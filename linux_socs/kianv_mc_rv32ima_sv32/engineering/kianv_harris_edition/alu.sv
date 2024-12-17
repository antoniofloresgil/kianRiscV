//
//  kianv.v - RISC-V rv32ima
//
//  copyright (c) 2022/24 hirosh dabui <hirosh@dabui.de>
//  Port to SystemVerilog copyright (c) 2024 Antonio Flores <aflores@um.es>
//
//  permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  the software is provided "as is" and the author disclaims all warranties
//  with regard to this software including all implied warranties of
//  merchantability and fitness. in no event shall the author be liable for
//  any special, direct, indirect, or consequential damages or any damages
//  whatsoever resulting from loss of use, data or profits, whether in an
//  action of contract, negligence or other tortious action, arising out of
//  or in connection with the use or performance of this software.
//
// RISC-V ALU Module - SystemVerilog Implementation
//
// This module implements the Arithmetic Logic Unit (ALU) for the RISC-V RV32IM
// architecture. It performs various arithmetic, logical, and comparison operations
// based on the ALU control signals. It supports both signed and unsigned operations
// as well as shift operations.
//
// **Inputs:**
// - `a` (32-bit): Operand A.
// - `b` (32-bit): Operand B.
// - `alucontrol` (ALU control signal): Specifies the operation to be performed.
//
// **Outputs:**
// - `result` (32-bit): Result of the ALU operation.
// - `zero` (1-bit): Indicates if the result is zero.

`default_nettype none
`include "riscv_defines.svh"

module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [`ALU_CTRL_WIDTH-1:0] alucontrol,
    output logic [31:0] result,
    output logic zero
);

  logic signed [31:0] signed_a, signed_b;
  assign signed_a = $signed(a);
  assign signed_b = $signed(b);

  always_comb begin
    case (alucontrol)
      `ALU_CTRL_AUIPC, `ALU_CTRL_ADD_ADDI: result = a + b;
      `ALU_CTRL_SUB:                       result = a - b;
      `ALU_CTRL_XOR_XORI:                  result = a ^ b;
      `ALU_CTRL_OR_ORI:                    result = a | b;
      `ALU_CTRL_AND_ANDI:                  result = a & b;
      `ALU_CTRL_SLL_SLLI:                  result = a << b[4:0];
      `ALU_CTRL_SRL_SRLI:                  result = a >> b[4:0];
      `ALU_CTRL_SRA_SRAI:                  result = signed_a >>> b[4:0];
      `ALU_CTRL_SLT_SLTI:                  result = {31'b0, signed_a < signed_b};
      `ALU_CTRL_SLTU_SLTIU:                result = {31'b0, a < b};
      `ALU_CTRL_MIN:                       result = (signed_a < signed_b) ? a : b;
      `ALU_CTRL_MAX:                       result = (signed_a >= signed_b) ? a : b;
      `ALU_CTRL_MINU:                      result = (a < b) ? a : b;
      `ALU_CTRL_MAXU:                      result = (a >= b) ? a : b;
      `ALU_CTRL_LUI:                       result = b;
      `ALU_CTRL_BEQ:                       result = {31'b0, a == b};
      `ALU_CTRL_BNE:                       result = {31'b0, a != b};
      `ALU_CTRL_BGE:                       result = {31'b0, signed_a >= signed_b};
      `ALU_CTRL_BGEU:                      result = {31'b0, a >= b};
      `ALU_CTRL_BLT:                       result = {31'b0, signed_a < signed_b};
      `ALU_CTRL_BLTU:                      result = {31'b0, a < b};
      default:                             result = 32'b0;
    endcase
  end

  assign zero = (result == 32'b0);

endmodule
