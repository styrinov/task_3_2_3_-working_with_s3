#!/bin/bash
set -e

# Update package list and install packages
apt-get update -y
apt-get install -y apache2 nginx openssl

# Enable and start Apache
systemctl enable apache2
systemctl start apache2

# Use IMDSv2 to get the instance's private IP
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")

myip=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Public IP: $PUBLIC_IP" 
echo "Private IP: $myip"   

# Create a basic web page
cat <<EOF > /var/www/html/index.html
<html>
<body bgcolor="black">
<h2><font color="gold">Build by Power of Terraform <font color="red"> v0.12</font></h2><br><p>
<font color="green">Server PublicIP: <font color="aqua">$PUBLIC_IP<br><br>
<font color="green">Server PrivateIP: <font color="aqua">$myip<br><br>
<font color="magenta"><b>Version 1.0</b>
</body>
</html>
EOF

# Create self-signed certificate for Nginx
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/server.key \
  -out /etc/nginx/ssl/server.crt \
  -subj "/C=US/ST=Terraform/L=Infra/O=Proxy/OU=Web/CN=${domain_name}"

# Configure Nginx as reverse proxy
cat <<EOF > /etc/nginx/sites-available/reverse-proxy
server {
    listen 443 ssl;
    server_name ${domain_name};

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    location / {
        proxy_pass http://127.0.0.1:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the Nginx config and disable the default
ln -s /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/reverse-proxy
rm -f /etc/nginx/sites-enabled/default

# Enable and start Nginx
systemctl enable nginx
systemctl restart nginx
systemctl status nginx
