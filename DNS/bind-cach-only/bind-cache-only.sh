#!/bin/bash

# Script for setting up a BIND DNS Server on linuxcbtserv1 or linuxcbtserv2
# Author: Professional Programmer
# Date: YYYY-MM-DD

# Function to check command execution status
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error executing command: $1"
        exit 1
    fi
}

# Function to check if a package is installed, if not, install it
install_package() {
    package=$1
    if ! rpm -q $package; then
        echo "Installing $package..."
        yum install -y $package
        check_status "yum install $package"
    else
        echo "$package is already installed."
    fi
}

# Function to get the server's primary IP address dynamically
get_ip_address() {
    ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1
}

# Function to get the hostname
get_hostname() {
    hostname
}

# Function to check if /etc/named.conf is properly configured
# Function to configure /etc/named.conf
configure_named_conf() {
    # Search and replace allow-query directive
    if grep -q "allow-query { localhost; };" /etc/named.conf; then
        echo "Updating 'allow-query { localhost; };' to 'allow-query { any; };'..."
        sed -i 's/allow-query { localhost; };/allow-query { any; };/g' /etc/named.conf
        check_status "sed -i to update allow-query directive"
    else
        echo "'allow-query { localhost; };' not found, no need to update."
    fi

    # Check if "listen-on port 53" already exists
    if grep -q "listen-on port 53 { 127.0.0.1; };" /etc/named.conf; then
        echo "'listen-on port 53 { 127.0.0.1; };' is already present in /etc/named.conf."
    else
        # Add listen-on directives if not found
        echo "Adding 'listen-on port 53 { 127.0.0.1; };' and 'listen-on-v6 port 53 { ::1; };'..."
        sed -i '/^options {/a\    listen-on port 53 { 127.0.0.1; };\n    listen-on-v6 port 53 { ::1; };' /etc/named.conf
        check_status "sed -i to add listen-on directives"
    fi
}

# Main script execution

# 1. Install necessary packages
install_package "net-tools"
install_package "firewalld"
install_package "bind"
install_package "bind-utils"

# 2. Start and enable firewalld
echo "Starting and enabling firewalld..."
systemctl start firewalld
check_status "systemctl start firewalld"
systemctl enable firewalld
check_status "systemctl enable firewalld"

# 3. Configure firewall rules
echo "Configuring firewall rules for DNS..."
firewall-cmd --zone=public --add-port=53/tcp --permanent
check_status "firewall-cmd --add-port=53/tcp"
firewall-cmd --permanent --add-service=dns
check_status "firewall-cmd --add-service=dns"
firewall-cmd --reload
check_status "firewall-cmd reload"

# 4. Enable and start named (BIND)
echo "Enabling and starting named service..."
systemctl enable named
check_status "systemctl enable named"
systemctl start named
check_status "systemctl start named"

# 5. Modify /etc/named.conf to listen on localhost and allow queries from any IP
configure_named_conf

# 6. Set SELinux booleans for named
echo "Configuring SELinux for named service..."
setsebool -P named_write_master_zones on
check_status "setsebool -P named_write_master_zones on"

# 7. Restart named to apply configuration changes
echo "Restarting named service after configuration changes..."
systemctl restart named
check_status "systemctl restart named"

# 8. Get server information and confirm DNS setup
server_ip=$(get_ip_address)
server_hostname=$(get_hostname)

echo "Server IP Address: $server_ip"
echo "Server Hostname: $server_hostname"

# 9. Query localhost DNS and test setup
echo "Querying localhost DNS..."
dig @localhost
check_status "dig @localhost"

echo "Querying DNS for www.example.com..."
dig @localhost www.linuxcbt.internal
check_status "dig @localhost www.linuxcbt.internal"

# 10. Verify open ports
echo "Verifying that UDP and TCP port 53 are open..."
netstat -nul | grep 53
netstat -ntl | grep 53

echo "DNS server setup completed successfully!"
