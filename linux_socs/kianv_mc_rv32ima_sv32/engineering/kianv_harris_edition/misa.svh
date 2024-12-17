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
// RISC-V MISA Register Definitions - SystemVerilog Header File
//
// This file defines the MISA register fields, extensions, and macros for
// checking and setting supported extensions in a RISC-V RV32 processor.
//
// **MISA Register Overview:**
// The MISA register is a Control and Status Register (CSR) that specifies:
// - **MXL Field**: Encodes the base ISA width.
//   - RV32: 2'b01
// - **Extension Bits**: Each bit represents support for a specific extension.
//
// MISA Register Format:
//  -------------------------------------------------------------------
//  | 31       | 30-0                                                       |
//  | MXL[1:0] | Extension Bits (A-Z and custom extensions)                 |
//  -------------------------------------------------------------------
//
// - **MXL[1:0]**: Encodes the base ISA width.
//     - 2'b01: RV32
//     - 2'b10: RV64
// - **Extension Bits**: Each bit corresponds to a specific RISC-V extension.
//     Example:
//       Bit 0 (A): Atomic Extension
//       Bit 12 (M): Integer Multiply/Divide
//       Bit 8 (I): Base Integer Instruction Set

`ifndef MISA_SVH
`define MISA_SVH

// Base ISA Width
`define MISA_MXL_RV32       2'b01

// MISA Extension Bits
`define MISA_EXTENSION_A    5'd0   // Atomic extension
`define MISA_EXTENSION_B    5'd1   // Tentatively reserved
`define MISA_EXTENSION_C    5'd2   // Compressed instructions
`define MISA_EXTENSION_D    5'd3   // Double-precision floating-point
`define MISA_EXTENSION_E    5'd4   // RV32E base ISA
`define MISA_EXTENSION_F    5'd5   // Single-precision floating-point
`define MISA_EXTENSION_G    5'd6   // General-purpose extension
`define MISA_EXTENSION_H    5'd7   // Hypervisor extension
`define MISA_EXTENSION_I    5'd8   // Base integer ISA
`define MISA_EXTENSION_J    5'd9   // Reserved for dynamic translations
`define MISA_EXTENSION_K    5'd10  // Reserved
`define MISA_EXTENSION_L    5'd11  // Tentatively reserved
`define MISA_EXTENSION_M    5'd12  // Integer Multiply/Divide
`define MISA_EXTENSION_N    5'd13  // User-level interrupts
`define MISA_EXTENSION_O    5'd14  // Reserved
`define MISA_EXTENSION_P    5'd15  // Packed-SIMD
`define MISA_EXTENSION_Q    5'd16  // Quad-precision floating-point
`define MISA_EXTENSION_R    5'd17  // Reserved
`define MISA_EXTENSION_S    5'd18  // Supervisor mode
`define MISA_EXTENSION_T    5'd19  // Tentatively reserved
`define MISA_EXTENSION_U    5'd20  // User mode
`define MISA_EXTENSION_V    5'd21  // Vector extension
`define MISA_EXTENSION_W    5'd22  // Reserved
`define MISA_EXTENSION_X    5'd23  // Non-standard extensions
`define MISA_EXTENSION_Y    5'd24  // Reserved
`define MISA_EXTENSION_Z    5'd25  // Reserved

// Macro to Check if an Extension is Supported
`define IS_EXTENSION_SUPPORTED(MXL, Extensions, Ext_To_Check) \
    (((MXL) == `MISA_MXL_RV32) && (((Extensions) >> (Ext_To_Check)) & 1'b1))

// Macro to Set MISA Value for RV32
`define SET_MISA_VALUE(MXL)        ((MXL) << 30)

// Macro to Create Extension Bit Mask
`define MISA_EXTENSION_BIT(extension) (1 << extension)

`endif // MISA_SVH
