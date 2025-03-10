# Complete Guide: Installing and Using Apio on Ubuntu (WSL2) with USB Access and Example Projects

This guide covers the following steps:

- Installing Apio on Ubuntu running under WSL2 on Windows
- Configuring USB access from Ubuntu to a USB device connected to Windows
- Downloading and running example projects provided with Apio

---

## 1. Installing Apio on Ubuntu (WSL2)

### 1.1 Update the System and Install Dependencies

Open your Ubuntu terminal in WSL2 and run:

```bash
sudo apt update
sudo apt install python3-pip python3-venv usbutils
```
### 1.2 Create and Activate a Virtual Environment (Recommended)

Create a virtual environment to isolate Apio and its dependencies:

```bash
python3 -m venv venv
source venv/bin/activate
```
### 1.3 Install Apio via pip

Within the virtual environment, install Apio:
```bash
pip install apio
```
Verify the installation:

```bash
apio --version
```
### 2. Downloading the Toolchain with Apio and enable FTDI drivers

To download and install all necessary toolchain packages (e.g., Icestorm, Icarus Verilog, SCons), run:

```bash
apio install --all
```
This command will automatically download and unpack the required packages for your FPGA projects.

To enable FTDI drivers, run:

```bash
$ apio drivers --ftdi-enable
Configure FTDI drivers for FPGA
FTDI drivers enabled
Unplug and reconnect your board
```

## 3. Configuring USB Access in WSL2

Since Ubuntu is running under WSL2, you will use usbipd-win to access USB devices connected to Windows.

### 3.1 Install usbipd-win on Windows

Open a PowerShell window as Administrator and install usbipd-win using the Windows Package Manager (winget):

```powershell
winget install --interactive --exact dorssel.usbipd-win
```
Alternatively, you can download the installer from the usbipd-win releases page and run the .msi file.

### 3.2 List Available USB Devices

Connect your USB device to your PC. In PowerShell, run:
```powershell
usbipd list
```

This command will display the connected USB devices along with their bus IDs. For example:

```powershell
Connected:
BUSID  VID:PID    DEVICE                                                        STATE
1-1    23c5:1478  UVC Camera, AC Interface                                      Not shared
1-2    0403:6015  USB Serial Converter                                          Not shared
1-3    0461:4e90  Dispositivo de entrada USB                                    Not shared
1-4    046d:c542  Dispositivo de entrada USB                                    Not shared
1-5    05c8:0437  HP 2.0MP High Definition Webcam                               Not shared
1-7    0bda:b00b  Realtek Bluetooth 4.2 Adapter                                 Not shared
```

### 3.3 Bind and Attach the USB Device to WSL2

Bind the USB Device:

Select the bus ID of the device you want to use and run:
```powershell
usbipd bind --busid <busid>
```

Replace <busid> with the actual identifier from the list.

Attach the USB Device:

After binding, attach the device to WSL2:
```powershell
usbipd wsl attach --busid <busid>
```
Ensure that a WSL command prompt is open to keep the WSL 2 lightweight VM active. Output should be similar to:

```powershell
PS C:\Windows\System32> usbipd attach --wsl --busid 1-2
usbipd: info: Using WSL distribution 'Ubuntu' to attach; the device will be available in all WSL 2 distributions.
usbipd: info: Detected networking mode 'nat'.
usbipd: info: Using IP address 172.30.160.1 to reach the host.
PS C:\Windows\System32>
```

### 3.4 Verify the USB Connection in Ubuntu

In your Ubuntu terminal, verify the device is visible by running:
```bash
lsusb
```

If the device appears in the list, it has been successfully attached.
```bash
aflores@DESKTOP-435SAPH:~$ lsusb
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 001 Device 002: ID 0403:6015 Future Technology Devices International, Ltd Bridge(I2C/SPI/UART/FIFO)
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
aflores@DESKTOP-435SAPH:~$
```

## 4. Downloading and Running an Apio Example

Apio provides example FPGA projects to help you get started.
### 4.1 List Available Examples

To list all available examples, run:
```bash
apio examples -l
```

This command will display a list of example project names and descriptions.
### 4.2 Download a Specific Example

Select an example from the list. For instance, if you want to use a blinking LED example (the example name may vary, such as ulx3s-12f/Blinky or icestick/leds), run:
```bash
apio examples -f <example_name>
```
Replace <example_name> with the exact name of the example you choose. We'll use the ulx3s-85f/Blinky example.
### 4.3 Build, Simulate, and Upload the Example Project

Navigate to the downloaded example project folder and perform the following steps:

Verify the Verilog Code:
```bash
apio verify
```
### Simulate the Design (Optional):

To view the waveform using GTKWave:

```bash
apio sim
```
Build the Project (Synthesize and Generate Bitstream):
```bash
$ apio build
[Mon Mar 10 12:54:40 2025] Processing ulx3s-85f
------------------------------------------------------------------------------------------------------------------------
yosys -p "synth_ecp5 -top top -json hardware.json" -q blinky.v
nextpnr-ecp5 --85k --package CABGA381 --json hardware.json --textcfg hardware.config --lpf ulx3s_v20.lpf -q --timing-allow-fail --force
ecppack --compress --db /home/aflores/.apio/packages/tools-oss-cad-suite/share/trellis/database hardware.config hardware.bit
```


Upload the Bitstream to Your FPGA:
```bash
$ apio upload
[Mon Mar 10 13:13:22 2025] Processing ulx3s-85f
------------------------------------------------------------------------------------------------------------------------
yosys -p "synth_ecp5 -top top -json hardware.json" -q blinky.v
nextpnr-ecp5 --85k --package CABGA381 --json hardware.json --textcfg hardware.config --lpf ulx3s_v20.lpf -q --timing-allow-fail --force
sed: can't read /home/aflores/.apio/packages/tools-oss-cad-suite/etc/fonts/fonts.conf.template: No such file or directory
fujprog -l 2 hardware.bit
Programming: 20%
Programming: 37%
Programming: 54%
Programming: 71%
Programming: 88%
Programming: 100%
Completed in 4.68 seconds.
ULX2S / ULX3S JTAG programmer v4.8 (git cc3ea93 built Nov 15 2022 18:03:02)
Copyright (C) Marko Zec, EMARD, gojimmypi, kost and contributors
Using USB cable: ULX3S FPGA 85K v3.0.8
============================================= [SUCCESS] Took 6.88 seconds =============================================
```
If everything runs correctly, you should see the example in action (e.g., LEDs blinking on your FPGA board).