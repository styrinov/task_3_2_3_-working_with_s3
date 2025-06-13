#!/bin/bash
set -e

# --- Configuration ---
subdomain="ec2web"
domain="styrinov.com"
domain_name="$subdomain.$domain"
admin_email="admin@$domain_name"

# --- Update and install essentials ---
sudo apt-get update -y
sudo apt-get install -y git curl nginx python3-certbot-nginx openssl

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
cd /opt
git clone https://github.com/ghostfolio/ghostfolio.git
cd ghostfolio

# --- Create .env file ---
cp .env.example .env

# --- Generate secrets ---
ACCESS_TOKEN_SALT=$(openssl rand -base64 32)
JWT_SECRET_KEY=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 16)
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
sudo docker compose -f ./docker/docker-compose.yml up -d

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
