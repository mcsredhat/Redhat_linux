#!/bin/bash

# Variables
VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
FIREWALL_PORTS=(20 21)

# Function to check if a package is installed
check_package_installed() {
    local package=$1
    if rpm -q "$package" > /dev/null 2>&1; then
        echo "$package is already installed."
    else
        echo "$package is not installed. Installing..."
        sudo yum install -y "$package"
    fi
}

# Function to check if a line exists in a file
check_and_add_line_in_file() {
    local line=$1
    local file=$2
    if grep -q "^$line" "$file"; then
        echo "Line '$line' already exists in $file."
    else
        echo "Adding '$line' to $file."
        echo "$line" | sudo tee -a "$file"
    fi
}

# Function to check if the firewall ports are open
check_firewall_ports() {
    local port=$1
    if sudo firewall-cmd --list-ports | grep -q "${port}/tcp"; then
        echo "Firewall port $port/tcp is already open."
    else
        echo "Opening firewall port $port/tcp."
        sudo firewall-cmd --permanent --add-port="${port}/tcp"
    fi
}

# Install VSFTPD and FTP client
echo "Checking and Installing VSFTPD and FTP client..."
check_package_installed "vsftpd"
check_package_installed "ftp"

# Verify VSFTPD Installation
echo "Verifying VSFTPD installation..."
sudo rpm -qa | grep vsftpd

# Check VSFTPD package files
echo "Listing VSFTPD package files..."
sudo rpm -ql vsftpd

# Enable VSFTPD to start on boot and start the service
echo "Enabling and starting VSFTPD service..."
sudo systemctl enable vsftpd.service
sudo systemctl start vsftpd.service

# Check VSFTPD service status
echo "Checking VSFTPD service status..."
sudo systemctl status vsftpd.service

# Open Firewall ports 20 and 21
echo "Configuring firewall for FTP ports (20, 21)..."
for port in "${FIREWALL_PORTS[@]}"; do
    check_firewall_ports "$port"
done
sudo firewall-cmd --reload

# Check listening ports for VSFTPD
echo "Checking VSFTPD listening ports..."
sudo netstat -ntlp | grep vsftpd

# Review and modify VSFTPD configuration
echo "Checking and updating VSFTPD configuration..."

# Check and ensure these lines are in vsftpd.conf, but do not add them if they already exist
check_and_add_line_in_file "anonymous_enable=NO" "$VSFTPD_CONF"
check_and_add_line_in_file "local_enable=YES" "$VSFTPD_CONF"
check_and_add_line_in_file "write_enable=YES" "$VSFTPD_CONF"
check_and_add_line_in_file "chroot_local_user=YES" "$VSFTPD_CONF"

# Restart the VSFTPD service to apply the configuration
echo "Restarting VSFTPD service..."
sudo systemctl restart vsftpd.service

# Test FTP Connectivity
echo "Testing FTP connection..."
sudo ftp localhost

# Verify the FTP directory
echo "Checking FTP directory /var/ftp..."
cd /var/ftp/ && ls -l

# Create a test file in the FTP directory
echo "Creating a test file in /var/ftp/pub..."
cd /var/ftp/pub/ && sudo seq 10000 > 100k.txt && ls -l 100k.txt

# Test FTP Access from Localhost
echo "Testing FTP access from localhost..."
ftp localhost

echo "VSFTPD setup completed!"
