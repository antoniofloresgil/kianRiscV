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

`ifndef RISCV_PRIV_CSR_STATUS_VH
`define RISCV_PRIV_CSR_STATUS_VH

// RISC-V privilege levels
`define PRIVILEGE_MODE_USER 0  // User mode privilege level
`define PRIVILEGE_MODE_SUPERVISOR 1  // Supervisor mode privilege level
`define PRIVILEGE_MODE_RESERVED 2  // Reserved privilege level
`define PRIVILEGE_MODE_MACHINE 3  // Machine mode privilege level

// Check if the given privilege level matches a specific mode
`define IS_USER(privilege) (privilege == `PRIVILEGE_MODE_USER)
`define IS_SUPERVISOR(privilege) (privilege == `PRIVILEGE_MODE_SUPERVISOR)
`define IS_MACHINE(privilege) (privilege == `PRIVILEGE_MODE_MACHINE)

// Machine Interrupt Enable (MIE) bits
`define MIE_MEIE_BIT       11  // Machine External Interrupt Enable bit
`define MIE_MSIE_BIT       3   // Machine Software Interrupt Enable bit
`define MIE_MTIE_BIT       7   // Machine Timer Interrupt Enable bit

// Supervisor Interrupt Enable (XIE) bits
`define XIE_SEIE_BIT       9   // Supervisor External Interrupt Enable bit
`define XIE_SSIE_BIT       1   // Supervisor Software Interrupt Enable bit
`define XIE_STIE_BIT       5   // Supervisor Timer Interrupt Enable bit

// Machine Interrupt Pending (MIP) bits
`define MIP_MEIP_BIT       11  // Machine External Interrupt Pending bit
`define MIP_MSIP_BIT       3   // Machine Software Interrupt Pending bit
`define MIP_MTIP_BIT       7   // Machine Timer Interrupt Pending bit

// Supervisor Interrupt Pending (XIP) bits
`define XIP_SEIP_BIT       9   // Supervisor External Interrupt Pending bit
`define XIP_SSIP_BIT       1   // Supervisor Software Interrupt Pending bit
`define XIP_STIP_BIT       5   // Supervisor Timer Interrupt Pending bit

// Interrupt Enable Masks
`define MIE_MEIE_MASK      (1 << `MIE_MEIE_BIT)  // Enable Machine External Interrupt
`define MIE_MSIE_MASK      (1 << `MIE_MSIE_BIT)  // Enable Machine Software Interrupt
`define MIE_MTIE_MASK      (1 << `MIE_MTIE_BIT)  // Enable Machine Timer Interrupt

`define XIE_SEIE_MASK      (1 << `XIE_SEIE_BIT)  // Enable Supervisor External Interrupt
`define XIE_SSIE_MASK      (1 << `XIE_SSIE_BIT)  // Enable Supervisor Software Interrupt
`define XIE_STIE_MASK      (1 << `XIE_STIE_BIT)  // Enable Supervisor Timer Interrupt

// Interrupt Pending Masks
`define MIP_MEIP_MASK      (1 << `MIP_MEIP_BIT)  // Machine External Interrupt Pending
`define MIP_MSIP_MASK      (1 << `MIP_MSIP_BIT)  // Machine Software Interrupt Pending
`define MIP_MTIP_MASK      (1 << `MIP_MTIP_BIT)  // Machine Timer Interrupt Pending

`define XIP_SEIP_MASK      (1 << `XIP_SEIP_BIT)  // Supervisor External Interrupt Pending
`define XIP_SSIP_MASK      (1 << `XIP_SSIP_BIT)  // Supervisor Software Interrupt Pending
`define XIP_STIP_MASK      (1 << `XIP_STIP_BIT)  // Supervisor Timer Interrupt Pending

