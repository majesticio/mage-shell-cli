#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Check for necessary dependencies
if ! command -v curl &>/dev/null; then
  echo "curl is required but not installed. Please install curl to continue."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "jq is required but not installed. Please install jq to continue."
  exit 1
fi

# Check for glow
if ! command -v glow &>/dev/null; then
  echo "glow is required for rendering Markdown but is not installed."
  echo "Please install glow using brew install glow or your package manager, and then rerun this script."
  exit 1
fi

# Define the installation path
INSTALL_PATH="/usr/local/bin/mage"

# Downloading mage.sh script
echo "Downloading mage.sh to ${INSTALL_PATH}..."
curl -sS https://raw.githubusercontent.com/majesticio/mage-shell-cli/main/mage.sh -o "${INSTALL_PATH}"

# Making the script executable
chmod +x "${INSTALL_PATH}"
echo "mage.sh has been installed successfully to ${INSTALL_PATH}."

echo "Installation complete. You can now use mage.sh by typing 'mage' in your terminal."
