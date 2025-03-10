# HOW-TO: Using Apio and Yosys for a SystemVerilog Project

This guide will walk you through the steps to create a SystemVerilog project using Apio and Yosys.

## Prerequisites

Before you begin, ensure you have the following installed on your system:
- [Python](https://www.python.org/downloads/)
- [Apio](https://github.com/FPGAwars/apio)
- [Yosys](http://www.clifford.at/yosys/)

## Step 1: Create a New Project

1. Create a new directory for your project:
    ```sh
    mkdir my_systemverilog_project
    cd my_systemverilog_project
    ```
2. Initialize a new Apio project:
    ```sh
    apio init --project
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

## Step 3: Synthesize with Yosys

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

## Step 4: Build and Upload with Apio

1. Create an Apio configuration file, e.g., `apio.ini`:
    ```sh
    touch apio.ini
    ```
2. Open `apio.ini` and configure it for your FPGA board. For example, for an iCE40 board:
    ```ini
    [env]
    board = iCE40-HX8K-B-EVN

    [build]
    toolchain = icestorm
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

You have now created a SystemVerilog project using Apio and Yosys. You can modify your SystemVerilog code and repeat the synthesis and build steps to update your project.

For more information, refer to the [Apio documentation](https://docs.apio.io/) and the [Yosys manual](http://www.clifford.at/yosys/files/yosys_manual.pdf).