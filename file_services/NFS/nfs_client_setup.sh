#!/bin/bash

# Define variables
NFS_SERVER_IP="172.31.44.225"
PROJECT_DIR="/projectx"

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

# NFS Client Configuration
echo "Configuring NFS client on linuxcbtserv1..."

# 1. Check and install nfs-utils
check_package_installed "nfs-utils"

# 2. Ensure rpcbind service is running
sudo systemctl start rpcbind
sudo systemctl enable rpcbind

# 3. Add entry to /etc/hosts for NFS server
if ! grep -q "$NFS_SERVER_IP" /etc/hosts; then
    echo "$NFS_SERVER_IP linuxcbtserv2.linuxcbt.internal linuxcbtserv2" | sudo tee -a /etc/hosts
else
    echo "/etc/hosts already contains an entry for $NFS_SERVER_IP"
fi

# 4. Mount the NFS share from the server
if mount | grep -q "$PROJECT_DIR"; then
    echo "$PROJECT_DIR is already mounted."
else
    echo "Mounting NFS share..."
    sudo mount -t nfs linuxcbtserv2.linuxcbt.internal:$PROJECT_DIR $PROJECT_DIR
fi

# 5. Verify mounted file systems
mount | grep "$PROJECT_DIR"

# 6. Verify Disk Space usage on the mounted NFS directory
sudo df -h "$PROJECT_DIR"

# 7. Append data to a file in the NFS-mounted directory
sudo seq 10000 >> "$PROJECT_DIR/1k.txt"
sudo ls -l "$PROJECT_DIR/1k.txt"

# 8. Update /etc/fstab for persistent mount
if ! grep -q "$PROJECT_DIR" /etc/fstab; then
    echo "Adding NFS mount to /etc/fstab."
    echo "linuxcbtserv2.linuxcbt.internal:$PROJECT_DIR $PROJECT_DIR nfs defaults 0 0" | sudo tee -a /etc/fstab
else
    echo "/etc/fstab already has a persistent mount for $PROJECT_DIR."
fi

# 9. Remount all filesystems listed in /etc/fstab
sudo mount -a

###Query NFS shares from another host**:
sudo showmount --all 172.31.44.225

####**Append data to files**:
sudo seq 10000 >> /projectx/100k.txt
sudo seq 10000 >> /projectx/1m.txt


echo "NFS client setup completed on linuxcbtserv1."
