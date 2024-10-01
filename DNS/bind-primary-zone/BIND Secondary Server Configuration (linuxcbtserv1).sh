#!/bin/bash

### BIND Secondary Server Configuration (linuxcbtserv1) ###

# Variables
PRIMARY_SERVER_IP="172.31.19.202"  # Set the primary server IP (linuxcbtserv2)
SECONDARY_SERVER_IP=$(hostname -I | awk '{print $1}')  # Automatically get secondary server's IP
ZONE_FILE="linuxcbt.external"
ZONE_FILE_PATH="/var/named/$ZONE_FILE"
HOSTNAME=$(hostname)  # Get hostname of the server

# Function to check command status
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Install BIND if not already installed
echo "Installing BIND on linuxcbtserv1..."
yum install -y bind bind-utils firewalld systemd 
check_status "BIND installation"

# Backup the named.conf file before editing
echo "Backing up /etc/named.conf..."
cp /etc/named.conf /etc/named.conf.backup
check_status "Backup of /etc/named.conf"

# Add zone definition for external zone
if ! grep -q "zone \"$ZONE_FILE\"" /etc/named.conf; then
    echo "Adding zone definition for $ZONE_FILE to /etc/named.conf..."
    cat <<EOT >> /etc/named.conf
zone "$ZONE_FILE" IN {
    type slave;
    masters { $PRIMARY_SERVER_IP; };
    file "$ZONE_FILE_PATH";
};
EOT
else
    echo "Zone definition already exists in /etc/named.conf."
fi



# Create the zone file if it doesn't already exist
if [ ! -f "$ZONE_FILE_PATH" ]; then
    echo "Creating new zone file: $ZONE_FILE_PATH"
    cp /var/named/named.localhost "$ZONE_FILE_PATH"
else
    echo "Zone file $ZONE_FILE_PATH already exists."
fi

# Edit the zone file by adding necessary DNS records if they don't already exist
echo "Editing zone file $ZONE_FILE_PATH with DNS records..."
ZONE_CONTENT="\$TTL 60
@   IN SOA  linuxcbt.external. vdns-admin.linuxcbt.external. (
               2017121506  ; serial
               1D          ; refresh
               1H          ; retry
               1W          ; expire
               3H )        ; minimum
@          IN NS    linuxcbtserv2.linuxcbt.external.
@          IN NS    linuxcbtserv1.linuxcbt.external.
@          IN MX 2  linuxcbtserv1.linuxcbt.external.

linuxcbtserv2   IN A     $PRIMARY_SERVER_IP
linuxcbtserv1   IN A     $SECONDARY_SERVER_IP
www             IN CNAME linuxcbtserv2.linuxcbt.external."

# Only add missing lines to the zone file
while IFS= read -r line; do
    if ! grep -Fxq "$line" "$ZONE_FILE_PATH"; then
        echo "$line" >> "$ZONE_FILE_PATH"
        echo "Added: $line"
    fi
done <<< "$ZONE_CONTENT"

# Check zone file syntax
# Set correct ownership and permissions on zone file
echo "Changing ownership of $ZONE_FILE_PATH..."
chown root:named "$ZONE_FILE_PATH"
check_status "Changing ownership of zone file"

# Check BIND configuration
sudo named-checkconf /etc/named.conf
check_status "named-checkconf"

# Restart BIND service
echo "Restarting BIND service..."
systemctl restart named
check_status "Restart BIND service"

named-checkzone linuxcbt.external "$ZONE_FILE_PATH"
check_status "Zone file check"



# Restart BIND to apply changes
echo "Restarting BIND service..."
systemctl restart named
check_status "Restart BIND service"

# Check running named processes
echo "Checking named processes..."
ps -ef | grep -i named

# Verify if BIND is listening on the correct ports
echo "Checking open TCP connections..."
netstat -ant | grep 53

# View BIND logs for errors
echo "Viewing named logs..."
tail /var/log/messages

# Testing DNS queries
echo "Testing DNS queries..."
dig @localhost $HOSTNAME
dig @$SECONDARY_SERVER_IP $ZONE_FILE NS
dig @localhost www.$ZONE_FILE
dig @$SECONDARY_SERVER_IP linuxcbtserv2.$ZONE_FILE

echo "Secondary DNS server (linuxcbtserv1) configuration completed."
