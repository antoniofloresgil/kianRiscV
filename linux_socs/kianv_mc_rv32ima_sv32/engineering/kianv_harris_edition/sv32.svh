//
//  kianv harris multicycle RISC-V rv32ima
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
// SV32 Addressing Definitions - SystemVerilog Header File
//
// This file defines the constants and macros for the RISC-V Sv32 memory management scheme.
// Sv32 supports 2 levels of page tables with 4 KiB pages. The macros define
// positions and masks for bits in the Page Table Entry (PTE) and SATP register.

`ifndef SV32_SVH
`define SV32_SVH

// Sv32 Levels and Page Properties
`define SV32_LEVELS        2
`define SV32_PTE_SIZE      4   // PTE size in bytes
`define SV32_PTE_SHIFT     2
`define SV32_PAGE_SIZE     4096 // Page size in bytes (4 KiB)
`define SV32_PAGE_OFFSET_BITS 12

// PTE Field Positions
`define SV32_PTE_V_SHIFT   0   // Valid bit position
`define SV32_PTE_R_SHIFT   1   // Read bit position
`define SV32_PTE_W_SHIFT   2   // Write bit position
`define SV32_PTE_X_SHIFT   3   // Execute bit position
`define SV32_PTE_U_SHIFT   4   // User bit position
`define SV32_PTE_G_SHIFT   5   // Global bit position
`define SV32_PTE_A_SHIFT   6   // Accessed bit position
`define SV32_PTE_D_SHIFT   7   // Dirty bit position
`define SV32_PTE_RSW_SHIFT 8   // Reserved for Software use
`define SV32_PTE_PPN_SHIFT 10  // Physical Page Number bit position

// Masks for PTE Fields
`define PTE_V_MASK        (32'h1 << `SV32_PTE_V_SHIFT)
`define PTE_R_MASK        (32'h1 << `SV32_PTE_R_SHIFT)
`define PTE_W_MASK        (32'h1 << `SV32_PTE_W_SHIFT)
`define PTE_X_MASK        (32'h1 << `SV32_PTE_X_SHIFT)
`define PTE_U_MASK        (32'h1 << `SV32_PTE_U_SHIFT)
`define PTE_G_MASK        (32'h1 << `SV32_PTE_G_SHIFT)
`define PTE_A_MASK        (32'h1 << `SV32_PTE_A_SHIFT)
`define PTE_D_MASK        (32'h1 << `SV32_PTE_D_SHIFT)
`define PTE_RSW_MASK      (32'h3 << `SV32_PTE_RSW_SHIFT)
`define PTE_PPN_MASK      (32'hFFFFF000)

// Page Table Entry Macros - Set and Get
`define SET_PTE_V(val)    ((val) << `SV32_PTE_V_SHIFT)
`define SET_PTE_R(val)    ((val) << `SV32_PTE_R_SHIFT)
`define SET_PTE_W(val)    ((val) << `SV32_PTE_W_SHIFT)
`define SET_PTE_X(val)    ((val) << `SV32_PTE_X_SHIFT)
`define SET_PTE_U(val)    ((val) << `SV32_PTE_U_SHIFT)
`define SET_PTE_G(val)    ((val) << `SV32_PTE_G_SHIFT)
`define SET_PTE_A(val)    ((val) << `SV32_PTE_A_SHIFT)
`define SET_PTE_D(val)    ((val) << `SV32_PTE_D_SHIFT)
`define SET_PTE_RSW(val)  ((val) << `SV32_PTE_RSW_SHIFT)
`define SET_PTE_PPN(val)  ((val) << `SV32_PTE_PPN_SHIFT)

`define GET_PTE_V(pte)    (((pte) & `PTE_V_MASK) >> `SV32_PTE_V_SHIFT)
`define GET_PTE_R(pte)    (((pte) & `PTE_R_MASK) >> `SV32_PTE_R_SHIFT)
`define GET_PTE_W(pte)    (((pte) & `PTE_W_MASK) >> `SV32_PTE_W_SHIFT)
`define GET_PTE_X(pte)    (((pte) & `PTE_X_MASK) >> `SV32_PTE_X_SHIFT)
`define GET_PTE_U(pte)    (((pte) & `PTE_U_MASK) >> `SV32_PTE_U_SHIFT)
`define GET_PTE_G(pte)    (((pte) & `PTE_G_MASK) >> `SV32_PTE_G_SHIFT)
`define GET_PTE_A(pte)    (((pte) & `PTE_A_MASK) >> `SV32_PTE_A_SHIFT)
`define GET_PTE_D(pte)    (((pte) & `PTE_D_MASK) >> `SV32_PTE_D_SHIFT)
`define GET_PTE_RSW(pte)  (((pte) & `PTE_RSW_MASK) >> `SV32_PTE_RSW_SHIFT)
`define GET_PTE_PPN(pte)  (((pte) & `PTE_PPN_MASK) >> `SV32_PTE_PPN_SHIFT)

// SATP Register Field Positions and Masks
`define SATP_MODE_SHIFT   31
`define SATP_ASID_SHIFT   22
`define SATP_PPN_SHIFT    0

`define SATP_MODE_MASK    (32'h1 << `SATP_MODE_SHIFT)
`define SATP_ASID_MASK    (32'h3FF << `SATP_ASID_SHIFT)
`define SATP_PPN_MASK     (32'h3FFFFF << `SATP_PPN_SHIFT)

// SATP Register Macros - Set and Get
`define SET_SATP_MODE(mode) ((mode) << `SATP_MODE_SHIFT)
`define SET_SATP_ASID(asid) ((asid) << `SATP_ASID_SHIFT)
`define SET_SATP_PPN(ppn)   ((ppn) << `SATP_PPN_SHIFT)

`define GET_SATP_MODE(satp) (((satp) & `SATP_MODE_MASK) >> `SATP_MODE_SHIFT)
`define GET_SATP_ASID(satp) (((satp) & `SATP_ASID_MASK) >> `SATP_ASID_SHIFT)
`define GET_SATP_PPN(satp)  (((satp) & `SATP_PPN_MASK) >> `SATP_PPN_SHIFT)

`endif // SV32_SVH

