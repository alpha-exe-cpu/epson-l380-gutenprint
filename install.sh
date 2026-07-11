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
echo "Applying Aggressive USB No-Sleep Patch..."
# Disable global USB autosuspend in the kernel for the current session
echo "Applying maximum-aggression USB power-state policy..."

# 1. Disable global autosuspend for the kernel module
echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true

# 2. Iterate through all USB devices and force power control to 'on'
# This ensures even if a device is added late, it is immediately woken up
for device in /sys/bus/usb/devices/*/power/control; do
    echo "on" > "$device" 2>/dev/null || true
done

# 3. Add a udev rule that monitors and forces 'on' for any new device added
cat << 'EOF' > /etc/udev/rules.d/99-usb-nosleep.rules
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
EOF

# 4. Final hammer: ensure the controller itself doesn't sleep
for bus in /sys/bus/usb/devices/usb*; do
    echo "0" > "$bus/power/autosuspend_delay_ms" 2>/dev/null || true
done

# Create a permanent udev rule to force ALL USB devices to stay awake
cat << 'EOF' > /etc/udev/rules.d/99-usb-nosleep.rules
# Force power/control to 'on' and disable autosuspend for all USB devices
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
EOF

# Reload and trigger the udev rules immediately without a reboot
udevadm control --reload-rules
udevadm trigger
echo "USB power-saving permanently disabled."

# 4. Handle PPD Setup (Local File vs Web Download)
echo "Preparing PPD directory at $PPD_DIR..."
mkdir -p "$PPD_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_PPD="$SCRIPT_DIR/epson-l380-custom.ppd"

if [ -f "$LOCAL_PPD" ]; then
    echo "Found local PPD file at $LOCAL_PPD"
    echo "Skipping download and copying local file..."
    cp "$LOCAL_PPD" "$PPD_DEST"
else
    echo "No local PPD found in script directory. Downloading from GitHub..."
    PPD_URL="https://raw.githubusercontent.com/alpha-exe-cpu/epson-l380-gutenprint/refs/heads/main/epson-l380-custom.ppd"
    curl -sL "$PPD_URL" -o "$PPD_DEST"
fi

# Apply system permissions to PPD
echo "Applying strict system permissions..."
chmod 644 "$PPD_DEST"
chown root:root "$PPD_DEST"

# Restart CUPS so it indexes the new driver immediately
systemctl restart cups

# 5. Automatically discover USB printer and add to CUPS
echo "Detecting physical Epson USB connection..."
USB_URI=$(lpinfo -v | grep -i "usb://Epson" | head -n 1 | awk '{print $2}')

if [ -z "$USB_URI" ]; then
    echo "WARNING: No physical Epson USB connection detected via lpinfo."
    echo "Creating the queue using a fallback USB address..."
    USB_URI="usb://Epson/L380%20Series"
fi

echo "Adding printer queue '$PRINTER_QUEUE_NAME' to CUPS..."
# Clear any stale configurations to prevent conflicts
lpadmin -x "$PRINTER_QUEUE_NAME" 2>/dev/null || true
lpadmin -p "$PRINTER_QUEUE_NAME" -E -v "$USB_URI" -m "epson/$(basename$PPD_DEST)"

# Enable network sharing for this specific queue
lpadmin -p "$PRINTER_QUEUE_NAME" -o printer-is-shared=true

# Set baseline driver options
echo "Setting driver safe-zone parameters..."
lpadmin -p "$PRINTER_QUEUE_NAME" -o PageSize=A4
lpadmin -p "$PRINTER_QUEUE_NAME" -o StpiShrinkOutput=Shrink

# 6. Create and enable the Permanent background socat service
echo "Generating systemd service file for Windows Port 9100..."
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

echo "Enabling and launching raw-printer system service..."
systemctl daemon-reload
systemctl enable raw-printer.service
systemctl restart raw-printer.service

# 7. Restart network broadcast service
echo "Restarting Avahi discovery broadcast..."
systemctl restart avahi-daemon

echo "======================================================="
echo "Setup Complete!"
echo "Selected Printer Queue: $PRINTER_QUEUE_NAME"
echo 'Select "Epson L380 - CUPS+Gutenprint+Adrish v5.3.4-m1.0.0" as printer model from the Epson/ make directory.'
echo "Windows Raw Network Pipe open on Port 9100."
echo "======================================================="
