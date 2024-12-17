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
// RISC-V Privilege and CSR Status Definitions - SystemVerilog Header File
//
// This file defines constants and macros for managing Control and Status Registers (CSR)
// in a RISC-V processor. The focus is on privilege levels, MSTATUS fields, and system behavior.
//
// **Key Concepts:**
// 1. **Privilege Levels:**
//    - User Mode (U): Least privileged, for application execution.
//    - Supervisor Mode (S): Intermediate privilege, used by operating systems.
//    - Machine Mode (M): Most privileged, responsible for low-level hardware control.
//
// 2. **CSR Register Format:**
//    Control and Status Registers (CSRs) are 32-bit registers used to control
//    the operation of the processor and hold system status information.
//
//    - CSR fields are often accessed via bit masks and shifts to read, write,
//      and update specific fields.
//    - Common CSRs include MSTATUS, MIE, MIP, and MCause.
//
//    Example CSR Register:
//    ----------------------------------------------------------
//    | 31 | 30-23 | 22-17 | 16-15 | 14-13 | 12-11 | 10-0      |
//    | I  |   X   |  MPRV |   X   |  MPIE |  MPP  | Reserved  |
//    ----------------------------------------------------------
//    - Bit [31]: Interrupt flag (I)
//    - Bit [17]: MPRV (Modify Privilege)
//    - Bits [12-11]: MPP (Previous Privilege Mode)
//    - Bit [7]: MPIE (Machine Previous Interrupt Enable)
//    - Bit [3]: MIE (Machine Interrupt Enable)
//
// 3. **Interrupt Handling:**
//    - MIE (Machine Interrupt Enable): Enables interrupts globally at the machine level.
//    - MPIE (Previous Interrupt Enable): Remembers interrupt status before traps.
//    - MPP (Machine Previous Privilege): Tracks previous privilege mode.
//
// 4. **Macros and Masks:**
//    - Constants for privilege levels, MSTATUS fields, and interrupt handling.
//    - Macros for setting and getting specific bits in registers.

`ifndef RISCV_PRIV_CSR_STATUS_SVH
`define RISCV_PRIV_CSR_STATUS_SVH

// RISC-V Privilege Levels
`define PRIVILEGE_MODE_USER       2'b00
`define PRIVILEGE_MODE_SUPERVISOR 2'b01
`define PRIVILEGE_MODE_RESERVED   2'b10
`define PRIVILEGE_MODE_MACHINE    2'b11

`define IS_USER(privilege)       (privilege == `PRIVILEGE_MODE_USER)
`define IS_SUPERVISOR(privilege) (privilege == `PRIVILEGE_MODE_SUPERVISOR)
`define IS_MACHINE(privilege)    (privilege == `PRIVILEGE_MODE_MACHINE)

// Interrupt Bits and Masks
`define MIP_MTIP_BIT   7
`define MIE_MTIP_BIT   7
`define MIP_MSIP_BIT   3
`define MIE_MSIP_BIT   3

`define MIP_MTIP_MASK  (1 << `MIP_MTIP_BIT)
`define MIE_MTIP_MASK  (1 << `MIE_MTIP_BIT)
`define MIP_MSIP_MASK  (1 << `MIP_MSIP_BIT)
`define MIE_MSIP_MASK  (1 << `MIE_MSIP_BIT)

// MSTATUS Register Fields
`define MSTATUS_MPP_BIT    11
`define MSTATUS_MPP_WIDTH  2
`define MSTATUS_MPIE_BIT   7
`define MSTATUS_MIE_BIT    3
`define MSTATUS_MPRV_BIT   17

`define MSTATUS_MIE_MASK   (1 << `MSTATUS_MIE_BIT)
`define MSTATUS_MPIE_MASK  (1 << `MSTATUS_MPIE_BIT)
`define MSTATUS_MPP_MASK   (((1 << `MSTATUS_MPP_WIDTH) - 1) << `MSTATUS_MPP_BIT)
`define MSTATUS_MPRV_MASK  (1 << `MSTATUS_MPRV_BIT)

// Macros for MSTATUS manipulation
`define GET_MIE_MTIP(mie)  ((mie >> `MIE_MTIP_BIT) & 1)
`define GET_MIE_MSIP(mie)  ((mie >> `MIE_MSIP_BIT) & 1)

`define GET_MIP_MTIP(mip)  (((mip) >> `MIP_MTIP_BIT) & 1'b1)
`define GET_MIP_MSIP(mip)  (((mip) >> `MIP_MSIP_BIT) & 1'b1)

`define SET_MIP_MSIP(mip, value) \
    ((mip & ~`MIP_MSIP_MASK) | ((value & 1'b1) << `MIP_MSIP_BIT))

`define SET_MIP_MTIP(mip, value) \
    ((mip & ~`MIP_MTIP_MASK) | ((value & 1'b1) << `MIP_MTIP_BIT))

// MSTATUS manipulation macros
`define SET_MSTATUS_MPP(mstatus, new_privilege_mode) \
    ((mstatus & ~`MSTATUS_MPP_MASK) | (((new_privilege_mode) & 2'b11) << `MSTATUS_MPP_BIT))

`define GET_MSTATUS_MPP(mstatus) \
    ((mstatus >> `MSTATUS_MPP_BIT) & 2'b11)

`define SET_MSTATUS_MPIE(mstatus, mpi_value) \
    ((mstatus & ~`MSTATUS_MPIE_MASK) | (((mpi_value) & 1'b1) << `MSTATUS_MPIE_BIT))

`define GET_MSTATUS_MPIE(mstatus) \
    ((mstatus >> `MSTATUS_MPIE_BIT) & 1'b1)

`define SET_MSTATUS_MIE(mstatus, value) \
    ((mstatus & ~`MSTATUS_MIE_MASK) | (((value) & 1'b1) << `MSTATUS_MIE_BIT))

`define GET_MSTATUS_MIE(mstatus) \
    ((mstatus >> `MSTATUS_MIE_BIT) & 1'b1)

`define SET_MSTATUS_MPRV(mstatus, mprv_value) \
    ((mstatus & ~`MSTATUS_MPRV_MASK) | (((mprv_value) & 1'b1) << `MSTATUS_MPRV_BIT))

`define GET_MSTATUS_MPRV(mstatus) \
    ((mstatus >> `MSTATUS_MPRV_BIT) & 1'b1)

// Instruction Matching Macros
`define IS_EBREAK(opcode, funct3, funct7, rs1, rs2, rd) \
    ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h00100073)

`define IS_ECALL(opcode, funct3, funct7, rs1, rs2, rd) \
    ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h00000073)

`define IS_MRET(opcode, funct3, funct7, rs1, rs2, rd) \
    ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h30200073)

`define IS_WFI(opcode, funct3, funct7, rs1, rs2, rd) \
    ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h10500073)

`define IRQ_M_TIMER 7

`include "mcause.svh"

`endif // RISCV_PRIV_CSR_STATUS_SVH
