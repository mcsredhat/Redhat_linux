#!/bin/bash

# Function to check if a command executed successfully
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error executing: $1"
        exit 1
    fi
}

### Variables ###
PRIMARY_IP=$(hostname -I | awk '{print $1}') # Get the primary IP address of the server dynamically

### Configuring /etc/named.conf for linuxcbt.internal zone ###
echo "Configuring /etc/named.conf for 'linuxcbt.internal' as the slave zone..."

if grep -q 'zone "linuxcbt.internal"' /etc/named.conf; then
    echo "Zone 'linuxcbt.internal' already exists in /etc/named.conf."
else
    # Backup the current named.conf
    cp /etc/named.conf /etc/named.conf.bak

    # Append the slave zone configuration to /etc/named.conf
    cat << EOF >> /etc/named.conf

zone "linuxcbt.internal" IN {
    type slave;
    file "/var/named/slaves/linuxcbt.internal";
    masters { 172.31.108.225; };  # Replace with the IP of linuxcbtserv2
};
EOF
    echo "Slave zone for 'linuxcbt.internal' added to /etc/named.conf."
fi

### Restarting named service on linuxcbtserv1 ###
echo "Restarting 'named' service on linuxcbtserv1..."
systemctl restart named.service
check_status "systemctl restart named.service"

### Checking service logs for errors ###
echo "Checking the named service logs for errors..."
tail -n 20 /var/named/data/named.run

### DNS Queries ###
echo "Querying localhost for 'www.linuxcbt.internal'..."
dig @localhost www.linuxcbt.internal

echo "Querying 192.168.75.20 DNS server for 'www.linuxcbt.internal'..."
dig @192.168.75.20 www.linuxcbt.internal

echo "Querying 192.168.75.20 DNS server for MX record of 'linuxcbt.external'..."
dig @192.168.75.20 linuxcbt.external MX

### Listing files in various directories ###
echo "Listing files in the 'slave' directory..."
ls -l /var/named/slave/

echo "Listing files in the 'dynamic' directory..."
ls -l /var/named/dynamic/

echo "Listing files in the 'data' directory..."
ls -l /var/named/data/
