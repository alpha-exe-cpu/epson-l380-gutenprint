# Epson L380 Headless Print Server Deployment

This repository provides an automated deployment solution and a custom PPD architecture to transform a Linux machine (e.g., DietPi, Raspberry Pi OS) into a high-performance network print server for the USB-only **Epson L380**.

## 🛠️ Engineering Fixes

### 1. The 2cm Page Truncation Fix
Standard Gutenprint drivers often miscalculate the printable area for the L380, causing images to hit a "carriage limit" near the bottom of A4 paper, triggering a premature page eject. 
We fixed this by extracting hardware-level margin math (`8.4pt` margins) and injecting it into a custom PPD. This ensures the mobile rendering engine respects the hardware's physical limits.

### 2. Aggressive USB Patching
Linux power management often puts USB ports to "sleep" to save power, which disconnects the printer. This script:
* Forces the `usbcore` kernel module to ignore power-saving.
* Loops through all USB buses to force `power/control` to `on`.
* Installs a `udev` rule to ensure any device plugged into the bus stays awake indefinitely.

---

## 🏗️ Architecture

```text
                  ┌──────────────┐
                  │ Phone/Tablet │
                  └──────┬───────┘
                         │ AirPrint (mDNS)
                         ▼
┌───────────┐     ┌──────────────┐     ┌──────────────────┐
│  Windows  ├────►│ Socat Listen ├────►│ CUPS Queue       │     ┌─────────────┐
│  Desktop  │     │ (Port 9100)  │     │ Epson_L380_Series├───►│ Epson L380  │
└───────────┘     └──────────────┘     └──────────────────┘     └─────────────┘
  (Raw TCP)                            (Custom PPD)                (USB Wire)
```

* **AirPrint:** Handled by `cups` + `avahi` on port 631.
* **Windows Direct:** Handled by `socat` on port 9100, allowing Windows to print via raw TCP without needing SMB sharing or drivers on the Pi.

---

## 🚀 Quick Start

1. **Clone the repository:**
   ```bash
   sudo apt install git
   git clone https://github.com/alpha-exe-cpu/epson-l380-gutenprint.git
   cd epson-l380-gutenprint
   ```

2. **Deploy:**
   ```bash
   chmod +x install_l380.sh
   sudo ./install_l380.sh
   ```

3. **Post-Install:**
   Access your CUPS web admin (usually `http://<YOUR_IP>:631/admin`), go to **Printers**, select `Epson_L380_Series`, and ensure the driver is set to: 
   `"Epson L380 - CUPS+Gutenprint+Adrish v5.3.4-m1.0.0"`
