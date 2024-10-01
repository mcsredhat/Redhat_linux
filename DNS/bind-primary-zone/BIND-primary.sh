#!/bin/bash

### BIND-primary server linuxcbtserv2 ###

# Variables
ZONE_FILE="linuxcbt.internal"
ZONE_NAME="linuxcbt.internal"
PRIMARY_SERVER_IP=$(hostname -I | awk '{print $1}')  # Automatically get the primary server's IP address
SECONDARY_SERVER_IP="CHANGE_THIS_TO_SECONDARY_SERVER_IP"  # Set the secondary server IP manually
HOSTNAME=$(hostname)  # Automatically get the hostname of the server


ZONE_FILE_PATH="/var/named/$ZONE_FILE"

echo "### Configuring BIND Primary Server ###"
echo "Primary Server IP: $PRIMARY_SERVER_IP"
echo "Hostname: $HOSTNAME"

# Install BIND package if not already installed
echo "Installing BIND..."
yum install -y bind bind-utils

# Backup named.conf before editing
echo "Backing up /etc/named.conf"
cp /etc/named.conf /etc/named.conf.backup

# Define the zone in named.conf
echo "Defining zone in /etc/named.conf"
cat <<EOT >> /etc/named.conf

zone "$ZONE_NAME" IN {
    type master;
    file "$ZONE_FILE";
    allow-update { none; };
};
EOT

#check the configuration file /etc/named.conf
sudo named-checkconf /etc/named.conf

# Restart BIND service
echo "Restarting named (BIND) service..."
systemctl restart named

# Navigate to the BIND zone directory
echo "Navigating to /var/named directory..."
cd /var/named/

# Check if named.localhost exists and copy it to create new zone file
echo "Creating new zone file from named.localhost"
cp named.localhost $ZONE_FILE

# Update the zone file with DNS records
echo "Editing zone file $ZONE_FILE with DNS records"
cat <<EOT > $ZONE_FILE
\$TTL 60
@   IN SOA  linuxcbt.internal. vdns-admin.linuxcbt.internal. (
               2017121506  ; serial
               1D          ; refresh
               1H          ; retry
               1W          ; expire
               3H )        ; minimum
@          IN NS   $HOSTNAME.
@          IN NS   linuxcbtserv1.linuxcbt.internal.
@          IN MX 2 linuxcbtserv1.linuxcbt.internal.

$HOSTNAME   IN A     $PRIMARY_SERVER_IP
linuxcbtserv1   IN A     $SECONDARY_SERVER_IP
www             IN CNAME $HOSTNAME.linuxcbt.internal.

EOT

# check configuration zone  /var/named/linuxcbt.internal##
named-checkzone linuxcbt.internal /var/named/linuxcbt.internal


# Change ownership of the zone file
echo "Changing ownership of $ZONE_FILE to root.named"
chown root:named $ZONE_FILE

# Restart the named service to apply changes
echo "Restarting named service..."
systemctl restart named.service

# Check for running named processes
echo "Checking named processes..."
ps -ef | grep -i named

# Check open TCP connections to verify BIND is listening
echo "Checking open TCP connections..."
netstat -ant | grep 53

# View the BIND logs for errors
echo "Viewing named service logs..."
tail /var/named/data/named.run

### Configuring Firewall ###
echo "Configuring firewall rules for DNS traffic..."

# Allow DNS traffic over TCP port 53
firewall-cmd --permanent --add-port=53/tcp

# Allow DNS traffic over UDP port 53
firewall-cmd --permanent --add-port=53/udp

# Reload firewall to apply the changes
firewall-cmd --reload

# Verify the firewall rules
iptables -L -n | grep 53

### DNS Queries and Testing ###
echo "Testing DNS configuration..."

# Query localhost for linuxcbtserv2
dig @localhost $HOSTNAME.$ZONE_NAME

# Query DNS server for linuxcbt.internal NS records
dig @$PRIMARY_SERVER_IP $ZONE_NAME NS

# Query for MX, CNAME, and A records
dig @localhost $ZONE_NAME MX
dig @localhost $ZONE_NAME CNAME
dig @localhost www.$ZONE_NAME
dig @localhost linuxcbtserv1.$ZONE_NAME


# SSH into secondary server and configure BIND
echo "Configuring secondary BIND server (linuxcbtserv1)..."
ssh $USERNAME@$SECONDARY_SERVER_IP << 'EOF'

# Install BIND package
yum install -y bind bind-utils

# Configure named.conf for external zone
cat <<EOT >> /etc/named.conf
zone "linuxcbt.external" IN {
    type master;
    file "linuxcbt.external";
    allow-update { none; };
};
EOT

# check the configuration file /etc/named.conf 
sudo named-checkconf /etc/named.conf


# create the copied zone file and rename it
cat <<EOT > /var/named/linuxcbt.external
\$TTL 60
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
www             IN CNAME linuxcbtserv2.linuxcbt.external.

EOT


# check configuration zone  /var/named/linuxcbt.external##
named-checkzone linuxcbt.external /var/named/linuxcbt.external


# Change ownership of the zone file
chown root:named /var/named/linuxcbt.external

# Restart the named service
systemctl restart named.service

# Query the DNS server for linuxcbt.external
dig @localhost linuxcbtserv1.linuxcbt.external
dig @$SECONDARY_SERVER_IP linuxcbt.external
dig @$SECONDARY_SERVER_IP www.linuxcbt.external
dig @$SECONDARY_SERVER_IP linuxcbt.external MX

EOF

echo "BIND DNS configuration completed successfully."