// Status Register Bits
`define XSTATUS_SIE_BIT 1  // Supervisor Interrupt Enable bit
`define XSTATUS_SIE_MASK (1 << `XSTATUS_SIE_BIT)

`define MSTATUS_MPP_BIT 11  // Machine Previous Privilege Mode bit position
`define MSTATUS_MPP_WIDTH 2  // Width of MPP field
`define MSTATUS_MPIE_BIT 7   // Machine Previous Interrupt Enable bit
`define MSTATUS_MIE_BIT 3    // Machine Interrupt Enable bit
`define MSTATUS_MPRV_BIT 17  // Memory Privilege bit

// Supervisor Status Bits
`define XSTATUS_SPIE_BIT 5  // Supervisor Previous Interrupt Enable bit
`define XSTATUS_SPIE_MASK (1 << `XSTATUS_SPIE_BIT)

`define XSTATUS_SPP_BIT 8  // Supervisor Previous Privilege Mode bit
`define XSTATUS_SPP_MASK (1 << `XSTATUS_SPP_BIT)

`define XSTATUS_MXR 19  // Make eXecutable Readable bit
`define XSTATUS_SUM_POS 18  // Supervisor User Memory bit position

// Masks for MSTATUS fields
`define MSTATUS_MIE_MASK (1 << `MSTATUS_MIE_BIT)
`define MSTATUS_MPIE_MASK (1 << `MSTATUS_MPIE_BIT)
`define MSTATUS_MPP_MASK (((1 << `MSTATUS_MPP_WIDTH) - 1) << `MSTATUS_MPP_BIT)
`define MSTATUS_MPRV_MASK (1 << `MSTATUS_MPRV_BIT)

// Supervisor Status Mask
`define SSTATUS_SIE_BIT   (1 << 1)  // Supervisor Interrupt Enable
`define SSTATUS_SPIE_BIT  (1 << 5)  // Supervisor Previous Interrupt Enable
`define SSTATUS_UBE_BIT   (1 << 6)  // User-mode Big-Endian
`define SSTATUS_SPP_BIT   (1 << 8)  // Supervisor Previous Privilege
`define SSTATUS_VS_BIT    (3 << 9)  // Virtualization State
`define SSTATUS_FS_BIT    (3 << 13) // Floating-point Status
`define SSTATUS_XS_BIT    (3 << 15) // Extension Status
`define SSTATUS_SUM_BIT   (1 << 18) // Supervisor User Memory Access
`define SSTATUS_MXR_BIT   (1 << 19) // Make eXecutable Readable
`define SSTATUS_SD_BIT    (1 << 31) // Dirty State

`define SSTATUS_MASK (`SSTATUS_SIE_BIT | `SSTATUS_SPIE_BIT | `SSTATUS_UBE_BIT | \
                      `SSTATUS_SPP_BIT | `SSTATUS_VS_BIT | `SSTATUS_FS_BIT | `SSTATUS_XS_BIT | `SSTATUS_SUM_BIT | \
                      `SSTATUS_MXR_BIT | `SSTATUS_SD_BIT)

// Machine Exception Delegation Register (MEDELEG) bits
`define MEDELEG_INST_ADDR_MISALIGNED  'h0001  // Instruction Address Misaligned
`define MEDELEG_INST_ACCESS_FAULT     'h0002  // Instruction Access Fault
`define MEDELEG_ILLEGAL_INST          'h0004  // Illegal Instruction
`define MEDELEG_BREAKPOINT            'h0008  // Breakpoint
`define MEDELEG_LOAD_ADDR_MISALIGNED  'h0010  // Load Address Misaligned
`define MEDELEG_LOAD_ACCESS_FAULT     'h0020  // Load Access Fault
`define MEDELEG_STORE_ADDR_MISALIGNED 'h0040  // Store Address Misaligned
`define MEDELEG_STORE_ACCESS_FAULT    'h0080  // Store Access Fault
`define MEDELEG_ECALL_U               'h0100  // Environment Call from User Mode
`define MEDELEG_ECALL_S               'h0200  // Environment Call from Supervisor Mode
`define MEDELEG_INSTR_PAGE_FAULT      'h1000  // Instruction Page Fault
`define MEDELEG_LOAD_PAGE_FAULT       'h2000  // Load Page Fault
`define MEDELEG_STORE_PAGE_FAULT      'h8000  // Store Page Fault

// MEDELEG Mask
`define MEDELEG_MASK (`MEDELEG_INST_ADDR_MISALIGNED | `MEDELEG_INST_ACCESS_FAULT | \
                      `MEDELEG_ILLEGAL_INST | `MEDELEG_BREAKPOINT | \
                      `MEDELEG_LOAD_ADDR_MISALIGNED | `MEDELEG_LOAD_ACCESS_FAULT | \
                      `MEDELEG_STORE_ADDR_MISALIGNED | `MEDELEG_STORE_ACCESS_FAULT | \
                      `MEDELEG_ECALL_U | `MEDELEG_ECALL_S | \
                      `MEDELEG_INSTR_PAGE_FAULT | `MEDELEG_LOAD_PAGE_FAULT | \
                      `MEDELEG_STORE_PAGE_FAULT)

// Machine Interrupt Delegation Register (MIDELEG) bits
`define MIDELEG_SUPERVISOR_SOFT_INTR   'h002  // Supervisor Software Interrupt
`define MIDELEG_SUPERVISOR_TIMER_INTR  'h020  // Supervisor Timer Interrupt
`define MIDELEG_SUPERVISOR_EXT_INTR    'h200  // Supervisor External Interrupt

`define MIDELEG_MASK (`MIDELEG_SUPERVISOR_SOFT_INTR | `MIDELEG_SUPERVISOR_TIMER_INTR | \
                      `MIDELEG_SUPERVISOR_EXT_INTR)

// Interrupt Masks
`define SIP_MASK (`XIP_SSIP_MASK | `XIP_SEIP_MASK | `XIP_STIP_MASK)  // Supervisor Interrupt Pending Mask
`define SIE_MASK (`XIE_SSIE_MASK | `XIE_SEIE_MASK | `XIE_STIE_MASK)  // Supervisor Interrupt Enable Mask

