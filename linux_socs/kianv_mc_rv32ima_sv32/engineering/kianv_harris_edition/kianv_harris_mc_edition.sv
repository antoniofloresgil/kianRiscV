
//
// Copyright (c) 2022/2023/2024 Hirosh Dabui <hirosh@dabui.de>
// Port to SystemVerilog Copyright (c) 2024 Antonio Flores <aflores@um.es>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// RISC-V Multi-Cycle CPU Core - SystemVerilog Implementation
//
// This module implements a multi-cycle RISC-V CPU core compliant with the RV32IMA
// architecture. It integrates the control unit, datapath unit, and a memory management unit (MMU)
// to execute instructions with support for interrupts, exceptions, and memory-mapped operations.
// 
// Key features:
// - Multi-cycle execution for arithmetic, memory, and control operations.
// - Support for CSR (Control and Status Registers) operations.
// - Exception and interrupt handling, including timer interrupts.
// - Integration with SV32 MMU for address translation.
// - Full support for atomic memory operations (AMO) and privilege modes.
//

`default_nettype none
`include "riscv_defines.svh"

// Top-level module: Kianv Harris MC Edition
module kianv_harris_mc_edition #(
    parameter int RESET_ADDR        = 0,
    parameter int SYSTEM_CLK        = 50_000_000,
    parameter int NUM_ENTRIES_ITLB  = 64,
    parameter int NUM_ENTRIES_DTLB  = 64
) (
    input  logic         clk,
    input  logic         resetn,
    output logic         mem_valid,
    input  logic         mem_ready,
    output logic [3:0]   mem_wstrb,
    output logic [33:0]  mem_addr,
    output logic [31:0]  mem_wdata,
    input  logic [31:0]  mem_rdata,
    output logic [31:0]  PC,
    input  logic         access_fault,
    input  logic         IRQ3,
    input  logic         IRQ7,
    input  logic         IRQ9,
    input  logic         IRQ11,
    output logic [63:0]  timer_counter,
    output logic         is_instruction
);

  // Internal signal declarations
  logic [31:0] Instr;
  logic [6:0]  op;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic        immb10; // Single-bit immediate from bit 10

  logic        Zero;

  logic [`RESULT_WIDTH-1:0] ResultSrc;
  logic [`ALU_CTRL_WIDTH-1:0] ALUControl;
  logic [`SRCA_WIDTH-1:0] ALUSrcA;
  logic [`SRCB_WIDTH-1:0] ALUSrcB;
  logic [2:0]  ImmSrc;
  logic [`STORE_OP_WIDTH-1:0] STOREop;
  logic [`LOAD_OP_WIDTH-1:0] LOADop;
  logic [`MUL_OP_WIDTH-1:0] MULop;
  logic [`DIV_OP_WIDTH-1:0] DIVop;
  logic [`CSR_OP_WIDTH-1:0] CSRop;
  logic        CSRwe;
  logic        CSRre;
  logic [4:0]  Rs1;
  logic [4:0]  Rs2;
  logic [4:0]  Rd;

  logic        RegWrite;
  logic        PCWrite;
  logic        AdrSrc;
  logic        MemWrite;
  logic        store_instr;
  logic        incr_inst_retired;
  logic        ALUOutWrite;

  logic        mul_valid;
  logic        mul_ready;
  logic        div_valid;
  logic        div_ready;

  // Assign specific instruction bits to control fields
  assign op     = Instr[6:0];
  assign funct3 = Instr[14:12];
  assign funct7 = Instr[31:25];
  assign Rs1    = Instr[19:15];
  assign Rs2    = Instr[24:20];
  assign Rd     = Instr[11:7];

  // AMO (Atomic Memory Operation) signals
  logic amo_temp_write_operation;
  logic amo_set_reserved_state_load;
  logic amo_buffered_data;
  logic amo_buffered_address;
  logic amo_reserved_state_load;
  logic muxed_Aluout_or_amo_rd_wr;
  logic select_ALUResult;
  logic select_amo_temp;

  // Exception Handler signals
  // These signals are used for exception handling and interrupt control.
  logic        exception_event;
  logic [31:0] cause;
  logic [31:0] badaddr;
  logic        mret;
  logic        sret;
  logic        wfi_event;
  logic        csr_access_fault;
  logic [31:0] mstatus;

  // CPU interrupt control signals
  logic IRQ_TO_CPU_CTRL1; // SSIP
  logic IRQ_TO_CPU_CTRL3; // MSIP
  logic IRQ_TO_CPU_CTRL5; // STIP
  logic IRQ_TO_CPU_CTRL7; // MTIP
  logic IRQ_TO_CPU_CTRL9; // SEIP
  logic IRQ_TO_CPU_CTRL11; // MEIP

  logic        page_fault;
  logic        selectPC;
  logic        tlb_flush;
  logic        tlb_flush_csr;
  logic [31:0] satp;
  logic [1:0]  privilege_mode;

  // Signals connecting CPU and memory (or MMU)
  logic        cpu_mem_ready;
  logic        cpu_mem_valid;
  logic [3:0]  cpu_mem_wstrb;
  logic [31:0] cpu_mem_addr;
  logic [31:0] cpu_mem_wdata;
  logic [31:0] cpu_mem_rdata;
  logic [31:0] sv32_fault_address;

  logic [1:0]  addr_align_bits;

  logic        stall;

  // Instantiate the control unit
  control_unit control_unit_I (
      .clk              (clk),
      .resetn           (resetn),
      .op               (op),
      .funct3           (funct3),
      .funct7           (funct7),
      .immb10           (immb10),
      .Zero             (Zero),
      .Rs1              (Rs1),
      .Rs2              (Rs2),
      .Rd               (Rd),
      .ResultSrc        (ResultSrc),
      .ALUControl       (ALUControl),
      .ALUSrcA          (ALUSrcA),
      .ALUSrcB          (ALUSrcB),
      .ImmSrc           (ImmSrc),
      .STOREop          (STOREop),
      .LOADop           (LOADop),
      .CSRop            (CSRop),
      .CSRwe            (CSRwe),
      .CSRre            (CSRre),
      .RegWrite         (RegWrite),
      .PCWrite          (PCWrite),
      .AdrSrc           (AdrSrc),
      .fault_address    (sv32_fault_address),
      .MemWrite         (MemWrite),
      .store_instr      (store_instr),
      .is_instruction   (is_instruction),
      .stall            (stall),
      .incr_inst_retired(incr_inst_retired),
      .ALUOutWrite      (ALUOutWrite),
      .mem_valid        (cpu_mem_valid),
      .mem_ready        (cpu_mem_ready),
      .cpu_mem_addr     (cpu_mem_addr),
      .MULop            (MULop),
      .access_fault     (access_fault),
      .page_fault       (page_fault),
      .selectPC         (selectPC),
      .tlb_flush        (tlb_flush),
      .mul_valid        (mul_valid),
      .mul_ready        (mul_ready),
      .DIVop            (DIVop),
      .div_valid        (div_valid),
      .div_ready        (div_ready),
      // AMO signals
      .amo_temp_write_operation   (amo_temp_write_operation),
      .amo_set_reserved_state_load(amo_set_reserved_state_load),
      .amo_buffered_data          (amo_buffered_data),
      .amo_buffered_address       (amo_buffered_address),
      .amo_reserved_state_load    (amo_reserved_state_load),
      .muxed_Aluout_or_amo_rd_wr  (muxed_Aluout_or_amo_rd_wr),
      .select_ALUResult           (select_ALUResult),
      .select_amo_temp            (select_amo_temp),
      .exception_event (exception_event),
      .cause           (cause),
      .badaddr         (badaddr),
      .mret            (mret),
      .sret            (sret),
      .wfi_event       (wfi_event),
      .privilege_mode  (privilege_mode),
      .csr_access_fault(csr_access_fault),
      .IRQ_TO_CPU_CTRL1(IRQ_TO_CPU_CTRL1),  // SSIP
      .IRQ_TO_CPU_CTRL3(IRQ_TO_CPU_CTRL3),  // MSIP
      .IRQ_TO_CPU_CTRL5(IRQ_TO_CPU_CTRL5),  // STIP
      .IRQ_TO_CPU_CTRL7(IRQ_TO_CPU_CTRL7),  // MTIP
      .IRQ_TO_CPU_CTRL9(IRQ_TO_CPU_CTRL9),  // SEIP
      .IRQ_TO_CPU_CTRL11(IRQ_TO_CPU_CTRL11) // MEIP
  );

  // Instantiate the datapath unit
  datapath_unit #(
      .RESET_ADDR(RESET_ADDR),
      .SYSTEM_CLK(SYSTEM_CLK)
  ) datapath_unit_I (
      .clk            (clk),
      .resetn         (resetn),
      .ResultSrc      (ResultSrc),
      .ALUControl     (ALUControl),
      .ALUSrcA        (ALUSrcA),
      .ALUSrcB        (ALUSrcB),
      .ImmSrc         (ImmSrc),
      .STOREop        (STOREop),
      .LOADop         (LOADop),
      .CSRop          (CSRop),
      .CSRwe          (CSRwe),
      .CSRre          (CSRre),
      .Zero           (Zero),
      .immb10         (immb10),
      .RegWrite       (RegWrite),
      .PCWrite        (PCWrite),
      .AdrSrc         (AdrSrc),
      .MemWrite       (MemWrite),
      .incr_inst_retired(incr_inst_retired),
      .store_instr    (store_instr),
      .ALUOutWrite    (ALUOutWrite),
      .Instr          (Instr),
      .mem_wstrb      (cpu_mem_wstrb),
      .mem_addr       (cpu_mem_addr),
      .mem_wdata      (cpu_mem_wdata),
      .mem_rdata      (cpu_mem_rdata),
      .MULop          (MULop),
      .mul_valid      (mul_valid),
      .mul_ready      (mul_ready),
      .DIVop          (DIVop),
      .div_valid      (div_valid),
      .div_ready      (div_ready),
      .ProgCounter    (PC),
      // AMO signals
      .amo_temp_write_operation   (amo_temp_write_operation),
      .amo_set_reserved_state_load(amo_set_reserved_state_load),
      .amo_buffered_data          (amo_buffered_data),
      .amo_buffered_address       (amo_buffered_address),
      .amo_reserved_state_load    (amo_reserved_state_load),
      .muxed_Aluout_or_amo_rd_wr  (muxed_Aluout_or_amo_rd_wr),
      .select_ALUResult           (select_ALUResult),
      .select_amo_temp            (select_amo_temp),
      // Exception signals
      .exception_event (exception_event),
      .cause           (cause),
      .badaddr         (badaddr),
      .mret            (mret),
      .sret            (sret),
      .wfi_event       (wfi_event),
      .privilege_mode  (privilege_mode),
      .csr_access_fault(csr_access_fault),
      .mstatus         (mstatus),
      .satp            (satp),
      .tlb_flush       (tlb_flush_csr),
      .timer_counter   (timer_counter),
      .page_fault      (page_fault),
      .selectPC        (selectPC),
      .IRQ3            (IRQ3),
      .IRQ7            (IRQ7),
      .IRQ9            (IRQ9),
      .IRQ11           (IRQ11),
      .IRQ_TO_CPU_CTRL1(IRQ_TO_CPU_CTRL1),  // SSIP
      .IRQ_TO_CPU_CTRL3(IRQ_TO_CPU_CTRL3),  // MSIP
      .IRQ_TO_CPU_CTRL5(IRQ_TO_CPU_CTRL5),  // STIP
      .IRQ_TO_CPU_CTRL7(IRQ_TO_CPU_CTRL7),  // MTIP
      .IRQ_TO_CPU_CTRL9(IRQ_TO_CPU_CTRL9),  // SEIP
      .IRQ_TO_CPU_CTRL11(IRQ_TO_CPU_CTRL11) // MEIP
  );

  // Instantiate the MMU (sv32)
  sv32 #(
      // Pass the top-level parameters to the MMU
      .NUM_ENTRIES_ITLB(NUM_ENTRIES_ITLB),
      .NUM_ENTRIES_DTLB(NUM_ENTRIES_DTLB)
  ) mmu_I (
      .clk          (clk),
      .resetn       (resetn),
      .cpu_valid    (cpu_mem_valid),
      .cpu_ready    (cpu_mem_ready),
      .cpu_wstrb    (cpu_mem_wstrb),
      .cpu_addr     (cpu_mem_addr),
      .cpu_wdata    (cpu_mem_wdata),
      .cpu_rdata    (cpu_mem_rdata),
      .mem_valid    (mem_valid),
      .mem_ready    (mem_ready),
      .mem_wstrb    (mem_wstrb),
      .mem_addr     (mem_addr),
      .mem_wdata    (mem_wdata),
      .mem_rdata    (mem_rdata),
      .fault_address(sv32_fault_address),
      .privilege_mode(privilege_mode),
      .is_instruction(is_instruction),
      .tlb_flush    (tlb_flush | tlb_flush_csr),
      .stall        (stall),
      .satp         (satp),
      .mstatus      (mstatus),
      .page_fault   (page_fault)
  );

endmodule

