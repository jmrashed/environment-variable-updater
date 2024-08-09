#!/bin/bash

# Define the folder name and path
FOLDER_NAME="environment-variable-updater"
ENV_FOLDER_PATH="$FOLDER_NAME"

# Check if the script is run from a directory containing the folder
if [ ! -d "$ENV_FOLDER_PATH" ]; then
  echo "Error: Folder '$FOLDER_NAME' not found in the current directory."
  exit 1
fi

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 {local|server}"
  exit 1
fi

# Set the source file based on the input argument
if [ "$1" == "local" ]; then
  ENV_FILE="$ENV_FOLDER_PATH/.env.local"
elif [ "$1" == "server" ]; then
  ENV_FILE="$ENV_FOLDER_PATH/.env.server"
else
  echo "Invalid argument. Please use 'local' or 'server'."
  exit 1
fi

# Check if the source file exists
if [ ! -f "$ENV_FILE" ]; then
  echo "File $ENV_FILE does not exist."
  exit 1
fi

# Backup the existing .env file if it exists
if [ -f .env ]; then
  cp .env .env.backup
else
  # Create an empty .env file if it doesn't exist
  touch .env
fi

# Create a temporary file to hold updated content
TEMP_FILE=$(mktemp)

# Read the source file and update the .env file
while IFS= read -r line; do
  # Skip empty lines and comments
  if [[ -z "$line" || "$line" =~ ^# ]]; then
    continue
  fi

  # Extract the key from the line (everything before the '=')
  key=$(echo "$line" | cut -d '=' -f 1)

  # Escape special characters in the key for use in sed
  escaped_key=$(printf '%s\n' "$key" | sed 's/[^^]/[&]/g; s/\^/\\^/g')

  # Update or add the key-value pair
  if grep -q "^$escaped_key=" .env; then
    # If the key exists, replace the line in the temporary file
    grep -v "^$escaped_key=" .env > "$TEMP_FILE"
    echo "$line" >> "$TEMP_FILE"
  else
    # If the key doesn't exist, append the line to the temporary file
    cat .env >> "$TEMP_FILE"
    echo "$line" >> "$TEMP_FILE"
  fi
done < "$ENV_FILE"

# Replace the original .env file with the updated content
mv "$TEMP_FILE" .env

echo ".env file has been updated based on $ENV_FILE."
