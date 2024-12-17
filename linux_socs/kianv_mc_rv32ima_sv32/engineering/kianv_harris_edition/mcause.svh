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
//
// RISC-V Exception and Interrupt Codes - SystemVerilog
//
// This file defines the exception and interrupt codes for the mcause register
// in the RISC-V architecture. The mcause register holds information about the
// cause of exceptions and interrupts in the processor.
//
// **How the mcause Register Works:**
// - The mcause register is a 32-bit register.
// - Bit [31]: Interrupt flag (1 = Interrupt, 0 = Exception)
// - Bits [30:0]: Exception or Interrupt cause code.
//   - If the interrupt flag is 1, the code identifies the source of the interrupt.
//   - If the interrupt flag is 0, the code identifies the cause of the exception.
//
// Example:
// - A value of `0x80000007` in mcause indicates a **Machine Timer Interrupt**.
// - A value of `0x00000002` in mcause indicates an **Illegal Instruction Exception**.
//

`ifndef MCAUSE_SVH
`define MCAUSE_SVH

// Exception Codes
`define EXC_INSTR_ADDR_MISALIGNED     32'h00000000
`define EXC_INSTR_ACCESS_FAULT        32'h00000001
`define EXC_ILLEGAL_INSTRUCTION       32'h00000002
`define EXC_BREAKPOINT                32'h00000003
`define EXC_LOAD_AMO_ADDR_MISALIGNED  32'h00000004
`define EXC_LOAD_AMO_ACCESS_FAULT     32'h00000005
`define EXC_STORE_AMO_ADDR_MISALIGNED 32'h00000006
`define EXC_STORE_AMO_ACCESS_FAULT    32'h00000007
`define EXC_ECALL_FROM_UMODE          32'h00000008
`define EXC_ECALL_FROM_SMODE          32'h00000009
`define EXC_ECALL_FROM_MMODE          32'h0000000B
`define EXC_INSTR_PAGE_FAULT          32'h0000000C
`define EXC_LOAD_PAGE_FAULT           32'h0000000D
`define EXC_STORE_AMO_PAGE_FAULT      32'h0000000F

// Interrupt Codes
`define INTERRUPT_USER_SOFTWARE       32'h80000000
`define INTERRUPT_SUPERVISOR_SOFTWARE 32'h80000001
`define INTERRUPT_MACHINE_SOFTWARE    32'h80000003
`define INTERRUPT_USER_TIMER          32'h80000004
`define INTERRUPT_SUPERVISOR_TIMER    32'h80000005
`define INTERRUPT_MACHINE_TIMER       32'h80000007
`define INTERRUPT_USER_EXTERNAL       32'h80000008
`define INTERRUPT_SUPERVISOR_EXTERNAL 32'h80000009
`define INTERRUPT_MACHINE_EXTERNAL    32'h8000000B

`endif // MCAUSE_SVH
