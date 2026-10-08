#!/bin/bash
# web01: Nginx reverse proxy in front of Tomcat (app01:8080)
set -e

apt-get update
apt-get install -y nginx

cat > /etc/nginx/sites-available/vproapp <<EOT
upstream vproapp {
  server app01:8080;
}

server {
  listen 80;
  location / {
    proxy_pass http://vproapp;
  }
}
EOT

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/vproapp /etc/nginx/sites-enabled/vproapp

nginx -t
systemctl enable nginx
systemctl restart nginx
