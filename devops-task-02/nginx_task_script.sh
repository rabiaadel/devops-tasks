#!/bin/bash

echo "Starting Nginx Task Automation Demo"
echo "==================================="

# Navigate up to simulate directory backtracking
cd ../../
echo "Moved to  $(pwd)"
sleep 1

cd ..
echo "Moved to $(pwd)"
sleep 1

cd ~
echo "Moved to $(pwd)"
sleep 1

cd -
echo "Back to  $(pwd)"
sleep 1

# Create HTML files
sudo touch /var/www/html/rabia82.html
sudo touch /var/www/html/rabia83.html
echo "Created HTML files"

# Create Nginx config files
sudo tee /etc/nginx/conf.d/ho82.conf > /dev/null <<EOF
server {
    listen 82;
    server_name localhost;

    location /image/ {
        root /var/www/html;
        index rabia82.html;
    }

    location ~ \.php\$ {
        root /var/www/html;
        index rabia82.html;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js)\$ {
        expires 30d;
    }
}
EOF

sudo tee /etc/nginx/conf.d/ho83.conf > /dev/null <<EOF
server {
    listen 83;
    server_name localhost;

    location /image/ {
        root /var/www/html;
        index rabia83.html;
    }

    location ~ \.php\$ {
        root /var/www/html;
        index rabia83.html;
        fastcgi_pass 127.0.0.1:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js)\$ {
        expires 30d;
    }
}
EOF

echo "Created Nginx conf files for ports 82 and 83"

# Show structure using eza
echo "Listing /etc/nginx/conf.d:"
eza -l /etc/nginx/conf.d | grep ho
echo

echo "Listing /var/www/html:"
eza -l /var/www/html | grep rabia
echo

# Show running processes
echo "Processes (nginx/php):"
procs | grep -E 'nginx|php'
echo

# Test and reload Nginx
echo "Testing Nginx..."
sudo nginx -t
echo "Reloading Nginx..."
sudo systemctl reload nginx
sleep 1

# Cleanup
echo "Cleaning up all created files..."
sudo rm /etc/nginx/conf.d/ho82.conf
sudo rm /etc/nginx/conf.d/ho83.conf
sudo rm /var/www/html/rabia82.html
sudo rm /var/www/html/rabia83.html
echo "Cleanup completed"

echo "Done."
