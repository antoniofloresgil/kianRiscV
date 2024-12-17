
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
// RISC-V Immediate Extension Module - SystemVerilog Implementation
//
// This module implements the immediate value extension logic for the RISC-V RV32IM architecture.
// It decodes and extends the immediate fields from the instruction based on the instruction type.
// Supported types include I-Type, S-Type, B-Type, J-Type, and U-Type.
//

`default_nettype none
`include "riscv_defines.svh"

module extend (
    input  logic [31:7] instr,   // Input instruction (excluding opcode)
    input  logic [2:0]  immsrc,  // Immediate source type (I, S, B, J, U)
    output logic [31:0] immext   // Sign-extended immediate output
);

    // Immediate extension based on the instruction type
    always_comb begin
        case (immsrc)
            `IMMSRC_ITYPE: immext = {{20{instr[31]}}, instr[31:20]};                    // I-Type: Sign-extend bits [31:20]
            `IMMSRC_STYPE: immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};       // S-Type: Sign-extend for store offset
            `IMMSRC_BTYPE: immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-Type: Branch offset with sign extension
            `IMMSRC_JTYPE: immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J-Type: Jump target offset with sign extension
            `IMMSRC_UTYPE: immext = {instr[31:12], 12'b0};                             // U-Type: Upper immediate with 12 lower bits zeroed
            default:       immext = 32'b0;                                             // Default: Zero output
        endcase
    end

endmodule

