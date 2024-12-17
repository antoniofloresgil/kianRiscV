
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
// RISC-V Load Decoder Module - SystemVerilog Implementation
//
// This module decodes the `funct3` field of the RISC-V load instructions
// and determines the appropriate load operation type (`LB`, `LBU`, `LH`, `LHU`, `LW`).
// Additionally, it detects unaligned memory accesses based on the address alignment.
//
// Features:
// - Decodes load operation type for sign-extended and zero-extended loads.
// - Identifies unaligned loads for halfword (`LH`) and word (`LW`) operations.
// - Supports atomic memory operations (AMO).
//

`default_nettype none
`include "riscv_defines.svh"

module load_decoder (
    input  logic [2:0]                   funct3,          // funct3 field from instruction
    input  logic                         amo_data_load,   // Flag for atomic memory operations
    output logic [`LOAD_OP_WIDTH-1:0]    LOADop,          // Load operation type
    input  logic [1:0]                   addr_align_bits, // Address alignment bits
    output logic                         is_load_unaligned // Flag for unaligned load
);

    // Decode load operation types
    logic is_lb, is_lh, is_lw, is_lbu, is_lhu;

    assign is_lb  = (funct3 == 3'b000); // Load Byte
    assign is_lh  = (funct3 == 3'b001); // Load Halfword
    assign is_lw  = (funct3 == 3'b010); // Load Word
    assign is_lbu = (funct3 == 3'b100); // Load Byte Unsigned
    assign is_lhu = (funct3 == 3'b101); // Load Halfword Unsigned

    always_comb begin
        is_load_unaligned = 1'b0; // Default: aligned load
        if (!amo_data_load) begin
            case (1'b1)
                is_lb:  LOADop = `LOAD_OP_LB;   // Load Byte
                is_lbu: LOADop = `LOAD_OP_LBU;  // Load Byte Unsigned
                is_lhu: LOADop = `LOAD_OP_LHU;  // Load Halfword Unsigned

                is_lh: begin
                    LOADop = `LOAD_OP_LH;      // Load Halfword
                    is_load_unaligned = addr_align_bits[0]; // Detect unaligned halfword access
                end

                is_lw: begin
                    LOADop = `LOAD_OP_LW;      // Load Word
                    is_load_unaligned = |addr_align_bits; // Detect unaligned word access
                end

                default: LOADop = `LOAD_OP_LB; // Default case (safe load type)
            endcase
        end else begin
            // AMO (Atomic Memory Operation) loads are treated as aligned word loads
            LOADop = `LOAD_OP_LW;
            is_load_unaligned = |addr_align_bits; // Detect unaligned word access
        end
    end

endmodule
