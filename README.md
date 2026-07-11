# Epson L380 Headless Print Server Deployment

This repository houses an automated deployment solution and a reverse-engineered PostScript Printer Description (PPD) architecture to transform a lightweight Linux machine (e.g., DietPi or Raspberry Pi OS) into a high-performance network print server for the USB-only **Epson L380**.

---

## 🛠️ The Core Issue & The Engineering Fix

### The 2cm Page Truncation / Drop-Size Panics
When connecting mobile engines (iOS AirPrint or Android Default Print Services) to an Epson L-series printer using generic open-source Gutenprint drivers, multi-page print loops frequently break or cut off early. 

Gutenprint defaults its physical coordinate metrics for custom vector spaces to `0.000` boundaries (absolute boundary translation). However, the physical paper tray rollers on standard Epson hardware require an explicit physical margin safe-zone to keep tension on the paper sheet as it exits the print car. 

Without explicit boundaries defined in software, the mobile graphics context sends print streams that overflow the printable canvas. The driver encounters a hardware carriage boundary constraint, interprets the edge-overflow as an implied completion of "Page 1," prematurely triggers a hard-eject, and shoves the remaining 2cm of data onto a second page.

### The PPD Mod Details
To resolve this anomaly without losing target execution speed or scaling accuracy on ARM64 architectures, the driver profile here (`Epson L380 - CUPS+Gutenprint+Adrish v5.3.4-m1.0.0`) was compiled by extracting the exact physical rendering equations from Epson's proprietary x86 execution architecture (`ESC/P-R`) and retrofitting them directly into Gutenprint's token stream block definitions.

The baseline limits were rewritten from zero-ground constraints to strict vector safe-points:

* **Target Page Definition Mapping:** Adjusted bounds to fractional scaling vectors (`595.3 x 841.9` PostScript points).
* **ImageableArea Coordinates:** Constrained bounding limits exactly to the hardware envelope bounds:
  ```text
  *ImageableArea A4/A4 210 x 297 mm: "8.4 8.4 586.9 833.5"
  ```
This structural constraint explicitly informs the source mobile rendering engine to scale down graphics contexts linearly into safe print bounds before pushing raw data downstream.

---

## 🏗️ Multi-Protocol Architecture

The automated configuration sets up two isolated pipelines to communicate concurrently with separate network environments:

```text
                  ┌──────────────┐
                  │ Phone/Tablet │
                  └──────┬───────┘
                         │ AirPrint / mDNS (Port 631)
                         ▼
┌───────────┐     ┌──────────────┐     ┌──────────────────┐
│  Windows  ├────►│ Socat Listen ├────►│ CUPS Queue       │     ┌─────────────┐
│  Desktop  │     │ (Port 9100)  │     │ Epson_L380_Series├───►│ Epson L380  │
└───────────┘     └──────────────┘     └──────────────────┘     └─────────────┘
  (Raw TCP Pipe)                       (Custom Adrish PPD)         (USB Wire)
```

1. **AirPrint/Android Service Loop:** Broadcasts natively through Avahi/mDNS daemon layers over network port `631`. This path uses the newly modified engine driver to transcode universal raster targets locally on the host CPU.
2. **Windows Serverless Pipeline:** Implements a direct, unauthenticated socket abstraction via a `socat` listener tied permanently to network Port `9100`. Windows clients compile data patterns natively using locally installed generic manufacturer drivers and stream raw PostScript code down the socket. This bypasses restrictive Windows enterprise SMB signing limitations.

---

## 🚀 Execution & Deployment Instructions

### 1. Repository Cloning
Clone this repository to a working folder directly on your target print server hardware:

```bash
git clone [https://github.com/alpha-exe-cpu/epson-l380-gutenprint.git](https://github.com/alpha-exe-cpu/epson-l380-gutenprint.git)
cd epson-l380-gutenprint
```

### 2. Run the Automation Engine
Grant immediate script execution privileges and trigger the automated pipeline installer:

```bash
chmod +x install_l380.sh
sudo ./install_l380.sh
```

The installer logic auto-probes dependencies, pulls baseline library contexts, verifies local file availability for `epson-l380-custom.ppd` before safely falling back to web mirrors, builds the systemd task loop (`raw-printer.service`), and registers the hardware instance with CUPS under the strict identifier **`Epson_L380_Series`**.

### 3. Client Station Additions (Windows Link)

To connect workstations to the newly instantiated high-availability Port 9100 endpoint:

1. Launch the classic Windows printer wizard by running `control printers` via **Win + R**.
2. Click **Add a printer** -> Select **The printer that I want isn't listed**.
3. Choose **Add a printer using an IP address or hostname** and select **TCP/IP Device**.
4. Pass the exact host IP address of your printing node (e.g., `192.168.0.35`). Make sure *Query the printer* is unchecked.
5. On the subsequent fallback prompt, select **Generic Network Card**.
6. When prompted for the local device driver, choose **Epson** -> **EPSON L380 Series** (or choose *Have Disk* if mapping original vendor driver files).
