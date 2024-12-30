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
// RISC-V Multiplier and Divider Extension Decoder - SystemVerilog Implementation
//
// This module acts as a combined decoder for both multiplier and divider operations
// in the RISC-V RV32IM instruction set. It integrates the `multiplier_decoder` and
// `divider_decoder` modules to decode the funct3 field and generate valid signals
// for multiplication and division operations.
//
// Features:
// - Decodes funct3 to determine multiplier and divider operations.
// - Generates valid signals for both multiplier and divider units.
// - Uses modular design with `multiplier_decoder` and `divider_decoder`.
//

`default_nettype none
`include "riscv_defines.svh"

module multiplier_extension_decoder (
    input  wire [2:0]                  funct3,         // funct3 field from instruction
    output logic [`MUL_OP_WIDTH-1:0]   MULop,          // Multiplier operation code
    output logic [`DIV_OP_WIDTH-1:0]   DIVop,          // Divider operation code
    input  wire                        mul_ext_valid,  // Multiplier external valid signal
    output logic                       mul_valid,      // Multiplier valid signal
    output logic                       div_valid       // Divider valid signal
);

    // Instance of Multiplier Decoder
    multiplier_decoder multiplier_I (
        .funct3          (funct3),
        .MULop           (MULop),
        .mul_ext_valid   (mul_ext_valid),
        .mul_valid       (mul_valid)
    );

    // Instance of Divider Decoder
    divider_decoder divider_I (
        .funct3          (funct3),
        .DIVop           (DIVop),
        .mul_ext_valid   (mul_ext_valid),
        .div_valid       (div_valid)
    );

endmodule