// Macros to manipulate interrupt and status fields
`define GET_MIE_MSIE(value) ((value >> `MIE_MSIE_BIT) & 1'b1)  // Get Machine Software Interrupt Enable
`define GET_MIE_MTIE(value) ((value >> `MIE_MTIE_BIT) & 1'b1)  // Get Machine Timer Interrupt Enable
`define GET_MIP_MEIP(value) (((value) >> `MIP_MEIP_BIT) & 1'b1)  // Get Machine External Interrupt Pending
`define GET_MIP_MSIP(value) (((value) >> `MIP_MSIP_BIT) & 1'b1)  // Get Machine Software Interrupt Pending
`define GET_MIP_MTIP(value) (((value) >> `MIP_MTIP_BIT) & 1'b1)  // Get Machine Timer Interrupt Pending
`define GET_XIP_SEIP(value) (((value) >> `XIP_SEIP_BIT) & 1'b1)  // Get Supervisor External Interrupt Pending
`define GET_XIP_SSIP(value) (((value) >> `XIP_SSIP_BIT) & 1'b1)  // Get Supervisor Software Interrupt Pending
`define GET_XIP_STIP(value) (((value) >> `XIP_STIP_BIT) & 1'b1)  // Get Supervisor Timer Interrupt Pending

`define SET_MIP_MEIP(value)  ((value) << `MIP_MEIP_BIT)  // Set Machine External Interrupt Pending
`define SET_MIP_MSIP(value)  ((value) << `MIP_MSIP_BIT)  // Set Machine Software Interrupt Pending
`define SET_MIP_MTIP(value)  ((value) << `MIP_MTIP_BIT)  // Set Machine Timer Interrupt Pending
`define SET_XIP_SEIP(value)  ((value) << `XIP_SEIP_BIT)  // Set Supervisor External Interrupt Pending
`define SET_XIP_SSIP(value)  ((value) << `XIP_SSIP_BIT)  // Set Supervisor Software Interrupt Pending
`define SET_XIP_STIP(value)  ((value) << `XIP_STIP_BIT)  // Set Supervisor Timer Interrupt Pending

