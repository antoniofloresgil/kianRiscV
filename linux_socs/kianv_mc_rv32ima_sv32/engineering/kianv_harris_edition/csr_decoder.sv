//
//  kianv.v - RISC-V rv32ima
//
//  copyright (c) 2022/23/24 hirosh dabui <hirosh@dabui.de>
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
// RISC-V CSR Decoder - SystemVerilog Implementation
//
// **CSR (Control and Status Registers) Overview:**
// CSRs are a fundamental part of the RISC-V architecture and allow software to interact
// with processor control, configuration, and status information. CSRs can be used
// for exception handling, interrupts, timers, and privilege management.
//
// CSR Instructions:
// The CSR instructions include operations for reading and writing to these registers:
//
// - **CSRRW**: Read-modify-write to CSR.
// - **CSRRS**: Read CSR and set bits.
// - **CSRRC**: Read CSR and clear bits.
// - **CSRRWI**: Write immediate to CSR.
// - **CSRRSI**: Read CSR and set bits using immediate.
// - **CSRRCI**: Read CSR and clear bits using immediate.
//
// Instruction Encoding for CSR Operations:
//
// --------------------------------------------------------------------------
// | 31    20 | 19  15 | 14  12 | 11   7 | 6       0 |
// | csr[11:0]| rs1/uim| funct3 | rd[4:0]| opcode   |
// --------------------------------------------------------------------------
// | csr      | Source | OpType | Dest   | SYSTEM   |
// --------------------------------------------------------------------------
//
// - `csr[11:0]`: Address of the CSR.
// - `rs1/uimm`: Source register or immediate value.
// - `funct3`: Operation code for CSR instructions.
// - `rd`: Destination register.
// - `opcode`: Fixed opcode for CSR operations (`1110011`).
//
// **CSR Operations Summary:**
// - CSRRW: Write value to CSR, optionally read old value.
// - CSRRS: Set CSR bits.
// - CSRRC: Clear CSR bits.
// - CSRRWI: Write immediate to CSR.
// - CSRRSI: Set CSR bits using immediate.
// - CSRRCI: Clear CSR bits using immediate.
//
// **CSR Detailed Operation:**
//
// --------------------------------------------------------------------------
// | Instruction | rd    | rs1/uimm | Read CSR? | Write CSR? |
// --------------------------------------------------------------------------
// | CSRRW       | x0    | -        | No        | Yes       |
// | CSRRW       | !x0   | -        | Yes       | Yes       |
// | CSRRS       | -     | x0       | Yes       | No        |
// | CSRRS       | -     | !x0      | Yes       | Yes       |
// | CSRRC       | -     | x0       | Yes       | No        |
// | CSRRC       | -     | !x0      | Yes       | Yes       |
// | CSRRWI      | x0    | -        | No        | Yes       |
// | CSRRWI      | !x0   | -        | Yes       | Yes       |
// | CSRRSI      | -     | 0        | Yes       | No        |
// | CSRRSI      | -     | !0       | Yes       | Yes       |
// | CSRRCI      | -     | 0        | Yes       | No        |
// | CSRRCI      | -     | !0       | Yes       | Yes       |
// --------------------------------------------------------------------------
//
`default_nettype none
`include "riscv_defines.svh"

module csr_decoder (
    input  logic [2:0]                 funct3,
    input  logic [4:0]                 Rs1Uimm,
    input  logic [4:0]                 Rd,
    input  logic                       valid,
    output logic                       CSRwe,
    output logic                       CSRre,
    output logic [`CSR_OP_WIDTH-1:0]   CSRop
);

  logic is_csrrw, is_csrrs, is_csrrc;
  logic is_csrrwi, is_csrrsi, is_csrrci;

  assign is_csrrw  = (funct3 == 3'b001);
  assign is_csrrs  = (funct3 == 3'b010);
  assign is_csrrc  = (funct3 == 3'b011);
  assign is_csrrwi = (funct3 == 3'b101);
  assign is_csrrsi = (funct3 == 3'b110);
  assign is_csrrci = (funct3 == 3'b111);

  logic we;
  logic re;

  assign CSRwe = we && valid;
  assign CSRre = re && valid;

  always_comb begin
    we = 1'b0;
    re = 1'b0;
    case (1'b1)
      is_csrrw: begin
        we = 1'b1;
        re = |Rd;
        CSRop = `CSR_OP_CSRRW;
      end
      is_csrrs: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRS;
      end
      is_csrrc: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRC;
      end
      is_csrrwi: begin
        we = 1'b1;
        re = |Rd;
        CSRop = `CSR_OP_CSRRWI;
      end
      is_csrrsi: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRSI;
      end
      is_csrrci: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRCI;
      end
      default: begin
        we = 1'b0;
        re = 1'b0;
        CSRop = `CSR_OP_NA;
      end
    endcase
  end

endmodule
