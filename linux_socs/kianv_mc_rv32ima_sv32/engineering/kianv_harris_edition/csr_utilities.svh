//
//  kianv.v - RISC-V rv32ima
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
// RISC-V Control and Status Registers (CSR) Utilities - SystemVerilog Header File
//
// This file defines the addresses and utility macros for working with
// RISC-V Control and Status Registers (CSRs), including privilege modes,
// counters, timers, and machine-level trap handling registers.
//
// **CSR Overview:**
// Control and Status Registers (CSRs) provide access to hardware status, counters,
// timers, and privilege modes. These registers are managed using specific opcodes
// and funct3 fields in CSR instructions.
//
// **CSR Register Categories:**
// - **Unprivileged Counter/Timers**: cycle, time, instret
// - **Machine Trap Setup**: mstatus, misa, mie, mtvec
// - **Machine Trap Handling**: mscratch, mepc, mcause, mtval, mip
// - **Machine-Level Identification**: mhartid, mvendorid, marchid
//
// **CSR Instruction Opcodes and Funct3:**
// - OPCODE: CSR instructions are encoded with the SYSTEM opcode.
// - FUNCT3: Identifies read, set, clear operations.
//
`ifndef CSR_UTILITIES_SVH
`define CSR_UTILITIES_SVH

// Unprivileged Counter/Timers
`define CSR_REG_CYCLE      12'hC00
`define CSR_REG_CYCLEH     12'hC80
`define CSR_REG_INSTRET    12'hC02
`define CSR_REG_INSTRETH   12'hC82
`define CSR_REG_TIME       12'hC01
`define CSR_REG_TIMEH      12'hC81

// Machine Trap Setup
`define CSR_REG_MSTATUS    12'h300
`define CSR_REG_MISA       12'h301
`define CSR_REG_MIE        12'h304
`define CSR_REG_MTVEC      12'h305

// Machine Trap Handling
`define CSR_REG_MSCRATCH   12'h340
`define CSR_REG_MEPC       12'h341
`define CSR_REG_MCAUSE     12'h342
`define CSR_REG_MTVAL      12'h343
`define CSR_REG_MIP        12'h344

`define CSR_REG_MCOUNTEREN 12'h306

// Machine-Level Identification Registers
`define CSR_REG_MHARTID    12'hF14
`define CSR_REG_MVENDORID  12'hF11
`define CSR_REG_MARCHID    12'hF12

// Custom Read-Only Register
`define CSR_PRIVILEGE_MODE 12'hFC0 // Machine privilege mode

// CSR Instruction Opcodes (SYSTEM Opcode) and Funct3 Values
`define CSR_OPCODE         `SYSTEM_OPCODE
`define CSR_FUNCT3_RW      3'b001 // Read/Write
`define CSR_FUNCT3_RS      3'b010 // Read and Set
`define CSR_FUNCT3_RC      3'b011 // Read and Clear
`define CSR_FUNCT3_RWI     3'b101 // Read/Write Immediate
`define CSR_FUNCT3_RSI     3'b110 // Read and Set Immediate
`define CSR_FUNCT3_RCI     3'b111 // Read and Clear Immediate

// Include Dependencies
`include "riscv_priv_csr_status.svh"
`include "misa.svh"

`endif // CSR_UTILITIES_SVH
