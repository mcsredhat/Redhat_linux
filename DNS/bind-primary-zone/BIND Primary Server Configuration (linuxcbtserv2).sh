#!/bin/bash

### BIND Primary Server Configuration (linuxcbtserv2) ###

# Variables
PRIMARY_SERVER_IP=$(hostname -I | awk '{print $1}')  # Get primary server's IP address automatically
SECONDARY_SERVER_IP="172.31.24.206"  # Set the secondary server IP manually (change this as necessary)
ZONE_FILE="linuxcbt.internal"
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
echo "Installing BIND..."
yum install -y bind bind-utils
check_status "BIND installation"

# Backup the named.conf file before editing
echo "Backing up /etc/named.conf..."
cp /etc/named.conf /etc/named.conf.backup
check_status "Backup of /etc/named.conf"

# Add zone definition to /etc/named.conf if not present
if ! grep -q "zone \"$ZONE_FILE\"" /etc/named.conf; then
    echo "Adding zone definition for $ZONE_FILE to /etc/named.conf..."
    cat <<EOT >> /etc/named.conf
zone "$ZONE_FILE" IN {
    type master;
    file "$ZONE_FILE_PATH";
    allow-update { none; };
};
EOT
else
    echo "Zone definition already exists in /etc/named.conf."
fi


# Create the zone file if it doesn't already exist
if [ ! -f "$ZONE_FILE_PATH" ]; then
    echo "Creating new zone file: $ZONE_FILE_PATH"
    touch $ZONE_FILE_PATH
else
    echo "Zone file $ZONE_FILE_PATH already exists."

    fi

# Define the required DNS records
echo "Checking zone file for required DNS records..."

cat <<'EOF' > /tmp/zone_content.txt
$TTL 60
@   IN SOA  linuxcbt.internal. vdns-admin.linuxcbt.internal. (
               2017121506  ; serial
               1D          ; refresh
               1H          ; retry
               1W          ; expire
               3H )        ; minimum
@          IN NS   linuxcbtserv2.linuxcbt.internal.
@          IN NS   linuxcbtserv1.linuxcbt.internal.
@          IN MX 2 linuxcbtserv1.linuxcbt.internal.
linuxcbtserv2.linuxcbt.internal   IN A     172.31.19.202
linuxcbtserv1   IN A      172.31.24.206
EOF

# Loop through each line in the zone file content and add missing records
while IFS= read -r line; do
    # Skip empty lines
    if [[ -z "$line" ]]; then
        continue
    fi

    # Only add lines that don't already exist in the file
    if ! grep -Fxq "$line" "$ZONE_FILE_PATH"; then
        echo "Adding missing record: $line"
        echo "$line" >> "$ZONE_FILE_PATH"
    else
        echo "Record already exists: $line"
    fi
done < /tmp/zone_content.txt

# Check BIND configuration
sudo named-checkconf /etc/named.conf
check_status "named-checkconf"


# Check zone file syntax
named-checkzone linuxcbt.internal "$ZONE_FILE_PATH"
check_status "Zone file check"

# Set correct ownership and permissions on zone file
echo "Changing ownership of $ZONE_FILE_PATH..."
chown root:named "$ZONE_FILE_PATH"
check_status "Changing ownership of zone file"


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

# Configure firewall to allow DNS traffic
echo "Configuring firewall for DNS..."
firewall-cmd --permanent --add-port=53/tcp
firewall-cmd --permanent --add-port=53/udp
firewall-cmd --reload
check_status "Firewall configuration"

# Testing DNS queries
echo "Testing DNS queries..."
dig @localhost $HOSTNAME
dig @$PRIMARY_SERVER_IP $ZONE_FILE NS
dig @localhost $ZONE_FILE MX
dig @localhost www.$ZONE_FILE
dig @localhost linuxcbtserv1.$ZONE_FILE

echo "Primary DNS server (linuxcbtserv2) configuration completed."




