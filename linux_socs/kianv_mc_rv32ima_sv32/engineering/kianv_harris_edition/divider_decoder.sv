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
// RISC-V Divider Decoder Module - SystemVerilog Implementation
//
// This module decodes the 'funct3' field of RISC-V RV32IM instructions
// to determine the specific division or remainder operation.
// It outputs control signals for signed and unsigned division/remainder operations
// and ensures the validity of operations with appropriate flags.
//

`default_nettype none
`include "riscv_defines.svh"

module divider_decoder (
    input  wire [2:0]                  funct3,        // 'funct3' field from instruction
    output logic [`DIV_OP_WIDTH-1:0]   DIVop,         // Division operation output
    input  wire                        mul_ext_valid, // Multiplier/Divider external validity flag
    output logic                       div_valid      // Division valid flag
);

    // Internal wires for decoding 'funct3'
    logic is_div;
    logic is_divu;
    logic is_rem;
    logic is_remu;

    // Valid signal to ensure proper operation
    logic valid;

    // Decode the funct3 field to determine the operation
    assign is_div  = (funct3 == 3'b100); // Signed division
    assign is_divu = (funct3 == 3'b101); // Unsigned division
    assign is_rem  = (funct3 == 3'b110); // Signed remainder
    assign is_remu = (funct3 == 3'b111); // Unsigned remainder

    // Combine valid signal with external validity flag
    assign div_valid = valid & mul_ext_valid;

    // Generate DIVop based on decoded funct3
    always_comb begin
        valid = 1'b1; // Default valid condition
        case (1'b1)
            is_div:  DIVop = `DIV_OP_DIV;   // Signed Division
            is_divu: DIVop = `DIV_OP_DIVU;  // Unsigned Division
            is_rem:  DIVop = `DIV_OP_REM;   // Signed Remainder
            is_remu: DIVop = `DIV_OP_REMU;  // Unsigned Remainder
            default: begin
                /* verilator lint_off WIDTH */
                DIVop = 'hxx; // Undefined operation
                /* verilator lint_on WIDTH */
                valid = 1'b0; // Mark invalid
            end
        endcase
    end

endmodule
