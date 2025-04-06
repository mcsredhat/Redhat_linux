# Reverse DNS Zone Configuration

This README explains how to configure reverse DNS zones on BIND DNS servers to enable IP-to-hostname resolution for the network infrastructure.

## Overview

This guide covers:
- Completing the slave zone configuration for cross-server redundancy
- Setting up reverse DNS (PTR records) for the 172.31.0.0/16 subnet
- Configuring proper file permissions and SELinux contexts for zone files
- Testing reverse DNS lookups

## Server Information

| Server Name | IP Address | Forward Zones | Reverse Zones |
|-------------|------------|---------------|---------------|
| linuxcbtserv2 | 172.31.97.38 | Master for linuxcbt.internal<br>Slave for linuxcbt.external | Master for 172.31.in-addr.arpa |
| linuxcbtserv1 | 172.31.108.225 | Master for linuxcbt.external<br>Slave for linuxcbt.internal | - |

## Configuration Steps

### Completing Slave Zone Configuration

1. **Finalize linuxcbtserv1 as Slave for linuxcbt.internal**
   - Edit named.conf to ensure proper slave zone configuration
   - Specify masters and zone file location
   - Verify zone transfer by checking slaves directory
   - Test resolution of records from the master zone

2. **Finalize linuxcbtserv2 as Slave for linuxcbt.external**
   - Configure proper slave zone settings in named.conf
   - Specify masters and zone file location
   - Verify successful zone transfer from master

### Setting Up Reverse DNS Zone

1. **Create Reverse Zone Configuration**
   - Add reverse zone declaration in named.conf for 172.31.in-addr.arpa
   - Create zone file based on template (named.localhost)
   - Configure SOA record with proper serial number and timing values
   - Add NS records for both DNS servers

2. **Configure PTR Records**
   - Create PTR records mapping IP addresses to hostnames
   - Example: 20 IN PTR linuxcbtserv1.linuxcbt.internal.
   - Example: 21 IN PTR linuxcbtserv2.linuxcbt.internal.

3. **Apply Proper Security Settings**
   - Set correct file ownership (root.named)
   - Set proper file permissions (644)
   - Configure SELinux context (named_zone_t)
   - Verify settings with ls -Z command

## Verification and Testing

1. **Check Configuration Syntax**
   - Use named-checkconf to validate named.conf
   - Use named-checkzone to validate zone file syntax

2. **Verify Zone Loading**
   - Restart named service
   - Check log files for successful zone loading

3. **Test Reverse DNS Resolution**
   - Use dig -x commands to perform reverse lookups
   - Verify proper resolution of IP addresses to hostnames

## Best Practices for Reverse DNS

- Ensure forward and reverse DNS records are consistent
- Use meaningful hostnames that reflect server roles
- Keep SOA serial numbers updated when making changes
- Always validate zone files before reloading services
- Implement proper file permissions and SELinux contexts
- Test from multiple locations to ensure proper resolution

## Troubleshooting

- If reverse lookups fail, check:
  - Zone file syntax and formatting
  - File permissions and SELinux contexts
  - Named service logs for errors
  - Network connectivity and firewall rules
  - Reverse zone delegation if applicable
