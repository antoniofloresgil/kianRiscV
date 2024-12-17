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
// RISC-V Control Unit - SystemVerilog Implementation
//
// This module implements the control unit for the RISC-V RV32IM architecture.
// It generates control signals for various components such as ALU, memory,
// CSR registers, and exception handlers.
//
// **Inputs:**
// - clk, resetn: Clock and active-low reset.
// - op, funct3, funct7: Decoded instruction fields.
// - Zero: Zero flag from ALU.
// - Rs1, Rs2, Rd: Register addresses.
// - Various signals for faults, IRQ, and privilege levels.
//
// **Outputs:**
// - Control signals for ALU, memory, and exception handling modules.
//
`default_nettype none
`include "riscv_defines.svh"

module control_unit (
    input  logic                       clk,
    input  logic                       resetn,
    input  logic [6:0]                 op,
    input  logic [2:0]                 funct3,
    input  logic [6:0]                 funct7,
    input  logic                       immb10,
    input  logic                       Zero,
    input  logic [4:0]                 Rs1,
    input  logic [4:0]                 Rs2,
    input  logic [4:0]                 Rd,
    output logic [`RESULT_WIDTH-1:0]   ResultSrc,
    output logic [`ALU_CTRL_WIDTH-1:0] ALUControl,
    output logic [`SRCA_WIDTH-1:0]     ALUSrcA,
    output logic [`SRCB_WIDTH-1:0]     ALUSrcB,
    output logic [2:0]                 ImmSrc,
    output logic [`STORE_OP_WIDTH-1:0] STOREop,
    output logic [`LOAD_OP_WIDTH-1:0]  LOADop,
    output logic [`MUL_OP_WIDTH-1:0]   MULop,
    output logic [`DIV_OP_WIDTH-1:0]   DIVop,
    output logic [`CSR_OP_WIDTH-1:0]   CSRop,
    output logic                       CSRwe,
    output logic                       CSRre,
    output logic                       RegWrite,
    output logic                       PCWrite,
    output logic                       AdrSrc,
    output logic                       MemWrite,
    input  logic                       access_fault,
    input  logic                       page_fault,
    output logic                       store_instr,
    output logic                       incr_inst_retired,
    output logic                       ALUOutWrite,
    output logic                       amo_temp_write_operation,
    output logic                       muxed_Aluout_or_amo_rd_wr,
    output logic                       amo_set_reserved_state_load,
    output logic                       amo_buffered_data,
    output logic                       amo_buffered_address,
    input  logic                       amo_reserved_state_load,
    output logic                       select_ALUResult,
    output logic                       select_amo_temp,

    // Exception Handler
    output logic                       exception_event,
    output logic [31:0]                cause,
    output logic [31:0]                badaddr,
    output logic                       mret,
    output logic                       sret,
    output logic                       wfi_event,
    input  logic [1:0]                 privilege_mode,
    input  logic                       csr_access_fault,
    input  logic [31:0]                fault_address,
    output logic                       selectPC,
    output logic                       tlb_flush,

    input  logic                       IRQ_TO_CPU_CTRL1,  // SSIP
    input  logic                       IRQ_TO_CPU_CTRL3,  // MSIP
    input  logic                       IRQ_TO_CPU_CTRL5,  // STIP
    input  logic                       IRQ_TO_CPU_CTRL7,  // MTIP
    input  logic                       IRQ_TO_CPU_CTRL9,  // SEIP
    input  logic                       IRQ_TO_CPU_CTRL11, // MEIP

    output logic                       is_instruction,
    input  logic                       stall,

    output logic                       mem_valid,
    input  logic                       mem_ready,
    input  logic [31:0]                cpu_mem_addr,

    output logic                       mul_valid,
    input  logic                       mul_ready,

    output logic                       div_valid,
    input  logic                       div_ready
);

  logic [`ALU_OP_WIDTH-1:0] ALUOp;
  logic [`AMO_OP_WIDTH-1:0] AMOop;
  logic PCUpdate;
  logic Branch;
  logic mul_ext_ready;
  logic mul_ext_valid;
  logic taken_branch;

  assign taken_branch = !Zero;
  assign PCWrite = Branch & taken_branch | PCUpdate;
  assign mul_ext_ready = mul_ready | div_ready;

  logic amo_data_load;
  logic amo_operation_store;
  logic is_load_unaligned;
  logic is_store_unaligned;
  logic is_instruction_unaligned;

  assign is_instruction_unaligned = |cpu_mem_addr[1:0];
  logic CSRvalid;

  main_fsm main_fsm_I (
      .clk              (clk),
      .resetn           (resetn),
      .op               (op),
      .funct7           (funct7),
      .funct3           (funct3),
      .Rs1              (Rs1),
      .Rs2              (Rs2),
      .Rd               (Rd),
      .Zero             (Zero),
      .AdrSrc           (AdrSrc),
      .is_instruction   (is_instruction),
      .stall            (stall),
      .store_instr      (store_instr),
      .incr_inst_retired(incr_inst_retired),
      .ALUSrcA          (ALUSrcA),
      .ALUSrcB          (ALUSrcB),
      .ALUOp            (ALUOp),
      .AMOop            (AMOop),
      .ResultSrc        (ResultSrc),
      .ImmSrc           (ImmSrc),
      .CSRvalid         (CSRvalid),
      .PCUpdate         (PCUpdate),
      .Branch           (Branch),
      .RegWrite         (RegWrite),
      .ALUOutWrite      (ALUOutWrite),
      .fault_address    (fault_address),
      .cpu_mem_addr     (cpu_mem_addr),
      .amo_temp_write_operation   (amo_temp_write_operation),
      .amo_data_load              (amo_data_load),
      .amo_operation_store        (amo_operation_store),
      .muxed_Aluout_or_amo_rd_wr  (muxed_Aluout_or_amo_rd_wr),
      .amo_set_reserved_state_load(amo_set_reserved_state_load),
      .amo_buffered_data          (amo_buffered_data),
      .amo_buffered_address       (amo_buffered_address),
      .amo_reserved_state_load    (amo_reserved_state_load),
      .select_ALUResult           (select_ALUResult),
      .select_amo_temp            (select_amo_temp),
      .MemWrite                   (MemWrite),
      .is_instruction_unaligned   (is_instruction_unaligned),
      .is_load_unaligned          (is_load_unaligned),
      .is_store_unaligned         (is_store_unaligned),
      .access_fault               (access_fault),
      .page_fault                 (page_fault),
      .selectPC                   (selectPC),
      .tlb_flush                  (tlb_flush),
      .exception_event            (exception_event),
      .cause                      (cause),
      .badaddr                    (badaddr),
      .mret                       (mret),
      .sret                       (sret),
      .wfi_event                  (wfi_event),
      .privilege_mode             (privilege_mode),
      .csr_access_fault           (csr_access_fault),
      .IRQ_TO_CPU_CTRL1           (IRQ_TO_CPU_CTRL1),
      .IRQ_TO_CPU_CTRL3           (IRQ_TO_CPU_CTRL3),
      .IRQ_TO_CPU_CTRL5           (IRQ_TO_CPU_CTRL5),
      .IRQ_TO_CPU_CTRL7           (IRQ_TO_CPU_CTRL7),
      .IRQ_TO_CPU_CTRL9           (IRQ_TO_CPU_CTRL9),
      .IRQ_TO_CPU_CTRL11          (IRQ_TO_CPU_CTRL11),
      .mem_valid                  (mem_valid),
      .mem_ready                  (mem_ready),
      .mul_ext_valid              (mul_ext_valid),
      .mul_ext_ready              (mul_ext_ready)
  );

  load_decoder load_decoder_I (
      .funct3           (funct3),
      .amo_data_load    (amo_data_load),
      .LOADop           (LOADop),
      .addr_align_bits  (cpu_mem_addr[1:0]),
      .is_load_unaligned(is_load_unaligned)
  );

  store_decoder store_decoder_I (
      .funct3             (funct3),
      .amo_operation_store(amo_operation_store),
      .STOREop            (STOREop),
      .addr_align_bits    (cpu_mem_addr[1:0]),
      .is_store_unaligned (is_store_unaligned)
  );

  csr_decoder csr_decoder_I (
      .funct3(funct3),
      .Rs1Uimm(Rs1),
      .Rd(Rd),
      .valid(CSRvalid),
      .CSRwe(CSRwe),
      .CSRre(CSRre),
      .CSRop(CSRop)
  );

  alu_decoder alu_decoder_I (
      .imm_bit10 (immb10),
      .op_bit5   (op[5]),
      .funct3    (funct3),
      .funct7b5  (funct7[5]),
      .ALUOp     (ALUOp),
      .AMOop     (AMOop),
      .ALUControl(ALUControl)
  );

  multiplier_extension_decoder multiplier_extension_decoder_I (
      .funct3       (funct3),
      .MULop        (MULop),
      .DIVop        (DIVop),
      .mul_ext_valid(mul_ext_valid),
      .mul_valid    (mul_valid),
      .div_valid    (div_valid)
  );

endmodule
