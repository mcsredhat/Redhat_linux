#!/bin/bash

# Apache Installation and Basic Setup
echo "Checking Apache HTTPD installation..."
if ! rpm -qa | grep -q httpd; then
    echo "Apache HTTPD not found. Installing..."
    yum -y install httpd
else
    echo "Apache HTTPD is already installed."
fi

# Performance Testing
echo "Testing Apache server response..."
ab http://localhost/
ab -n 100 -c 10 http://localhost/

# Service Management
echo "Managing Apache service..."
echo "Checking Apache PID file..."
ls -l /etc/httpd/run/httpd.pid
echo "Checking running Apache processes..."
ps -ef | grep httpd

echo "Stopping Apache service..."
systemctl stop httpd.service
sleep 5
echo "Starting Apache service..."
systemctl start httpd.service
sleep 5

# Apache Configuration Files
echo "Listing Apache configuration files..."
ls -l /etc/httpd/conf.d/

echo "Viewing contents of ssl.conf..."
cat /etc/httpd/conf.d/ssl.conf

# Virtual Hosts Configuration
echo "Configuring Virtual Hosts..."

# Prepare Virtual Host Configuration File
echo "Creating Virtual Host configuration for site1.linuxcbt.internal..."
cat <<EOF > /etc/httpd/conf.d/site1.linuxcbt.internal.conf
<VirtualHost 192.168.75.22>
    ServerAdmin root@linuxcbtserv2.linuxcbt.internal
    ServerName site1.linuxcbt.internal
    DocumentRoot /var/www/site1.linuxcbt.internal
    <Directory /var/www/site1.linuxcbt.internal>
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Set Up Document Root
echo "Setting up Document Root for site1..."
mkdir -p /var/www/site1.linuxcbt.internal
echo "<center>SITE1</center>" > /var/www/site1.linuxcbt.internal/index.php

echo "Reloading Apache to apply virtual host configuration..."
systemctl reload httpd.service

# Testing Virtual Host
echo "Testing Virtual Host configuration..."
curl -I http://site1.linuxcbt.internal

# Virtual Host DNS Configuration (Example DNS settings)
echo "Configuring DNS settings..."
cat <<EOF >> /etc/resolv.conf
search linuxcbt.internal
nameserver 192.168.75.21
EOF

# Example DNS zone file entry for virtual host (adjust as needed)
echo "Updating DNS zone file..."
cat <<EOF >> /var/named/linuxcbt.internal
site1   IN  A   192.168.75.22
EOF

echo "Restarting named service..."
systemctl restart named.service

# Testing DNS Resolution
echo "Testing DNS resolution for site1.linuxcbt.internal..."
dig site1.linuxcbt.internal

# Final Checks and Logs
echo "Checking Apache configuration..."
httpd -S

echo "Viewing Apache access logs..."
tail -n 10 /var/log/httpd/access_log

echo "Viewing Apache error logs..."
tail -n 10 /var/log/httpd/error_log

echo "Apache configuration and testing complete."
