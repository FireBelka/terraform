#!/bin/bash
#sudo apt -y update
#sudo apt -y install nginx
#echo "<h2><br><br>Server 1</h2>" >> /var/www/html/index.html
#sudo systemctl start nginx
sudo apt -y update
sudo apt -y install nginx openssl
echo "<h2><br><br>Server 1</h2>" >> /var/www/html/index.html
mkdir /etc/nginx/certificate
cd /etc/nginx/certificate
sudo openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out nginx-certificate.crt -keyout nginx.key -subj '/C=BY/ST=./L=./CN=localhost/O=./E=./OU=.'
sudo echo "server {
        listen 443 ssl default_server;
        listen [::]:443 ssl default_server;
        ssl_certificate /etc/nginx/certificate/nginx-certificate.crt;
        ssl_certificate_key /etc/nginx/certificate/nginx.key;
        root /var/www/html;
        index index.html index.htm index.nginx-debian.html;
        server_name _;
        location / {
                try_files \$uri \$uri/ =404;
        }
      }" > /etc/nginx/sites-available/default
sudo service nginx restart
