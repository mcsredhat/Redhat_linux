#!/bin/bash

# MySQL Installation and Basic Commands

### Check if MySQL is already installed ###
echo "Checking if MySQL is installed..."
rpm -qa | grep mysql
if [ $? -eq 0 ]; then
    echo "MySQL is already installed."
else
    ### Search for MySQL packages ###
    echo "Searching for MySQL packages in the repository..."
    yum search mysql

    ### Install MySQL server ###
    echo "Installing MySQL server..."
    sudo yum -y install mysql-server

    ### Verify installed files for mysql-server ###
    echo "Verifying installed files for mysql-server package..."
    sudo rpm -ql mysql-server

    ### Check MySQL configuration file (my.cnf) ###
    echo "Checking MySQL configuration file (my.cnf)..."
    less /etc/my.cnf

    ### Enable MySQL to start on boot ###
    echo "Enabling MySQL to start on boot..."
    sudo systemctl enable mysqld

    ### Start MySQL service ###
    echo "Starting MySQL service..."
    sudo systemctl start mysqld
fi

### MySQL Login and Basic Operations ###
echo "Logging into MySQL as root user..."
sudo mysql -u root -p <<EOF
# Perform basic MySQL operations once logged in
SHOW DATABASES;
USE mysql;
SHOW TABLES;
DESCRIBE user;
SELECT User,Host,Authentication_string FROM user;
\q
EOF

### Managing MySQL Users and Passwords ###
echo "Changing MySQL root password..."
/usr/bin/mysqladmin -u root password 'abc123'

echo "Logging into MySQL with new root password..."
mysql -u root -p'abc123' <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY 'abc123';
SELECT User, Host FROM mysql.user WHERE User = 'root';
FLUSH PRIVILEGES;
\q
EOF

### Creating and Managing Databases and Tables ###
echo "Logging into MySQL and creating database 'addressBook'..."
mysql -u root -p'abc123' <<EOF
CREATE DATABASE addressBook;
USE addressBook;

# Create 'contacts' table with fields
CREATE TABLE contacts (
    fname CHAR(20),
    lname CHAR(20),
    bus_phone CHAR(20),
    email CHAR(30),
    PRIMARY KEY(email)
);

# Show tables and structure
SHOW TABLES;
DESCRIBE contacts;

# Insert sample record
INSERT INTO contacts VALUES ('faraj', 'assulai', '0766450357', 'farajassulai@gmail.com');

# Select all records from contacts
SELECT * FROM contacts;

# Update a record
UPDATE contacts SET email = 'mcsredhat@gmail.com' WHERE fname = 'faraj';

# Delete a record
DELETE FROM contacts WHERE email = 'mcsredhat@gmail.com';

# Exit MySQL shell
\q
EOF

echo "MySQL setup and basic operations completed."
