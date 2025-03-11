# Using Apio and Yosys for a SystemVerilog Project

This guide will walk you through the steps to create a SystemVerilog project using Apio and Yosys for the ULX3S-85F board.

## Prerequisites

Before you begin, ensure you have the following installed on your system:
- [Python](https://www.python.org/downloads/)
- [Apio](https://github.com/FPGAwars/apio)
- [Yosys](http://www.clifford.at/yosys/)
- [ULX3S-85F Board](https://github.com/emard/ulx3s)
- Packages for RISC-V cross-compilation on Ubuntu:
    ```sh
    git clone https://github.com/riscv/riscv-gnu-toolchain
    sudo apt-get install autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build
    ./configure --prefix=/opt/riscv --with-arch=rv32gc --with-abi=ilp32d
    make linux
    ```
    And then add /opt/riscv/bin to your PATH.
## Step 1: Create a New Project

1. Create a new directory for your project:
    ```sh
    mkdir my_systemverilog_project
    cd my_systemverilog_project
    ```
2. Initialize a new Apio project:
    ```sh
    apio init --board ulx3s-85f
    ```

## Step 2: Write Your SystemVerilog Code

1. Create a new file for your SystemVerilog code, e.g., `main.sv`:
    ```sh
    touch main.sv
    ```
2. Open `main.sv` in your preferred text editor and write your SystemVerilog code. For example:
    ```systemverilog
    module top (
        input wire clk,
        input wire rst,
        output wire led
    );
        reg [3:0] counter;
        
        always @(posedge clk or posedge rst) begin
            if (rst)
                counter <= 4'b0000;
            else
                counter <= counter + 1;
        end
        
        assign led = counter[3];
    endmodule
    ```

## Step 3: Create Constraints File

1. Create a constraints file, e.g., `constraints.lpf`:
    ```sh
    touch constraints.lpf
    ```
2. You can either write your own constraints or download a constraints file from the [ULX3S repository](https://github.com/emard/ulx3s/tree/master/doc/constraints). For example:
    ```lpf
    LOCATE COMP "clk" SITE "P11";
    LOCATE COMP "rst" SITE "P12";
    LOCATE COMP "led" SITE "P13";
    ```

## Step 4: Synthesize with Yosys

1. Create a Yosys script file, e.g., `synth.ys`:
    ```sh
    touch synth.ys
    ```
2. Open `synth.ys` in your text editor and add the following commands:
    ```yosys
    read_verilog main.sv
    synth -top top
    write_json top.json
    ```
3. Run Yosys to synthesize your design:
    ```sh
    yosys synth.ys
    ```

## Step 5: Build and Upload with Apio

1. Create an Apio configuration file, e.g., `apio.ini`:
    ```sh
    touch apio.ini
    ```
2. Open `apio.ini` and configure it for your FPGA board. For the ULX3S-85F board:
    ```ini
    [env]
    board = ulx3s-85f

    [build]
    toolchain = trellis
    constraints = constraints.lpf
    ```

3. Build your project:
    ```sh
    apio build
    ```
4. Upload your project to the FPGA:
    ```sh
    apio upload
    ```

## Conclusion

You have now created a SystemVerilog project using Apio and Yosys for the ULX3S-85F board. You can modify your SystemVerilog code and repeat the synthesis and build steps to update your project.

For more information, refer to the [Apio documentation](https://docs.apio.io/), the [Yosys manual](http://www.clifford.at/yosys/files/yosys_manual.pdf), and the [ULX3S-85F repository](https://github.com/emard/ulx3s).

## Setting Up a RISC-V Cross-Compiler and Generating a Linux System

In this section, we will guide you through the steps to set up a RISC-V cross-compiler, generate a Linux system, and create a filesystem that can be installed on a microSD card to run Linux on the FPGA with a synthesized RISC-V softcore processor.

### Step 1: Install RISC-V GNU Toolchain

1. Clone the RISC-V GNU toolchain repository:
    ```sh
    git clone https://github.com/riscv/riscv-gnu-toolchain
    ```
2. Install the required dependencies:
    ```sh
    sudo apt-get install autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build
    ```
3. Configure and build the toolchain with Newlib:
    ```sh
    cd riscv-gnu-toolchain
    ./configure --prefix=/opt/riscv --with-arch=rv32im --with-abi=ilp32 --enable-multilib
    make newlib
    ```
4. Add the toolchain to your PATH:
    ```sh
    export PATH=/opt/riscv/bin:$PATH
    ```

### Step 2: Build the Linux Kernel

1. Clone the Linux kernel repository for RISC-V:
    ```sh
    git clone https://github.com/riscv/riscv-linux
    cd riscv-linux
    ```
2. Configure the kernel for your target:
    ```sh
    make ARCH=riscv defconfig
    ```
3. Build the kernel:
    ```sh
    make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- -j$(nproc)
    ```

### Step 3: Create a Root Filesystem

1. Download and extract a root filesystem for RISC-V:
    ```sh
    wget https://example.com/riscv-rootfs.tar.gz
    tar -xzf riscv-rootfs.tar.gz -C /path/to/rootfs
    ```

### Step 4: Prepare the microSD Card

1. Insert the microSD card into your computer and identify its device name (e.g., `/dev/sdX`).
2. Partition the microSD card:
    ```sh
    sudo fdisk /dev/sdX
    ```
    - Create a new partition and set its type to Linux (type 83).
3. Format the partition:
    ```sh
    sudo mkfs.ext4 /dev/sdX1
    ```
4. Mount the partition:
    ```sh
    sudo mount /dev/sdX1 /mnt
    ```

### Step 5: Install the Root Filesystem

1. Copy the root filesystem to the microSD card:
    ```sh
    sudo cp -r /path/to/rootfs/* /mnt
    ```
2. Unmount the microSD card:
    ```sh
    sudo umount /mnt
    ```

### Step 6: Boot Linux on the FPGA

1. Insert the microSD card into the FPGA board.
2. Power on the FPGA board and configure it to boot from the microSD card.
3. The board should now boot into the Linux system running on the RISC-V softcore processor.

Congratulations! You have successfully set up a RISC-V cross-compiler, generated a Linux system, and created a filesystem to run Linux on your FPGA with a synthesized RISC-V softcore processor.



