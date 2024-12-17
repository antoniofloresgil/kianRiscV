
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

module kianv_harris_mc_edition #(
    parameter int RESET_ADDR        = 0,          // Reset address
    parameter int SYSTEM_CLK        = 50_000_000, // System clock frequency
    parameter int NUM_ENTRIES_ITLB  = 64,         // Instruction TLB entries
    parameter int NUM_ENTRIES_DTLB  = 64          // Data TLB entries
) (
    input  logic         clk,                    // System clock
    input  logic         resetn,                 // Active-low reset
    output logic         mem_valid,              // Memory valid signal
    input  logic         mem_ready,              // Memory ready signal
    output logic [3:0]   mem_wstrb,              // Memory write strobe
    output logic [33:0]  mem_addr,               // Memory address bus
    output logic [31:0]  mem_wdata,              // Memory write data
    input  logic [31:0]  mem_rdata,              // Memory read data
    output logic [31:0]  PC,                     // Program counter output
    input  logic         access_fault,           // Memory access fault signal
    input  logic         IRQ3,                   // Interrupt request 3 (software)
    input  logic         IRQ7,                   // Interrupt request 7 (timer)
    input  logic         IRQ9,                   // Interrupt request 9 (external)
    input  logic         IRQ11,                  // Interrupt request 11 (external)
    output logic [63:0]  timer_counter,          // Timer counter
    output logic         is_instruction          // Instruction fetch flag
);

    // Internal Signals
    logic [31:0] Instr;                  // Instruction bus
    logic [6:0]  op;                     // Opcode field
    logic [2:0]  funct3;                 // Funct3 field
    logic [6:0]  funct7;                 // Funct7 field
    logic        Zero;                   // Zero flag from ALU
    logic [4:0]  Rs1, Rs2, Rd;           // Register fields
    logic        page_fault;             // Page fault signal

    // Control and Exception Signals
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
    logic        RegWrite, PCWrite, MemWrite, ALUOutWrite;
    logic        store_instr, incr_inst_retired;
    logic        CSRwe, CSRre;

    // AMO Signals
    logic amo_temp_write_operation;
    logic amo_set_reserved_state_load;
    logic amo_buffered_data;
    logic amo_buffered_address;
    logic amo_reserved_state_load;
    logic muxed_Aluout_or_amo_rd_wr;
    logic select_ALUResult, select_amo_temp;

    // Exception and Interrupt Signals
    logic exception_event;
    logic [31:0] cause, badaddr, mstatus;
    logic mret, sret, wfi_event, csr_access_fault;
    logic tlb_flush, tlb_flush_csr, selectPC;
    logic [31:0] satp;
    logic [1:0] privilege_mode;

    // MMU Signals
    logic [31:0] cpu_mem_addr, cpu_mem_wdata, cpu_mem_rdata;
    logic [3:0]  cpu_mem_wstrb;
    logic        cpu_mem_valid, cpu_mem_ready, stall;

    // Assign instruction decoding fields
    assign op     = Instr[6:0];
    assign funct3 = Instr[14:12];
    assign funct7 = Instr[31:25];
    assign Rs1    = Instr[19:15];
    assign Rs2    = Instr[24:20];
    assign Rd     = Instr[11:7];

    // Instantiate Control Unit
    control_unit control_unit_I (
        .clk(clk),
        .resetn(resetn),
        .op(op),
        .funct3(funct3),
        .funct7(funct7),
        .Rs1(Rs1),
        .Rs2(Rs2),
        .Rd(Rd),
        .Zero(Zero),
        .ResultSrc(ResultSrc),
        .ALUControl(ALUControl),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ImmSrc(ImmSrc),
        .STOREop(STOREop),
        .LOADop(LOADop),
        .CSRop(CSRop),
        .CSRwe(CSRwe),
        .CSRre(CSRre),
        .RegWrite(RegWrite),
        .PCWrite(PCWrite),
        .MemWrite(MemWrite),
        .store_instr(store_instr),
        .ALUOutWrite(ALUOutWrite),
        .selectPC(selectPC),
        .tlb_flush(tlb_flush)
    );

    // Instantiate Datapath Unit
    datapath_unit #(
        .RESET_ADDR(RESET_ADDR),
        .SYSTEM_CLK(SYSTEM_CLK)
    ) datapath_unit_I (
        .clk(clk),
        .resetn(resetn),
        .ResultSrc(ResultSrc),
        .ALUControl(ALUControl),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ImmSrc(ImmSrc),
        .STOREop(STOREop),
        .LOADop(LOADop),
        .CSRop(CSRop),
        .CSRwe(CSRwe),
        .CSRre(CSRre),
        .Instr(Instr),
        .Zero(Zero),
        .PC(PC),
        .timer_counter(timer_counter)
    );

    // Instantiate Memory Management Unit (MMU)
    sv32 #(
        .NUM_ENTRIES_ITLB(NUM_ENTRIES_ITLB),
        .NUM_ENTRIES_DTLB(NUM_ENTRIES_DTLB)
    ) mmu_I (
        .clk(clk),
        .resetn(resetn),
        .cpu_addr(cpu_mem_addr),
        .cpu_rdata(cpu_mem_rdata),
        .cpu_wdata(cpu_mem_wdata),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .stall(stall),
        .privilege_mode(privilege_mode),
        .page_fault(page_fault)
    );

endmodule

