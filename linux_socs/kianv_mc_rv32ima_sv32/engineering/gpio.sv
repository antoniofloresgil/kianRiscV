//
// Copyright (c) 2022 Hirosh Dabui <hirosh@dabui.de>
// Port to SystemVerilog Copyright (c) 2024 Antonio Flores <aflores@um.es>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// GPIO Module - SystemVerilog Implementation
//
// This module implements a General Purpose Input/Output (GPIO) controller. 
// It allows bidirectional communication through configurable GPIO pins, 
// enabling both input and output functionality. The module provides a 
// simple register-based interface for configuration and data access.
//
// Features:
// - Parameterizable number of GPIO pins (`GPIO_NR`).
// - Supports bidirectional GPIO functionality (input/output).
// - Control registers for configuring pin direction and setting output values.
// - Ability to read the current input values of the GPIO pins.
// - Compatible with a standard memory-mapped interface.
//
//
`default_nettype none

module gpio #(
    parameter GPIO_NR = 8
) (
    input  logic                clk,
    input  logic                resetn,
    input  logic [         3:0] addr,
    input  logic [         3:0] wrstb,
    input  logic [        31:0] wdata,
    output logic [        31:0] rdata,
    input  logic                valid,
    output logic                ready,
    inout  wire [GPIO_NR -1:0] gpio
);

    logic [GPIO_NR -1:0] gpio_out_en;
    logic [GPIO_NR -1:0] gpio_in;
    logic [GPIO_NR -1:0] gpio_out_val;

    // Read the input value of the GPIO pins
    assign gpio_in = gpio;

    genvar i;
    // Assigning output values
    generate
        for (i = 0; i < GPIO_NR; i++) begin : GPIO_GEN
            assign gpio[i] = gpio_out_en[i] ? gpio_out_val[i] : 1'bz;
        end
    endgenerate

    logic wr;

    assign wr = |wrstb;

    // Ready signal logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) 
            ready <= 1'b0;
        else 
            ready <= valid;
    end

    // Control logic for GPIO
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            gpio_out_en  <= '0;  // default all pins as input
            gpio_out_val <= '0;  // default all output values to 0
        end else begin
            if (valid) begin
                unique case (addr)
                    4'h0: begin // 1 output, 0 input
                        if (wr) 
                            gpio_out_en <= wdata[GPIO_NR-1:0];
                        else 
                            rdata <= {24'b0, gpio_out_en};
                    end
                    4'h4: begin // Set or Get the output value
                        if (wr) 
                            gpio_out_val <= wdata[GPIO_NR-1:0];
                        else 
                            rdata <= {24'b0, gpio_out_val};
                    end
                    4'h8: begin // Get the input value
                        if (!wr) 
                            rdata <= {24'b0, gpio_in};
                    end
                    default: begin
                        rdata <= 32'b0; // Default case ensures no stale values
                    end
                endcase
            end
        end
    end

endmodule
