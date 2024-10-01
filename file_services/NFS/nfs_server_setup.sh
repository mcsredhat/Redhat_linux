#!/bin/bash

# Define variables
PROJECT_DIR="/projectx"
NFS_SERVER_IP="172.31.44.225"

# Function to check if a package is installed
check_package_installed() {
    local package=$1
    if rpm -q "$package" >/dev/null 2>&1; then
        echo "$package is already installed."
    else
        echo "$package is not installed. Installing..."
        sudo yum install -y "$package"
    fi
}

# Function to check if a directory exists
check_directory_exists() {
    local dir=$1
    if [ -d "$dir" ]; then
        echo "Directory $dir exists."
    else
        echo "Directory $dir does not exist. Creating..."
        sudo mkdir -p "$dir"
        sudo chmod 777 "$dir"
    fi
}

# Function to check if an entry exists in /etc/exports
check_exports_configuration() {
    local export_entry=$1
    if grep -q "$export_entry" /etc/exports; then
        echo "$export_entry already exists in /etc/exports."
    else
        echo "Adding $export_entry to /etc/exports."
        echo "$export_entry" | sudo tee -a /etc/exports
    fi
}

# NFS Server Configuration
echo "Configuring NFS server on linuxcbtserv2 ($NFS_SERVER_IP)..."

# 1. Check and install nfs-utils
check_package_installed "nfs-utils"

# 2. Enable and start NFS server services
sudo systemctl enable nfs-server
sudo systemctl start nfs-server
sudo systemctl start rpcbind
sudo systemctl enable rpcbind

# 3. Check if /projectx directory exists
check_directory_exists "$PROJECT_DIR"

# 4. Update /etc/exports for the directory
check_exports_configuration "$PROJECT_DIR *(rw,sync,no_root_squash)"

# 5. Export the NFS directories
sudo exportfs -av

# 6. Open firewall ports for NFS
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=rpc-bind
sudo firewall-cmd --permanent --add-port=2049/tcp
sudo firewall-cmd --permanent --add-port=111/tcp
sudo firewall-cmd --reload

# 7. Show NFS exports
sudo showmount --exports "$NFS_SERVER_IP"

# 8. Verify NFS and RPCBIND status
sudo netstat -ntlp | grep -i 'nfs\|rpcbind'

# 9. SELinux configuration for NFS
sudo setsebool -P allow_nfsd_anon_write on
sudo setsebool -P virt_use_nfs on
sudo setsebool -P xen_use_nfs on
sudo setsebool -P nfs_export_all_ro=1 nfs_export_all_rw=1 samba_share_nfs=1 httpd_use_nfs=1 use_nfs_home_dirs=1

echo "NFS server setup completed on linuxcbtserv2."