// Macros to manipulate MSTATUS fields
`define GET_MSTATUS_MIE(value) (((value) >> `MSTATUS_MIE_BIT) & 1'b1)  // Get Machine Interrupt Enable
`define GET_MSTATUS_MPIE(value) (((value) >> `MSTATUS_MPIE_BIT) & 1'b1)  // Get Machine Previous Interrupt Enable
`define GET_MSTATUS_MPP(value) (((value) >> `MSTATUS_MPP_BIT) & 2'b11)  // Get Machine Previous Privilege Mode
`define GET_MSTATUS_MPRV(value) ((value >> `MSTATUS_MPRV_BIT) & 1'b1)  // Get Memory Privilege bit
`define GET_MSTATUS_MXR(value) (((value) >> `XSTATUS_MXR) & 1'b1)  // Get Make eXecutable Readable
`define GET_XSTATUS_SIE(value) (((value) >> `XSTATUS_SIE_BIT) & 1'b1)  // Get Supervisor Interrupt Enable
`define GET_XSTATUS_SPIE(value) (((value) >> `XSTATUS_SPIE_BIT) & 1'b1)  // Get Supervisor Previous Interrupt Enable
`define GET_XSTATUS_SPP(value) (((value) >> `XSTATUS_SPP_BIT) & 1'b1)  // Get Supervisor Previous Privilege Mode
`define GET_XSTATUS_SUM(value) (((value) >> `XSTATUS_SUM_POS) & 1'b1)  // Get Supervisor User Memory Access

`define SET_MSTATUS_MIE(value) ((value) << `MSTATUS_MIE_BIT)  // Set Machine Interrupt Enable
`define SET_MSTATUS_MPIE(value) ((value) << `MSTATUS_MPIE_BIT)  // Set Machine Previous Interrupt Enable
`define SET_MSTATUS_MPP(new_privilege_mode) (((new_privilege_mode) & 2'b11) << `MSTATUS_MPP_BIT)  // Set Machine Previous Privilege Mode
`define SET_MSTATUS_MPRV(mstatus, mprv_value) ((mstatus & ~`MSTATUS_MPRV_MASK) | (((mprv_value) & 1'b1) << `MSTATUS_MPRV_BIT))  // Set Memory Privilege
`define SET_MSTATUS_MXR(mstatus, value) ((mstatus & ~`XSTATUS_MXR_MASK) | ((value << 19) & `XSTATUS_MXR_MASK))  // Set Make eXecutable Readable
`define SET_XSTATUS_SIE(value)  ((value) << `XSTATUS_SIE_BIT)  // Set Supervisor Interrupt Enable
`define SET_XSTATUS_SPIE(value) ((value) << `XSTATUS_SPIE_BIT)  // Set Supervisor Previous Interrupt Enable
`define SET_XSTATUS_SPP(value)  ((value) << `XSTATUS_SPP_BIT)  // Set Supervisor Previous Privilege Mode

// SSTC (Supervisor Single Timer Compare) Conditions
`define GET_MENVCFGH_STCE(menvcfgh) ((menvcfgh >> 31) & 1)  // Get Supervisor Timer Compare Enable
`define GET_MCOUNTEREN_TM(mcounteren) ((mcounteren >> 1) & 1)  // Get Timer Match bit
`define CHECK_SSTC_CONDITIONS(menvcfgh, mcounteren) \
    (`GET_MENVCFGH_STCE(menvcfgh) && `GET_MCOUNTEREN_TM(mcounteren))
`define CHECK_SSTC_TM_AND_CMP(timer_counter, stimecmph, stimecmp, menvcfgh, mcounteren) \
    (timer_counter >= {stimecmph, stimecmp} && \
    `CHECK_SSTC_CONDITIONS(menvcfgh, mcounteren))

// Instruction Checks
`define IS_EBREAK(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h00100073)  // Check for EBREAK instruction
`define IS_ECALL(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h00000073)  // Check for ECALL instruction
`define IS_MRET(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h30200073)  // Check for MRET instruction
`define IS_SRET(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h10200073)  // Check for SRET instruction
`define IS_WFI(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h10500073)  // Check for WFI instruction

`include "mcause.svh"  // Include cause register definitions

`endif
