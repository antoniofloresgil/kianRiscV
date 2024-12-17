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
// RISC-V Load Alignment Module - SystemVerilog Implementation
//
// This module implements the data alignment logic for load instructions in the
// RISC-V RV32IMA architecture. It processes the raw data read from memory
// based on the load operation type (`LB`, `LBU`, `LH`, `LHU`, `LW`) and 
// the address offset, extracting the appropriate byte(s) or halfword(s).
//
// Features:
// - Supports sign-extended and zero-extended loads for byte and halfword types.
// - Aligns 32-bit words directly without modification.
//

`default_nettype none
`include "riscv_defines.svh"

module load_alignment (
    input  logic [1:0]               addr,     // Address offset (2 LSBs of memory address)
    input  logic [`LOAD_OP_WIDTH-1:0] LOADop,  // Load operation type
    input  logic [31:0]              data,     // Data from memory
    output logic [31:0]              result    // Aligned load result
);

    // Load operation type decoding
    logic is_lb, is_lbu, is_lh, is_lhu, is_lw;

    assign is_lb  = (LOADop == `LOAD_OP_LB);   // Load Byte (sign-extended)
    assign is_lbu = (LOADop == `LOAD_OP_LBU);  // Load Byte Unsigned
    assign is_lh  = (LOADop == `LOAD_OP_LH);   // Load Halfword (sign-extended)
    assign is_lhu = (LOADop == `LOAD_OP_LHU);  // Load Halfword Unsigned
    assign is_lw  = (LOADop == `LOAD_OP_LW);   // Load Word (32-bit)

    always_comb begin
        result = 32'b0; // Default result initialization

        // Handle byte-aligned loads
        if (is_lb || is_lbu) begin
            case (addr[1:0])
                2'b00: result[7:0] = data[7:0];    // Byte 0
                2'b01: result[7:0] = data[15:8];   // Byte 1
                2'b10: result[7:0] = data[23:16];  // Byte 2
                2'b11: result[7:0] = data[31:24];  // Byte 3
                default: result[7:0] = 8'hx;
            endcase
            // Extend byte to 32 bits (sign or zero extension)
            result = is_lbu ? {24'b0, result[7:0]} : {{24{result[7]}}, result[7:0]};
        end

        // Handle halfword-aligned loads
        if (is_lh || is_lhu) begin
            case (addr[1])
                1'b0: result[15:0] = data[15:0];   // Halfword 0
                1'b1: result[15:0] = data[31:16];  // Halfword 1
                default: result[15:0] = 16'hx;
            endcase
            // Extend halfword to 32 bits (sign or zero extension)
            result = is_lhu ? {16'b0, result[15:0]} : {{16{result[15]}}, result[15:0]};
        end

        // Handle word-aligned loads
        if (is_lw) begin
            result = data;  // Directly assign the full 32-bit data
        end
    end

endmodule
