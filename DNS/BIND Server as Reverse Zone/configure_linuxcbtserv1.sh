#!/bin/bash

# Function to get the server's primary IP address dynamically
get_ip_address() {
    ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1
}

# Function to get the network address from the IP
get_network_address() {
    ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d. -f1,2,3 | head -n 1
}

# Function to calculate the reverse zone name based on network address
get_reverse_zone() {
    local network_address=$1
    echo "$(echo $network_address | awk -F. '{print $3"."$2"."$1}').in-addr.arpa"
}

# Function to configure forward and reverse zones in /etc/named.conf
configure_zones() {
    local reverse_zone=$1

    # Configure forward zone for linuxcbtserv1
    echo "Configuring forward zone for linuxcbtserv1..."
    if ! grep -q "linuxcbt.internal" /etc/named.conf; then
        cat << EOF >> /etc/named.conf
zone "linuxcbt.internal" IN {
    type slave;
    masters { $ip_address; };
    file "slaves/linuxcbt.internal";
    allow-update { none; };
};
EOF
    fi

    # Configure reverse zone for linuxcbtserv1
    echo "Configuring reverse zone for linuxcbtserv1..."
    if ! grep -q "$reverse_zone" /etc/named.conf; then
        cat << EOF >> /etc/named.conf
zone "$reverse_zone" IN {
    type master;
    file "/var/named/${reverse_zone}.zone";
    allow-update { none; };
};
EOF
    fi
}

# Function to create the reverse zone file with PTR records
create_reverse_zone_file() {
    local reverse_zone=$1
    echo "Creating reverse zone file for $reverse_zone..."

    if [ ! -f /var/named/${reverse_zone}.zone ]; then
        cat << EOF > /var/named/${reverse_zone}.zone
\$TTL 1800
@ IN SOA linuxcbtserv1.linuxcbt.internal. dns-admin.linuxcbt.internal. (
                    2017121601 ; serial
                    1D         ; refresh
                    1H         ; retry
                    1W         ; expire
                    3H )       ; minimum
@ IN NS linuxcbtserv1.linuxcbt.internal.
@ IN NS linuxcbtserv2.linuxcbt.internal.
"the first octet from ip address" IN PTR linuxcbtserv1.linuxcbt.internal.
EOF
    fi
}

# Main script execution
ip_address=$(get_ip_address)
network_address=$(get_network_address)
reverse_zone=$(get_reverse_zone "$network_address")

echo "Server IP Address: $ip_address"
echo "Network Address: $network_address"
echo "Reverse Zone: $reverse_zone"

# Ensure BIND is installed and configured
check_bind_installed() {
    if ! command -v named > /dev/null; then
        echo "BIND (named) is not installed. Please install it."
        exit 1
    fi
    echo "BIND is installed."
}

# Check if /etc/named.conf exists
if [ ! -f /etc/named.conf ]; then
    echo "/etc/named.conf does not exist. Please configure BIND first."
    exit 1
fi

configure_zones "$reverse_zone"
create_reverse_zone_file "$reverse_zone"

# Apply file permissions and restart the named service
sudo chown root:named /var/named/${reverse_zone}.zone
sudo chmod 644 /var/named/${reverse_zone}.zone
sudo restorecon -v /var/named/${reverse_zone}.zone
sudo chcon -t named_zone_t /var/named/${reverse_zone}.zone

sudo systemctl restart named.service
echo "BIND configuration for linuxcbtserv1 complete."

