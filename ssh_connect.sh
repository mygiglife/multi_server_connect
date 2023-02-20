#!/bin/bash

# 1. Check if the script is being run as a regular user
if [[ $EUID -eq 0 ]]; then
   echo "This script must be run as a regular user" 
   exit 1
fi

# 2. Check if the restricted folder to hold ssh keys is created with proper permissions
SSH_FOLDER="$HOME/.ssh"
if [ ! -d "$SSH_FOLDER" ]; then
    mkdir "$SSH_FOLDER"
    chmod 700 "$SSH_FOLDER"
fi

# 3. Check home folder for new ssh .pem file and move them to the ssh folder with the correct 400 permission
for PEM_FILE in "$HOME"/*.pem; do
    if [ -f "$PEM_FILE" ]; then
        mv "$PEM_FILE" "$SSH_FOLDER"
        chmod 400 "$SSH_FOLDER/$(basename $PEM_FILE)"
    fi
done

# 4. Prompt the user if they are connecting to a new or existing server
echo "Are you connecting to a new or existing server? (n/e)"
read -r CHOICE

# 5. If new server, prompt for server ip, username, and display a list of ssh keys to select from and save to local database
if [[ "$CHOICE" == "n" ]]; then
    echo "Enter the IP address of the new server:"
    read -r SERVER_IP

    echo "Enter the username to use for SSH login:"
    read -r SSH_USERNAME

    # Display a list of ssh keys to select from
    echo "Select an SSH key to use for authentication:"
    select SSH_KEY_FILE in "$SSH_FOLDER"/*.pem; do
        if [ -n "$SSH_KEY_FILE" ]; then
            break
        else
            echo "Invalid choice. Please try again."
        fi
    done

    # Ask for a unique name to save to local database
    echo "Enter a unique name for this server connection:"
    read -r SERVER_NAME

    # Save server details to local database
    echo "$SERVER_NAME,$SSH_USERNAME,$SERVER_IP,$SSH_KEY_FILE" >> "$HOME/.servers.db"

# 6. If existing is selected, display a selectable list of servers to connect to and connect to it
elif [[ "$CHOICE" == "e" ]]; then
    # Display a list of existing servers to choose from
    echo "Select an existing server to connect to:"
    select SERVER in $(cut -d',' -f1 "$HOME/.servers.db"); do
        if [ -n "$SERVER" ]; then
            break
        else
            echo "Invalid choice. Please try again."
        fi
    done

    # Get server details from local database
    SERVER_DETAILS=$(grep "^$SERVER" "$HOME/.servers.db" | head -n1)

    # Connect to the selected server using SSH
    ssh -i "$(echo "$SERVER_DETAILS" | cut -d',' -f4)" "$(echo "$SERVER_DETAILS" | cut -d',' -f2)@$(echo "$SERVER_DETAILS" | cut -d',' -f3)"
fi
