#!/bin/bash

# Script to configure vsftpd FTP server for a specific user

### Check if VSFTPD package is installed ###
echo "Checking if vsftpd is installed..."
rpm -qa | grep vsftpd > /dev/null

if [ $? -ne 0 ]; then
    echo "vsftpd is not installed. Please install it using your package manager."
    exit 1
else
    echo "vsftpd is installed."
fi

### Check SELinux boolean settings related to FTP ###
echo "Checking SELinux boolean settings for FTP..."
getsebool -a | grep ftp

### Set SELinux booleans to allow specific FTP behaviors ###
echo "Configuring SELinux to allow FTP-related behaviors..."
sudo setsebool -P allow_ftpd_anon_write on
sudo setsebool -P allow_ftpd_use_cifs on
sudo setsebool -P allow_ftpd_use_nfs on
sudo setsebool -P ftpd_connect_db on
sudo setsebool -P httpd_enable_ftp_server on
sudo setsebool -P tftp_anon_write on

### Configure firewall to allow FTP ports 20 and 21 ###
echo "Configuring firewall to allow FTP ports 20 and 21..."
if command -v firewall-cmd > /dev/null; then
    sudo firewall-cmd --permanent --add-port=20-21/tcp
    sudo firewall-cmd --reload
    echo "Firewall settings updated for firewalld."
elif command -v iptables > /dev/null; then
    sudo iptables -I INPUT -m tcp -p tcp --dport 20 -j ACCEPT
    sudo iptables -I INPUT -m tcp -p tcp --dport 21 -j ACCEPT
    sudo service iptables save
    sudo service iptables restart
    echo "Firewall settings updated for iptables."
else
    echo "Neither firewalld nor iptables were found."
fi

### Enable VSFTPD service to start on boot ###
echo "Enabling vsftpd service to start on boot..."
if command -v systemctl > /dev/null; then
    sudo systemctl enable vsftpd
    sudo systemctl start vsftpd
    echo "vsftpd enabled using systemctl."
elif command -v chkconfig > /dev/null; then
    sudo chkconfig vsftpd on
    sudo service vsftpd start
    echo "vsftpd enabled using chkconfig."
else
    echo "System does not support systemctl or chkconfig."
    exit 1
fi

### Check status of VSFTPD service ###
echo "Checking vsftpd service status..."
if command -v systemctl > /dev/null; then
    systemctl status vsftpd
else
    service vsftpd status
fi

### Append current vsftpd.conf configuration to vsmod.txt for reference ###
echo "Backing up vsftpd.conf configuration to vsmod.txt..."
sudo cat /etc/vsftpd/vsftpd.conf >> vsmod.txt

### Edit vsftpd.conf to configure FTP server settings ###
echo "Configuring vsftpd..."
sudo sed -i '/^anonymous_enable/c\anonymous_enable=NO' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^local_enable/c\local_enable=YES' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^write_enable/c\write_enable=YES' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^local_umask/c\local_umask=022' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^dirmessage_enable/c\dirmessage_enable=YES' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^xferlog_enable/c\xferlog_enable=YES' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^connect_from_port_20/c\connect_from_port_20=YES' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^xferlog_std_format/c\xferlog_std_format=YES' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^dual_log_enable/c\dual_log_enable=YES' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^pam_service_name/c\pam_service_name=vsftpd' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^userlist_enable/c\userlist_enable=NO' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^tcp_wrappers/c\tcp_wrappers=NO' /etc/vsftpd/vsftpd.conf
sudo sed -i '/^allow_writeable_chroot/c\allow_writeable_chroot=YES' /etc/vsftpd/vsftpd.conf

### Restart vsftpd service to apply the configuration changes ###
echo "Restarting vsftpd service..."
sudo systemctl restart vsftpd

### Test FTP connection to localhost ###
echo "Testing FTP connection to localhost..."
echo "Enter the username cloud_user and password (rooté&--) when prompted."
ftp -inv << EOF
open localhost
user cloud_user rooté&--
pwd
ls
pwd
ls
mput file1
y
ls -l file1
bye
EOF

echo "FTP setup and configuration completed."
