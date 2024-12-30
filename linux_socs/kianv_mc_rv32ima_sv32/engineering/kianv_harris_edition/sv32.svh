/*
 *  kianv harris multicycle RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */

`ifndef SV32_VH
`define SV32_VH

// General configuration for Sv32 (32-bit virtual addressing)
`define SV32_LEVELS 2  // Number of page table levels
`define SV32_PTE_SIZE 4  // Size of a page table entry in bytes
`define SV32_PTE_SHIFT 2  // Log2 of PTE size (used for alignment)

// Bit positions in a page table entry (PTE)
`define SV32_PTE_V_SHIFT 0  // Valid bit position
`define SV32_PTE_R_SHIFT 1  // Read permission bit position
`define SV32_PTE_W_SHIFT 2  // Write permission bit position
`define SV32_PTE_X_SHIFT 3  // Execute permission bit position
`define SV32_PTE_U_SHIFT 4  // User mode accessibility bit position
`define SV32_PTE_G_SHIFT 5  // Global mapping bit position
`define SV32_PTE_A_SHIFT 6  // Accessed bit position (set on access)
`define SV32_PTE_D_SHIFT 7  // Dirty bit position (set on write)
`define SV32_PTE_RSW_SHIFT 8  // Reserved for software use (2 bits)
`define SV32_PTE_PPN_SHIFT 10  // Physical Page Number bit position
`define SV32_PTE_ALIGNED_PPN_SHIFT (`SV32_PTE_PPN_SHIFT + 2)  // Aligned PPN position

// Memory and addressing constants
`define SV32_PTE_PPN_BITS 22  // Number of bits for Physical Page Number
`define SV32_PAGE_SIZE 4096  // Page size in bytes (4 KiB for Sv32)
`define SV32_PAGE_OFFSET_BITS 12  // Number of bits for page offset (log2 of page size)

`define SV32_OFFSET_BITS 12  // Bits for page offset
`define SV32_VPN0_BITS 10  // Bits for first-level virtual page number
`define SV32_VPN1_BITS 10  // Bits for second-level virtual page number

// SATP register bit masks
`define SV32_SATP_MODE_MASK 31  // Mask for mode field in SATP register

// Address masks for virtual page numbers and offsets
`define SV32_OFFSET_MASK ((32'h1 << `SV32_OFFSET_BITS) - 1)  // Mask for page offset
`define SV32_VPN0_MASK (((32'h1 << `SV32_VPN0_BITS) - 1) << `SV32_OFFSET_BITS)  // Mask for VPN0
`define SV32_VPN1_MASK (((32'h1 << `SV32_VPN1_BITS) - 1) << (`SV32_OFFSET_BITS + `SV32_VPN0_BITS))  // Mask for VPN1

// Shifts for virtual page numbers
`define SV32_VPN0_SHIFT 10  // VPN0 shift
`define SV32_VPN1_SHIFT (`SV32_OFFSET_BITS + `SV32_VPN0_BITS)  // VPN1 shift

// Masks for specific PTE flags
`define PTE_V_MASK (32'h1 << 0)  // Valid bit mask
`define PTE_R_MASK (32'h1 << 1)  // Read permission bit mask
`define PTE_W_MASK (32'h1 << 2)  // Write permission bit mask
`define PTE_X_MASK (32'h1 << 3)  // Execute permission bit mask
`define PTE_U_MASK (32'h1 << 4)  // User mode bit mask
`define PTE_G_MASK (32'h1 << 5)  // Global bit mask
`define PTE_A_MASK (32'h1 << 6)  // Accessed bit mask
`define PTE_D_MASK (32'h1 << 7)  // Dirty bit mask
`define PTE_RSW_MASK (32'h3 << 8)  // Reserved for software (2 bits)
`define PTE_PPN_MASK 32'hFFFFF000  // Physical Page Number mask
`define PTE_FLAGS 32'h3FF  // Mask for all PTE flags

// Macros to set individual fields in a PTE
`define SET_PTE_V(pte, val) ((val) << 0)  // Set Valid bit
`define SET_PTE_R(pte, val) ((val) << 1)  // Set Read bit
`define SET_PTE_W(pte, val) ((val) << 2)  // Set Write bit
`define SET_PTE_X(pte, val) ((val) << 3)  // Set Execute bit
`define SET_PTE_U(pte, val) ((val) << 4)  // Set User mode bit
`define SET_PTE_G(pte, val) ((val) << 5)  // Set Global bit
`define SET_PTE_A(pte, val) ((val) << 6)  // Set Accessed bit
`define SET_PTE_D(pte, val) ((val) << 7)  // Set Dirty bit
`define SET_PTE_RSW(pte, val) ((val) << 8)  // Set Reserved bits
`define SET_PTE_PPN(pte, val) ((val) << 10)  // Set Physical Page Number

// Macros to extract individual fields from a PTE
`define GET_PTE_V(pte) (((pte) & `PTE_V_MASK) >> 0)  // Get Valid bit
`define GET_PTE_R(pte) (((pte) & `PTE_R_MASK) >> 1)  // Get Read bit
`define GET_PTE_W(pte) (((pte) & `PTE_W_MASK) >> 2)  // Get Write bit
`define GET_PTE_X(pte) (((pte) & `PTE_X_MASK) >> 3)  // Get Execute bit
`define GET_PTE_U(pte) (((pte) & `PTE_U_MASK) >> 4)  // Get User mode bit
`define GET_PTE_G(pte) (((pte) & `PTE_G_MASK) >> 5)  // Get Global bit
`define GET_PTE_A(pte) (((pte) & `PTE_A_MASK) >> 6)  // Get Accessed bit
`define GET_PTE_D(pte) (((pte) & `PTE_D_MASK) >> 7)  // Get Dirty bit
`define GET_PTE_RSW(pte) (((pte) & `PTE_RSW_MASK) >> 8)  // Get Reserved bits
`define GET_PTE_PPN(pte) (((pte) & `PTE_PPN_MASK) >> 10)  // Get Physical Page Number

// SATP (Supervisor Address Translation and Protection) register fields
`define SATP_MODE_MASK 32'h80000000  // Mask for SATP mode field
`define SATP_ASID_MASK 32'h7FC00000  // Mask for ASID (Address Space ID)
`define SATP_PPN_MASK 32'h003FFFFF  // Mask for Physical Page Number

// Shifts for SATP fields
`define SATP_MODE_SHIFT 31  // Shift for mode field
`define SATP_ASID_SHIFT 22  // Shift for ASID field
`define SATP_PPN_SHIFT 0  // Shift for Physical Page Number field

// Macros to set SATP fields
`define SET_SATP_MODE(satp, mode) ((mode) << `SATP_MODE_SHIFT)  // Set mode field
`define SET_SATP_ASID(satp, asid) ((asid) << `SATP_ASID_SHIFT)  // Set ASID field
`define SET_SATP_PPN(satp, ppn) ((ppn) << `SATP_PPN_SHIFT)  // Set Physical Page Number field

// Macros to extract SATP fields
`define GET_SATP_MODE(satp) (((satp) & `SATP_MODE_MASK) >> `SATP_MODE_SHIFT)  // Get mode field
`define GET_SATP_ASID(satp) (((satp) & `SATP_ASID_MASK) >> `SATP_ASID_SHIFT)  // Get ASID field
`define GET_SATP_PPN(satp) (((satp) & `SATP_PPN_MASK) >> `SATP_PPN_SHIFT)  // Get Physical Page Number field

`endif

