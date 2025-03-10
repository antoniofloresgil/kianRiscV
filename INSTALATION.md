Below is a comprehensive guide in Markdown format for installing Apio on Ubuntu running under WSL2, configuring USB access, and running example projects.​

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
### 2. Downloading the Toolchain with Apio

To download and install all necessary toolchain packages (e.g., Icestorm, Icarus Verilog, SCons), run:

```bash
apio install --all
```

This command will automatically download and unpack the required packages for your FPGA projects.
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

usbipd list

This command will display the connected USB devices along with their bus IDs.

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
Ensure that a WSL command prompt is open to keep the WSL 2 lightweight VM active. 

### 3.4 Verify the USB Connection in Ubuntu

In your Ubuntu terminal, verify the device is visible by running:
```bash
lsusb
```

If the device appears in the list, it has been successfully attached.

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
Replace <example_name> with the exact name of the example you choose.
###4.3 Build, Simulate, and Upload the Example Project

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
apio build
```
Upload the Bitstream to Your FPGA:
```bash
apio upload
```
If everything runs correctly, you should see the example in action (e.g., LEDs blinking on your FPGA board).