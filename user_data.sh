#!/bin/bash
set -e

# --- Configuration ---
subdomain="ec2web"
domain="styrinov.com.ua"
domain_name="$subdomain.$domain"
admin_email="admin@$domain_name"
s3_bucket="ca045393-c70c-4328-aeaf-d0fd56a60a1a-docker-compose-bucket"

# --- Update and install essentials ---
sudo apt-get update -y
sudo apt-get install -y git curl unzip nginx python3-certbot-nginx openssl inotify-tools checkinstall build-essential tcl libssl-dev libjemalloc-dev postgresql-client dos2unix 
sleep 30

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
systemctl status docker

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
export PATH=$PATH:/usr/local/bin
aws --version

mkdir -p /home/ubuntu/projects
cd /home/ubuntu/projects
sudo chmod 755 /home/ubuntu/projects/
sudo chown -R ubuntu:ubuntu /home/ubuntu/projects
mkdir -p /home/ubuntu/projects/docker
aws s3 ls s3://$s3_bucket
aws s3 cp s3://$s3_bucket/docker-compose.yml /home/ubuntu/projects/docker/docker-compose.yml
sudo chown -R ubuntu:ubuntu /home/ubuntu/projects
sudo chown -R ubuntu:ubuntu /home/ubuntu/projects/docker
sudo chown ubuntu:ubuntu /home/ubuntu/projects/docker/docker-compose.yml


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
#certbot --nginx -n --agree-tos --redirect --email "$admin_email" -d "$domain_name"

# --- Enable auto-renewal ---
#systemctl enable certbot.timer