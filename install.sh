#!/bin/bash

# Stop the script immediately if any command fails
set -e

# Configuration Variables
PRINTER_QUEUE_NAME="Epson_L380_Series"
PPD_DIR="/usr/share/cups/model/epson"
PPD_DEST="$PPD_DIR/epson-l380-custom.ppd"
SERVICE_FILE="/etc/systemd/system/raw-printer.service"

echo "======================================================="
echo "Starting Complete Epson L380 Network Server Setup..."
echo "Make sure the printer is connected via USB."
echo "If it is not connected, please connect it now."
echo "Press [Enter] to continue or Ctrl+C (^C) to exit..."
echo "======================================================="
read -r

# 1. Update package lists
echo "Updating apt repositories..."
apt update

# 2. Install core system packages
echo "Installing CUPS, Gutenprint, Avahi, socat, and curl..."
apt install -y cups printer-driver-gutenprint avahi-daemon socat curl

# 3. Apply Aggressive USB No-Sleep Patch
echo "Applying maximum-aggression USB power-state policy..."
echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true

for device in /sys/bus/usb/devices/*/power/control; do
    echo "on" > "$device" 2>/dev/null || true
done

for bus in /sys/bus/usb/devices/usb*; do
    echo "0" > "$bus/power/autosuspend_delay_ms" 2>/dev/null || true
done

cat << 'EOF' > /etc/udev/rules.d/99-usb-nosleep.rules
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
EOF

udevadm control --reload-rules
udevadm trigger
echo "USB power-saving permanently disabled."

# 4. Handle PPD Setup
echo "Preparing PPD directory at $PPD_DIR..."
mkdir -p "$PPD_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_PPD="$SCRIPT_DIR/epson-l380-custom.ppd"

if [ -f "$LOCAL_PPD" ]; then
    echo "Found local PPD file. Copying..."
    cp "$LOCAL_PPD" "$PPD_DEST"
else
    echo "Downloading PPD from GitHub..."
    PPD_URL="https://raw.githubusercontent.com/alpha-exe-cpu/epson-l380-gutenprint/refs/heads/main/epson-l380-custom.ppd"
    curl -sL "$PPD_URL" -o "$PPD_DEST"
fi

chmod 644 "$PPD_DEST"
chown root:root "$PPD_DEST"
systemctl restart cups

# 5. Automatically discover USB printer and add to CUPS
USB_URI=$(lpinfo -v | grep -i "usb://Epson" | head -n 1 | awk '{print $2}')
[ -z "$USB_URI" ] && USB_URI="usb://Epson/L380%20Series"

echo "Adding printer queue '$PRINTER_QUEUE_NAME'..."
lpadmin -x "$PRINTER_QUEUE_NAME" 2>/dev/null || true
lpadmin -p "$PRINTER_QUEUE_NAME" -E -v "$USB_URI" -m "epson/$(basename "$PPD_DEST")"
lpadmin -p "$PRINTER_QUEUE_NAME" -o printer-is-shared=true
lpadmin -p "$PRINTER_QUEUE_NAME" -o PageSize=A4
lpadmin -p "$PRINTER_QUEUE_NAME" -o StpiShrinkOutput=Shrink

# 6. Setup socat service
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Raw TCP Printer Forwarding for Windows (Port 9100)
After=network.target cups.service

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP4-LISTEN:9100,reuseaddr,fork EXEC:"lp -d $PRINTER_QUEUE_NAME -"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable raw-printer.service
systemctl restart raw-printer.service
systemctl restart avahi-daemon

echo "======================================================="
echo "Setup Complete!"
echo 'Select "Epson L380 - CUPS+Gutenprint+Adrish v5.3.4-m1.0.0" as printer model.'
echo "======================================================="
