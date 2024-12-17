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
/// RISC-V Multiplier Decoder Module - SystemVerilog Implementation
//
// This module decodes the funct3 field of the RISC-V RV32IM instruction set
// to generate control signals for multiplication operations. It supports
// signed, unsigned, and mixed-sign multiplications.
//
// Features:
// - Decodes `funct3` to determine the multiplication operation.
// - Generates a valid signal based on instruction validity.
// - Supports four types of multiplication: MUL, MULH, MULHSU, MULHU.
//

`default_nettype none
`include "riscv_defines.svh"

module multiplier_decoder (
    input  logic [2:0]                  funct3,         // funct3 field from instruction
    output logic [`MUL_OP_WIDTH-1:0]    MULop,          // Multiplier operation code
    input  logic                        mul_ext_valid,  // Multiplier external valid signal
    output logic                        mul_valid       // Multiplier valid signal
);

    // Internal signals for detecting multiplication operation types
    logic is_mul;     // Signed multiplication (low part)
    logic is_mulh;    // Signed multiplication (high part)
    logic is_mulsu;   // Mixed signed-unsigned multiplication
    logic is_mulu;    // Unsigned multiplication

    // Internal valid signal
    logic valid;

    // Decode funct3 field
    assign is_mul   = (funct3 == 3'b000);
    assign is_mulh  = (funct3 == 3'b001);
    assign is_mulsu = (funct3 == 3'b010);
    assign is_mulu  = (funct3 == 3'b011);

    // Combine valid signal
    assign mul_valid = valid & mul_ext_valid;

    // Multiplication operation decoding
    always_comb begin
        valid = 1'b1;  // Assume valid by default
        case (1'b1)
            is_mul:   MULop = `MUL_OP_MUL;    // Signed multiplication
            is_mulh:  MULop = `MUL_OP_MULH;   // Signed high multiplication
            is_mulsu: MULop = `MUL_OP_MULSU;  // Mixed signed-unsigned multiplication
            is_mulu:  MULop = `MUL_OP_MULU;   // Unsigned multiplication
            default: begin
                MULop = 'hxx;  // Invalid operation
                valid = 1'b0;  // Set valid signal to false
            end
        endcase
    end

endmodule
