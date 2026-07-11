#!/bin/bash

# Stop the script immediately if any command fails
set -e

echo "Starting Custom L380 Print Server Setup..."

# 1. Update package lists
echo "Updating apt repositories..."
apt update

# 2. Install the core packages
echo "Installing CUPS, Gutenprint, Avahi, and download tools..."
apt install -y cups printer-driver-gutenprint avahi-daemon curl

# 3. Create the standard Epson model directory for CUPS
PPD_DIR="/usr/share/cups/model/epson"
echo "Preparing PPD directory at $PPD_DIR..."
mkdir -p "$PPD_DIR"

# 4. Check for local file vs. Web Download
# This grabs the exact directory path where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_PPD="$SCRIPT_DIR/epson-l380-custom.ppd"
PPD_DEST="$PPD_DIR/epson-l380-custom.ppd"

if [ -f "$LOCAL_PPD" ]; then
    echo "Found local PPD file at $LOCAL_PPD"
    echo "Skipping download and copying local file..."
    cp "$LOCAL_PPD" "$PPD_DEST"
else
    echo "No local PPD found in script directory. Downloading from the internet..."
    PPD_URL="https://raw.githubusercontent.com/alpha-exe-cpu/epson-l380-gutenprint/refs/heads/main/epson-l380-custom.ppd"
    curl -sL "$PPD_URL" -o "$PPD_DEST"
fi

# 5. Fix permissions so the background CUPS user can actually read it
echo "Applying strict system permissions..."
chmod 644 "$PPD_DEST"
chown root:root "$PPD_DEST"

# 6. Restart the services so CUPS rebuilds its driver database
echo "Restarting services and rebuilding driver lists..."
systemctl restart cups
systemctl restart avahi-daemon

echo "======================================================="
echo "Setup Complete!"
echo "Your custom L380 driver is now locked into CUPS."
echo 'Select "Epson L380 - CUPS+Gutenprint+Adrish v5.3.4-m1.0.0" as printer model from the Epson/ make directory.'
echo "======================================================="
