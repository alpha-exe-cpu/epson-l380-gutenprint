#!/bin/bash

# Ensure we are running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./uninstall-all.sh)"
    exit 1
fi

echo "--- Purging Print Server Environment ---"

# 1. Run the base cleanup first
./uninstall.sh

# 2. Purge Print Drivers
echo "Purging CUPS and Gutenprint..."
apt purge -y cups printer-driver-gutenprint

# 3. Conditional Avahi Removal
read -p "Do you want to remove avahi-daemon? [y/N] " confirm_avahi
if [[ $confirm_avahi =~ ^[Yy]$ ]]; then
    echo "Purging avahi-daemon..."
    apt purge -y avahi-daemon
else
    echo "Skipping avahi-daemon removal."
fi

# 4. Conditional Socat Removal
read -p "Do you want to remove socat? [y/N] " confirm_socat
if [[ $confirm_socat =~ ^[Yy]$ ]]; then
    echo "Purging socat..."
    apt purge -y socat
else
    echo "Skipping socat removal."
fi

# 5. Cleanup remaining dependencies
echo "Cleaning up unused dependencies..."
apt autoremove -y

echo "======================================================="
echo "Purge complete."
echo "======================================================="
