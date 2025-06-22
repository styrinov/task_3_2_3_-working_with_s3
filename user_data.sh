#!/bin/bash
set -e

# --- Configuration ---
subdomain="ec2web"
domain="styrinov.com.ua"
domain_name="$subdomain.$domain"
admin_email="admin@$domain_name"

# --- Update and install essentials ---
sudo apt-get update -y
sudo apt-get install -y git curl nginx python3-certbot-nginx openssl inotify-tools awscli

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd docker || true
sudo usermod -aG docker ubuntu
sudo docker version

# Stop and remove Apache if present
systemctl stop apache2 || true
systemctl disable apache2 || true
apt-get purge -y apache2 apache2-utils apache2-bin apache2.2-common || true
apt-get autoremove -y

# --- Enable and start Docker ---
systemctl enable docker
systemctl start docker

# --- Clone Ghostfolio ---
mkdir -p /home/ubuntu/projects
cd /home/ubuntu/projects
sudo chmod 755 /home/ubuntu/projects/
git clone https://github.com/styrinov/task_3_2_5_deploying_app2ec2_via_cd.git
cd task_3_2_5_deploying_app2ec2_via_cd

# --- Create .env file ---
cp .env.example .env

# --- Generate secrets ---
ACCESS_TOKEN_SALT=$(openssl rand -base64 32)
JWT_SECRET_KEY=$(openssl rand -base64 32)
POSTGRES_PASSWORD="sergio1981"
REDIS_PASSWORD=$(openssl rand -base64 16)
POSTGRES_USER="ghostfolio"
POSTGRES_DB="ghostfolio"

# --- Update .env ---
cat > .env <<EOF
ACCESS_TOKEN_SALT=$ACCESS_TOKEN_SALT
JWT_SECRET_KEY=$JWT_SECRET_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
COMPOSE_PROJECT_NAME=ghostfolio
POSTGRES_USER=$POSTGRES_USER
POSTGRES_DB=$POSTGRES_DB
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?connect_timeout=300&sslmode=prefer
REDIS_HOST=redis
REDIS_PORT=6379
EOF

# --- Run Ghostfolio using Docker Compose ---
sudo docker compose --env-file ./.env -f docker/docker-compose.yml up -d

# --- Create watcher script ---
WATCHER_SCRIPT="/home/ubuntu/watch-docker-compose.sh"
COMPOSE_DIR="/home/ubuntu/projects/task_3_2_5_deploying_app2ec2_via_cd/docker"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"

cat <<EOF > "$WATCHER_SCRIPT"
#!/bin/bash

echo "Watching $COMPOSE_FILE for changes..."

while inotifywait -e close_write,move,create,delete "$COMPOSE_FILE"; do
    echo "Change detected. Restarting services..."
    cd "$COMPOSE_DIR"
    docker compose down
    docker compose --env-file /home/ubuntu/projects/task_3_2_5_deploying_app2ec2_via_cd/.env up -d
done
EOF

chmod +x "$WATCHER_SCRIPT"
chown ubuntu:ubuntu "$WATCHER_SCRIPT"

# --- Create systemd service ---
cat <<EOF > /etc/systemd/system/docker-compose-watcher.service
[Unit]
Description=Watch docker-compose file and restart services on change
After=network.target docker.service
Requires=docker.service

[Service]
ExecStart=$WATCHER_SCRIPT
WorkingDirectory=$COMPOSE_DIR
Restart=always
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

# --- Enable and start the service ---
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable docker-compose-watcher.service
systemctl start docker-compose-watcher.service

sudo chown -R ubuntu:ubuntu /home/ubuntu/projects

# --- Configure Nginx reverse proxy ---
cat > /etc/nginx/sites-available/ghostfolio <<EOF
server {
    listen 80;
    server_name $domain_name;

    location / {
        proxy_pass http://localhost:3333;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# --- Enable Nginx site and restart ---
ln -s /etc/nginx/sites-available/ghostfolio /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx
systemctl restart nginx
systemctl status nginx

# Wait for DNS to propagate
sleep 30

# --- Request SSL Certificate ---
certbot --nginx -n --agree-tos --redirect --email "$admin_email" -d "$domain_name"

# --- Enable auto-renewal ---
systemctl enable certbot.timer

# === CREATE BACKUP SCRIPT ===
BACKUP_SCRIPT="/home/ubuntu/backup_ghostfolio_db.sh"
cat <<EOF > \$BACKUP_SCRIPT
#!/bin/bash

# === CONFIGURATION ===
CONTAINER_NAME="gf-postgres"
DB_NAME="ghostfolio"
DB_USER="ghostfolio"
DB_PASSWORD="sergio1981"
BACKUP_DIR="/tmp"
TIMESTAMP=\$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="\${DB_NAME}_backup_\${TIMESTAMP}.sql"
ARCHIVE_FILE="\${BACKUP_FILE}.gz"
S3_BUCKET="my-backup-bucket-0e407885-3158-4157-bfa3-a57a40f1b561"
S3_PATH="ghostfolio-db-backups/\${ARCHIVE_FILE}"

# === STEP 1: Dump the database from the container ===
echo "Creating database dump..."
docker exec -e PGPASSWORD="\${DB_PASSWORD}" "\${CONTAINER_NAME}" pg_dump -U "\${DB_USER}" "\${DB_NAME}" > "\${BACKUP_DIR}/\${BACKUP_FILE}"

# === STEP 2: Compress the backup ===
echo "Compressing dump..."
gzip "\${BACKUP_DIR}/\${BACKUP_FILE}"

# === STEP 3: Upload to S3 ===
echo "Uploading to S3..."
aws s3 cp "\${BACKUP_DIR}/\${ARCHIVE_FILE}" "s3://\${S3_BUCKET}/\${S3_PATH}"

# === STEP 4: Cleanup local file ===
echo "Cleaning up..."
rm -f "\${BACKUP_DIR}/\${ARCHIVE_FILE}"

echo "✅ Backup complete: s3://\${S3_BUCKET}/\${S3_PATH}"
EOF

chmod +x \$BACKUP_SCRIPT
chown ubuntu:ubuntu \$BACKUP_SCRIPT

# === ADD CRON JOB FOR DAILY BACKUP AT 3:00 AM ===
(crontab -l -u ubuntu 2>/dev/null; echo "0 3 * * * /home/ubuntu/backup_ghostfolio_db.sh >> /var/log/ghostfolio_backup.log 2>&1") | crontab -u ubuntu -
