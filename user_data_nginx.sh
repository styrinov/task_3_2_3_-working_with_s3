#!/bin/bash
yum -y update
yum -y install httpd nginx mod_ssl openssl

# Start and enable Apache
systemctl enable httpd
systemctl start httpd

# Create simple HTML page
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
cat <<EOF > /var/www/html/index.html
<html>
<body bgcolor="black">
<h2><font color="gold">Build by Power of Terraform <font color="red"> v0.12</font></h2><br><p>
<font color="green">Server PrivateIP: <font color="aqua">$myip<br><br>
<font color="magenta"><b>Version 3.0</b>
</body>
</html>
EOF

# Create self-signed certificate
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/server.key \
  -out /etc/nginx/ssl/server.crt \
  -subj "/C=US/ST=Terraform/L=Infra/O=Proxy/OU=Web/CN=ec2web.styrinov.com"


# Configure Nginx reverse proxy
cat <<EOF > /etc/nginx/conf.d/reverse-proxy.conf
server {
    listen 443 ssl;
    server_name ec2web.styrinov.com;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    location / {
        proxy_pass http://127.0.0.1:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Disable default HTTP Nginx server
rm -f /etc/nginx/conf.d/default.conf

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx
