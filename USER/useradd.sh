#!/bin/bash

# Path to the file containing username:password entries
USER_FILE="users.txt"

# Define variables for useradd options
HOME_DIR_BASE="/home"
SHELL="/bin/bash"
SKEL_DIR="/etc/skel"

# Password policy variables
MIN_DAYS=7         # Minimum days before password change is allowed
MAX_DAYS=120       # Maximum password age before it expires
WARN_DAYS=5        # Number of days before password expiration to warn the user
EXPIRE_DATE=$(date -d "+1 year" +%Y-%m-%d)  # Account expiration after one year

# Check if the file exists
if [[ ! -f "$USER_FILE" ]]; then
    echo "File $USER_FILE does not exist!"
    exit 1
fi

# Loop through each line in the file
while IFS=: read -r username password; do

    # Check if the username already exists in /etc/passwd
    if grep -q "^$username:" /etc/passwd; then
        echo "User '$username' already exists. Skipping."
    else
        # Create home directory, set shell, and skeleton directory using variables
        sudo useradd -m -d "$HOME_DIR_BASE/$username" -k "$SKEL_DIR" -s "$SHELL" "$username"

        # Check if the user was added successfully
        if [[ $? -eq 0 ]]; then
            # Set the password for the user
            echo "$username:$password" | sudo chpasswd

            # Set the password expiration policies
            sudo chage -m $MIN_DAYS -M $MAX_DAYS -W $WARN_DAYS -E $EXPIRE_DATE "$username"

            echo "User '$username' added successfully with password policy set."
        else
            echo "Failed to add user '$username'."
        fi
    fi

done < "$USER_FILE"

echo "User creation process completed."
