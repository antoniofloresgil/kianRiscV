//
//  kianv harris multicycle RISC-V rv32im
//
//  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
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
// RISC-V RV32 Atomic Memory Operations Opcodes - SystemVerilog Header File
//
// This file defines constants and macros for the Atomic Memory Operations (AMO)
// instructions, funct3 values, fence operations, and associated opcodes for the RISC-V rv32im ISA.
//
// **Atomic Memory Operations (AMO) Coding Format:**
// RV32 Atomic Instructions use the following encoding format:
//
//  ----------------------------------------------------------------------
//  | funct5 | aq | rl |    rs2   |    rs1   | funct3 |    rd    | opcode |
//  ----------------------------------------------------------------------
//
// - **funct5**: Identifies the specific atomic operation (e.g., ADD, SWAP, XOR, etc.).
// - **aq**: Acquire bit for memory ordering.
// - **rl**: Release bit for memory ordering.
// - **rs2**: Source register 2 (value to be written for AMO instructions).
// - **rs1**: Source register 1 (address for the atomic operation).
// - **funct3**: Identifies the AMO operation category (always 3'h2 for RV32 AMO).
// - **rd**: Destination register (to store the result).
// - **opcode**: 7'h2F for Atomic Memory Operations.
//
// Example: AMOADD.W instruction
//    funct5 = 5'b00000, aq = 0, rl = 0, funct3 = 3'h2, opcode = 7'h2F

`ifndef RV32_AMO_OPCODES_SVH
`define RV32_AMO_OPCODES_SVH

// RV32 Atomic Operation Opcodes and Funct3
`define RV32_AMO_OPCODE      7'h2F
`define RV32_AMO_FUNCT3      3'h2

// Atomic Operation Funct5 Codes
`define RV32_AMOADD_W        5'h00
`define RV32_AMOSWAP_W       5'h01
`define RV32_LR_W            5'h02
`define RV32_SC_W            5'h03
`define RV32_AMOXOR_W        5'h04
`define RV32_AMOAND_W        5'h0C
`define RV32_AMOOR_W         5'h08
`define RV32_AMOMIN_W        5'h10
`define RV32_AMOMAX_W        5'h14
`define RV32_AMOMINU_W       5'h18
`define RV32_AMOMAXU_W       5'h1C

// Fence Opcodes and Funct3
`define RV32_FENCE_OPCODE    7'b0001111
`define RV32_FENCE_FUNCT3    3'b000
`define RV32_FENCE_I_FUNCT3  3'b001

// System Opcodes and SFENCE_VMA
`define RV32_SYSTEM_OPCODE          7'b1110011
`define RV32_SFENCE_VMA_FUNCT3      3'b000
`define RV32_SFENCE_VMA_FUNCT7      7'b0001001

// Instruction Matching Macros
`define RV32_IS_AMO_INSTRUCTION(opcode, funct3) \
    ((opcode == `RV32_AMO_OPCODE) && (funct3 == `RV32_AMO_FUNCT3))

`define RV32_IS_AMOADD_W(funct5)    (funct5 == `RV32_AMOADD_W)
`define RV32_IS_AMOSWAP_W(funct5)   (funct5 == `RV32_AMOSWAP_W)
`define RV32_IS_LR_W(funct5)        (funct5 == `RV32_LR_W)
`define RV32_IS_SC_W(funct5)        (funct5 == `RV32_SC_W)
`define RV32_IS_AMOXOR_W(funct5)    (funct5 == `RV32_AMOXOR_W)
`define RV32_IS_AMOAND_W(funct5)    (funct5 == `RV32_AMOAND_W)
`define RV32_IS_AMOOR_W(funct5)     (funct5 == `RV32_AMOOR_W)
`define RV32_IS_AMOMIN_W(funct5)    (funct5 == `RV32_AMOMIN_W)
`define RV32_IS_AMOMAX_W(funct5)    (funct5 == `RV32_AMOMAX_W)
`define RV32_IS_AMOMINU_W(funct5)   (funct5 == `RV32_AMOMINU_W)
`define RV32_IS_AMOMAXU_W(funct5)   (funct5 == `RV32_AMOMAXU_W)

`define RV32_IS_SFENCE_VMA(opcode, funct3, funct7) \
    ((opcode == `RV32_SYSTEM_OPCODE) && (funct3 == `RV32_SFENCE_VMA_FUNCT3) && (funct7 == `RV32_SFENCE_VMA_FUNCT7))

`define RV32_IS_FENCE(opcode, funct3) \
    ((opcode == `RV32_FENCE_OPCODE) && (funct3 == `RV32_FENCE_FUNCT3))

`define RV32_IS_FENCE_I(opcode, funct3) \
    ((opcode == `RV32_FENCE_OPCODE) && (funct3 == `RV32_FENCE_I_FUNCT3))

`endif // RV32_AMO_OPCODES_SVH

