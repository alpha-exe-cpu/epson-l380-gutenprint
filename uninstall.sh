#!/bin/bash

# Ensure we are running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./uninstall.sh)"
    exit 1
fi

echo "--- Removing L380 Server Configurations ---"

# Stop and remove services
systemctl stop raw-printer.service || true
systemctl disable raw-printer.service || true
rm -f /etc/systemd/system/raw-printer.service
systemctl daemon-reload

# Remove printer and PPD
lpadmin -x Epson_L380_Series 2>/dev/null || true
rm -f /usr/share/cups/model/epson/epson-l380-custom.ppd

# Cleanup USB rules
rm -f /etc/udev/rules.d/99-usb-nosleep.rules
udevadm control --reload-rules
udevadm trigger

systemctl restart cups
echo "Uninstallation complete."
