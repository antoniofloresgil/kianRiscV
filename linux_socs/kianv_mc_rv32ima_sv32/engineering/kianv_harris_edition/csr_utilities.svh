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
`define CSR_CYCLE    12'hC00
`define CSR_CYCLEH   12'hC80
`define CSR_INSTRET  12'hC02
`define CSR_INSTRETH 12'hC82
`define CSR_TIME     12'hC01
`define CSR_TIMEH    12'hC81

`define CSR_MTIMECMP  12'h7c0
`define CSR_MTIMECMPH 12'h7c1

// Machine Trap Setup
`define CSR_MSTATUS 12'h300
`define CSR_MISA    12'h301
`define CSR_MIE     12'h304
`define CSR_MTVEC   12'h305

// Machine Trap Handling
`define CSR_MSCRATCH 12'h340
`define CSR_MEPC     12'h341
`define CSR_MCAUSE   12'h342
`define CSR_MTVAL    12'h343
`define CSR_MIP      12'h344

`define CSR_MENVCFG      12'h30a
`define CSR_MENVCFGH     12'h31a
`define CSR_MCOUNTEREN   12'h306
`define CSR_MCOUNTINHIBIT 12'h320

// Supervisor Trap Handling
`define CSR_SSTATUS   12'h100
`define CSR_SSCRATCH  12'h140
`define CSR_SEPC      12'h141
`define CSR_SCAUSE    12'h142
`define CSR_STVAL     12'h143
`define CSR_STVEC     12'h105
`define CSR_SIE       12'h104
`define CSR_SIP       12'h144
`define CSR_SATP      12'h180

`define CSR_STIMECMP   12'h14d
`define CSR_STIMECMPH  12'h15d
`define CSR_SCOUNTEREN 12'h106

`define CSR_MEDELEG 12'h302
`define CSR_MIDELEG 12'h303

`define CSR_MCOUNTEREN 12'h306

`define CSR_MVENDORID 12'hf11
`define CSR_MARCHID   12'hf12
`define CSR_MIMPID    12'hf13
`define CSR_MHARTID   12'hf14

// Machine-Level CSRs
// custrom read-only
`define CSR_PRIVILEGE_MODE 12'hfc0 // machine privilege mode

// RISC-V CSR instruction opcodes (7-bit) and funct3 (3-bit)
`define CSR_OPCODE    `SYSTEM_OPCODE
`define CSR_FUNCT3_RW 3'b001
`define CSR_FUNCT3_RS 3'b010
`define CSR_FUNCT3_RC 3'b011
`define CSR_FUNCT3_RWI 3'b101
`define CSR_FUNCT3_RSI 3'b110
`define CSR_FUNCT3_RCI 3'b111

`include "riscv_priv_csr_status.svh"
`include "misa.svh"
`endif /*  CSR_UTILITIES_SVH */
