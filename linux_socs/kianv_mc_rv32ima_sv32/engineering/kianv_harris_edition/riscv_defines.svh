//
//  kianv.v - RISC-V rv32ima
//
//  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
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
// RISC-V Core Definitions - SystemVerilog Header File
//
// This file defines key constants, macros, and opcodes for the RISC-V RV32IM
// architecture. It includes definitions for ALU operations, AMO operations,
// CSR utilities, load/store operations, and multiplexer controls.
//
// **Instruction Encoding Notes:**
// RISC-V instructions are typically encoded using 32 bits with the following general format:
//
//  -------------------------------------------------------------------
//  |   opcode    |   rd   | funct3 |   rs1   |   rs2   |   funct7    |
//  -------------------------------------------------------------------
//  - **opcode**: 7 bits, specifies the instruction type (e.g., SYSTEM, LOAD, STORE).
//  - **rd**: Destination register (5 bits).
//  - **funct3**: Specifies the operation type for the opcode (3 bits).
//  - **rs1/rs2**: Source registers (5 bits each).
//  - **funct7**: Additional operation code or modifier (7 bits).
//
// Example: ALU Operations (R-Type instructions)
// - ADD: opcode = 7'b0110011, funct3 = 3'b000, funct7 = 7'b0000000
// - SUB: opcode = 7'b0110011, funct3 = 3'b000, funct7 = 7'b0100000
//
`ifndef RISCV_DEFINES_SVH
`define RISCV_DEFINES_SVH

`ifdef SIM
  `define RV32M
  `define CSR
`endif

// General Opcodes
`define SYSTEM_OPCODE      7'b1110011
`define NOP_INSTR          32'h0000_0013

// MUX SRCA
`define SRCA_WIDTH         $clog2(`SRCA_LAST)
`define SRCA_PC            0
`define SRCA_OLD_PC        1
`define SRCA_RD1_BUF       2
`define SRCA_AMO_TEMP_DATA 3
`define SRCA_CONST_0       4
`define SRCA_LAST          5

// MUX SRCB
`define SRCB_WIDTH         $clog2(`SRCB_LAST)
`define SRCB_RD2_BUF       0
`define SRCB_IMM_EXT       1
`define SRCB_CONST_4       2
`define SRCB_CONST_0       3
`define SRCB_LAST          4

// MUX4 in DATA_UNIT RESULT
`define RESULT_WIDTH       $clog2(`RESULT_LAST)
`define RESULT_ALUOUT      0
`define RESULT_DATA        1
`define RESULT_ALURESULT   2
`define RESULT_MULOUT      3
`define RESULT_CSROUT      4
`define RESULT_AMO_TEMP_ADDR 5
`define RESULT_LAST        6

// Address Selectors
`define ADDR_PC            0
`define ADDR_RESULT        1

// Immediate Sources
`define IMMSRC_RTYPE       3'bxxx
`define IMMSRC_ITYPE       3'b000
`define IMMSRC_STYPE       3'b001
`define IMMSRC_BTYPE       3'b010
`define IMMSRC_UTYPE       3'b100
`define IMMSRC_JTYPE       3'b011

// ALU Operations
`define ALU_OP_WIDTH       $clog2(`ALU_OP_LAST)
`define ALU_OP_ADD         0
`define ALU_OP_SUB         1
`define ALU_OP_ARITH_LOGIC 2
`define ALU_OP_LUI         3
`define ALU_OP_AUIPC       4
`define ALU_OP_BRANCH      5
`define ALU_OP_AMO         6
`define ALU_OP_LAST        7

// AMO Operations
`define AMO_OP_WIDTH       $clog2(`AMO_OP_LAST)
`define AMO_OP_ADD_W       0
`define AMO_OP_SWAP_W      1
`define AMO_OP_LR_W        2
`define AMO_OP_SC_W        3
`define AMO_OP_XOR_W       4
`define AMO_OP_AND_W       5
`define AMO_OP_OR_W        6
`define AMO_OP_MIN_W       7
`define AMO_OP_MAX_W       8
`define AMO_OP_MINU_W      9
`define AMO_OP_MAXU_W      10
`define AMO_OP_LAST        11

// Multiplier Operations
`define MUL_OP_WIDTH       $clog2(`MUL_OP_LAST)
`define MUL_OP_MUL         0
`define MUL_OP_MULH        1
`define MUL_OP_MULSU       2
`define MUL_OP_MULU        3
`define MUL_OP_LAST        4

// Divider Operations
`define DIV_OP_WIDTH       $clog2(`DIV_OP_LAST)
`define DIV_OP_DIV         0
`define DIV_OP_DIVU        1
`define DIV_OP_REM         2
`define DIV_OP_REMU        3
`define DIV_OP_LAST        4

// Store Operations
`define STORE_OP_WIDTH     $clog2(`STORE_OP_LAST)
`define STORE_OP_SB        0
`define STORE_OP_SH        1
`define STORE_OP_SW        2
`define STORE_OP_LAST      3

// Load Operations
`define LOAD_OP_WIDTH      $clog2(`LOAD_OP_LAST)
`define LOAD_OP_LB         0
`define LOAD_OP_LBU        1
`define LOAD_OP_LH         2
`define LOAD_OP_LHU        3
`define LOAD_OP_LW         4
`define LOAD_OP_LAST       5

// ALU Control Signals
`define ALU_CTRL_WIDTH     $clog2(`ALU_CTRL_LAST)
`define ALU_CTRL_ADD_ADDI  0
`define ALU_CTRL_SUB       1
`define ALU_CTRL_XOR_XORI  2
`define ALU_CTRL_OR_ORI    3
`define ALU_CTRL_AND_ANDI  4
`define ALU_CTRL_SLL_SLLI  5
`define ALU_CTRL_SRL_SRLI  6
`define ALU_CTRL_SRA_SRAI  7
`define ALU_CTRL_SLT_SLTI  8
`define ALU_CTRL_AUIPC     9
`define ALU_CTRL_LUI       10
`define ALU_CTRL_SLTU_SLTIU 11
`define ALU_CTRL_BEQ       12
`define ALU_CTRL_BNE       13
`define ALU_CTRL_BLT       14
`define ALU_CTRL_BGE       15
`define ALU_CTRL_BLTU      16
`define ALU_CTRL_BGEU      17
`define ALU_CTRL_MIN       18
`define ALU_CTRL_MAX       19
`define ALU_CTRL_MINU      20
`define ALU_CTRL_MAXU      21
`define ALU_CTRL_LAST      22

// CSR Operations
`define CSR_OP_WIDTH       $clog2(`CSR_OP_LAST)
`define CSR_OP_CSRRW       0
`define CSR_OP_CSRRS       1
`define CSR_OP_CSRRC       2
`define CSR_OP_CSRRWI      3
`define CSR_OP_CSRRSI      4
`define CSR_OP_CSRRCI      5
`define CSR_OP_NA          6
`define CSR_OP_LAST        7

// Include Dependencies
`include "csr_utilities.svh"
`include "rv32_amo_opcodes.svh"
`include "sv32.svh"

`endif  // RISCV_DEFINES_SVH
