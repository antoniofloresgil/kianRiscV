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
// RISC-V ALU Decoder Module - SystemVerilog Implementation
//
// This module implements the ALU decoder for the RISC-V RV32IM architecture.
// It generates the ALU control signals based on the input control bits, ALU operation,
// and AMO operation types. The decoder selects the appropriate ALU control signal
// based on the instruction format.
//
// **Inputs:**
// - `imm_bit10`: Immediate bit [10].
// - `op_bit5`: Opcode bit [5].
// - `funct3`: Function field [2:0].
// - `funct7b5`: Function field [7][5] (MSB of funct7).
// - `ALUOp`: ALU operation type.
// - `AMOop`: AMO operation type.
//
// **Outputs:**
// - `ALUControl`: ALU control signal that determines the ALU operation.

`default_nettype none
`include "riscv_defines.svh"

module alu_decoder (
    input wire                         imm_bit10,
    input wire                         op_bit5,
    input wire [2:0]                   funct3,
    input wire                         funct7b5,
    input wire [`ALU_OP_WIDTH-1:0]     ALUOp,
    input wire [`AMO_OP_WIDTH-1:0]     AMOop,
    output logic [`ALU_CTRL_WIDTH-1:0] ALUControl
);

  logic is_rtype_sub;
  logic is_srl_srli;

  assign is_rtype_sub = op_bit5 & funct7b5;
  assign is_srl_srli  = (op_bit5 && !funct7b5) || (!op_bit5 && !imm_bit10);

  always_comb begin
    case (ALUOp)
      `ALU_OP_ADD:                             ALUControl = `ALU_CTRL_ADD_ADDI;
      `ALU_OP_SUB:                             ALUControl = `ALU_CTRL_SUB;
      `ALU_OP_AUIPC:                           ALUControl = `ALU_CTRL_AUIPC;
      `ALU_OP_LUI:                             ALUControl = `ALU_CTRL_LUI;
      `ALU_OP_BRANCH: begin
        case (funct3)
          3'b000: ALUControl = `ALU_CTRL_BEQ;
          3'b001: ALUControl = `ALU_CTRL_BNE;
          3'b100: ALUControl = `ALU_CTRL_BLT;
          3'b101: ALUControl = `ALU_CTRL_BGE;
          3'b110: ALUControl = `ALU_CTRL_BLTU;
          3'b111: ALUControl = `ALU_CTRL_BGEU;
          default: ALUControl = 'hx; // Lint off ignored warnings
        endcase
      end
      `ALU_OP_AMO: begin
        case (AMOop)
          `AMO_OP_ADD_W:  ALUControl = `ALU_CTRL_ADD_ADDI;
          `AMO_OP_SWAP_W: ALUControl = `ALU_CTRL_ADD_ADDI; // TODO: fixme
          `AMO_OP_LR_W:   ALUControl = `ALU_CTRL_ADD_ADDI;
          `AMO_OP_SC_W:   ALUControl = `ALU_CTRL_ADD_ADDI; // TODO: fixme
          `AMO_OP_XOR_W:  ALUControl = `ALU_CTRL_XOR_XORI;
          `AMO_OP_AND_W:  ALUControl = `ALU_CTRL_AND_ANDI;
          `AMO_OP_OR_W:   ALUControl = `ALU_CTRL_OR_ORI;
          `AMO_OP_MIN_W:  ALUControl = `ALU_CTRL_MIN;
          `AMO_OP_MAX_W:  ALUControl = `ALU_CTRL_MAX; // TODO: fixme
          `AMO_OP_MINU_W: ALUControl = `ALU_CTRL_MINU;
          `AMO_OP_MAXU_W: ALUControl = `ALU_CTRL_MAXU;
          default: ALUControl = 'hx; // Lint off ignored warnings
        endcase
      end
      `ALU_OP_ARITH_LOGIC: begin
        case (funct3)
          3'b000: ALUControl = is_rtype_sub ? `ALU_CTRL_SUB : `ALU_CTRL_ADD_ADDI;
          3'b100: ALUControl = `ALU_CTRL_XOR_XORI;
          3'b110: ALUControl = `ALU_CTRL_OR_ORI;
          3'b111: ALUControl = `ALU_CTRL_AND_ANDI;
          3'b010: ALUControl = `ALU_CTRL_SLT_SLTI;
          3'b001: ALUControl = `ALU_CTRL_SLL_SLLI;
          3'b011: ALUControl = `ALU_CTRL_SLTU_SLTIU;
          3'b101: ALUControl = is_srl_srli ? `ALU_CTRL_SRL_SRLI : `ALU_CTRL_SRA_SRAI;
          default: ALUControl = 'hx; // Lint off ignored warnings
        endcase
      end
      default: ALUControl = 'hx; // Lint off ignored warnings
    endcase
  end

endmodule
