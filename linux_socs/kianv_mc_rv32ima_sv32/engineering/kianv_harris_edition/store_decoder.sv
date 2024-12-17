
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
// RISC-V Store Decoder - SystemVerilog Implementation
//
// This module decodes the store instruction's funct3 field and determines
// the store operation type (SB, SH, SW) for the RISC-V RV32IM architecture.
// It also detects unaligned store operations.
//
// Features:
// - Decodes funct3 for Store Byte (SB), Store Halfword (SH), and Store Word (SW).
// - Handles atomic memory operations (AMO) store signals.
// - Detects unaligned memory accesses based on address alignment bits.
//

`default_nettype none
`include "riscv_defines.svh"

module store_decoder (
    input  logic [2:0]                 funct3,               // funct3 field from instruction
    input  logic                       amo_operation_store,  // AMO store operation flag
    output logic [`STORE_OP_WIDTH-1:0] STOREop,              // Store operation output
    input  logic [1:0]                 addr_align_bits,      // Address alignment bits
    output logic                       is_store_unaligned    // Flag for unaligned stores
);

    // Internal wire declarations for store operation decoding
    logic is_sb, is_sh, is_sw;

    assign is_sb = (funct3[1:0] == 2'b00);
    assign is_sh = (funct3[1:0] == 2'b01);
    assign is_sw = (funct3[1:0] == 2'b10);

    // Main decoding logic
    always_comb begin
        // Default assignments
        STOREop            = `STORE_OP_SB;
        is_store_unaligned = 1'b0;

        if (!amo_operation_store) begin
            case (1'b1)
                is_sb: STOREop = `STORE_OP_SB;

                is_sh: begin
                    STOREop            = `STORE_OP_SH;
                    is_store_unaligned = addr_align_bits[0];  // Unaligned if addr[0] is set
                end

                is_sw: begin
                    STOREop            = `STORE_OP_SW;
                    is_store_unaligned = |addr_align_bits;    // Unaligned if any bit in addr_align_bits is set
                end

                default: STOREop = `STORE_OP_SB; // Default to SB operation
            endcase
        end else begin
            // For AMO store operations, force SW and detect unaligned address
            STOREop            = `STORE_OP_SW;
            is_store_unaligned = |addr_align_bits;
        end
    end

endmodule

