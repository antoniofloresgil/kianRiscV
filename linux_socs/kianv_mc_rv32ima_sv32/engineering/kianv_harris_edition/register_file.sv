//
// Copyright (c) 2023 Hirosh Dabui <hirosh@dabui.de>
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
// RISC-V Register File - SystemVerilog Implementation
//
// This module implements a 32x32-bit register file for the RISC-V RV32IMA architecture.
// It provides two read ports and one write port, supporting synchronous write operations.
//
// Features:
// - Supports 32 registers, where register x0 is hardwired to zero.
// - Two simultaneous read operations and one write operation per clock cycle.
//

`default_nettype none

module register_file (
    input wire        clk,            // Clock signal
    input wire        we,             // Write enable
    input wire [4:0]  A1,             // Read address 1
    input wire [4:0]  A2,             // Read address 2
    input wire [4:0]  A3,             // Write address
    input wire [31:0] wd,             // Write data
    output logic [31:0] rd1,            // Read data 1
    output logic [31:0] rd2             // Read data 2
);

    // Register bank: 32 registers, 32 bits each
    logic [31:0] bank0 [31:0];          // Register file array

    // Synchronous write: Only write when we is enabled and A3 is not zero
    always_ff @(posedge clk) begin
        if (we && (A3 != 0)) begin
            bank0[A3] <= wd;
        end
    end

    // Asynchronous read: Output data from registers, x0 hardwired to zero
    assign rd1 = (A1 != 0) ? bank0[A1] : 32'b0;
    assign rd2 = (A2 != 0) ? bank0[A2] : 32'b0;

endmodule

