
//  kianv harris multicycle RISC-V rv32imo
//
//  copyright (c) 2023/2024 hirosh dabui <hirosh@dabui.de>
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
// RISC-V Datapath Unit Module - SystemVerilog Implementation
//
// This module implements the datapath unit for the RISC-V RV32IMO multicycle processor. 
// The datapath unit handles instruction execution, data transfers, and arithmetic 
// operations, interfacing with multiple functional units such as the ALU, CSR handler, 
// and memory subsystem. The datapath unit is responsible for executing instructions,
// managing control signals, and interfacing with:
//    - ALU for arithmetic and logic operations,
//    - Register File for register read/write operations,
//    - Memory for load/store operations,
//    - CSR (Control and Status Registers) for privileged instructions and
//      exception handling.
//
//  Key Features:
//    - Supports RV32I, RV32M (Multiplication/Division), and CSR instructions.
//    - Implements exception and interrupt handling using a CSR handler module.
//    - Supports AMO (Atomic Memory Operations) for load-reserved/store-conditional instructions.
//    - Extensible control flow and data muxing for ALU inputs, outputs, and program counters.
//    - Includes multipliers, dividers, and alignment logic for load/store operations.
//    - Interfaces with the exception handler for fault handling and privilege level management.
//
//
`default_nettype none

`include "riscv_defines.vh"

module datapath_unit #(
    parameter RESET_ADDR = 0,
    parameter SYSTEM_CLK = 50_000_000
) (
    input  logic clk,
    input  logic resetn,

    input  logic [`RESULT_WIDTH   -1:0] ResultSrc,
    input  logic [`ALU_CTRL_WIDTH -1:0] ALUControl,
    input  logic [`SRCA_WIDTH     -1:0] ALUSrcA,
    input  logic [`SRCB_WIDTH     -1:0] ALUSrcB,
    input  logic [                 2:0] ImmSrc,
    input  logic [`STORE_OP_WIDTH -1:0] STOREop,
    input  logic [`LOAD_OP_WIDTH  -1:0] LOADop,
    input  logic [`MUL_OP_WIDTH   -1:0] MULop,
    input  logic [`DIV_OP_WIDTH   -1:0] DIVop,
    input  logic [`CSR_OP_WIDTH   -1:0] CSRop,
    input  logic                        CSRwe,
    input  logic                        CSRre,
    output logic                        Zero,
    output logic                        immb10,

    input  logic RegWrite,
    input  logic PCWrite,
    input  logic AdrSrc,
    input  logic MemWrite,
    input  logic incr_inst_retired,
    input  logic store_instr,
    input  logic ALUOutWrite,

    // AMO
    input  logic amo_temp_write_operation,
    input  logic amo_set_reserved_state_load,
    input  logic amo_buffered_data,
    input  logic amo_buffered_address,
    output logic amo_reserved_state_load,
    input  logic muxed_Aluout_or_amo_rd_wr,
    input  logic select_ALUResult,
    input  logic select_amo_temp,

    // 32-bit instruction input
    output logic [31:0] Instr,

    output logic [ 3:0] mem_wstrb,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    input  logic        mul_valid,
    output logic        mul_ready,
    input  logic        div_valid,
    output logic        div_ready,
    output logic [31:0] ProgCounter,

    // Exception Handler
    input  logic        exception_event,
    input  logic [31:0] cause,
    input  logic [31:0] badaddr,
    input  logic        mret,
    input  logic        sret,
    input  logic        wfi_event,
    output logic        csr_access_fault,
    output logic [ 1:0] privilege_mode,
    output logic [31:0] satp,
    output logic        tlb_flush,
    output logic [31:0] mstatus,
    output logic [63:0] timer_counter,
    input  logic        page_fault,
    input  logic        selectPC,

    input  logic IRQ3,
    input  logic IRQ7,
    input  logic IRQ9,
    input  logic IRQ11,

    output logic IRQ_TO_CPU_CTRL1,
    output logic IRQ_TO_CPU_CTRL3,
    output logic IRQ_TO_CPU_CTRL5,
    output logic IRQ_TO_CPU_CTRL7,
    output logic IRQ_TO_CPU_CTRL9,
    output logic IRQ_TO_CPU_CTRL11
);

    // Internal Wires
    logic [31:0] Rd1;
    logic [31:0] Rd2;

    logic [ 4:0] Rs1 = Instr[19:15];
    logic [ 4:0] Rs2 = Instr[24:20];
    logic [ 4:0] Rd  = Instr[11:7];

    logic [31:0] WD3;

    // Register File Instance
    register_file register_file_I (
        .clk(clk),
        .we (RegWrite),
        .A1 (Rs1),
        .A2 (Rs2),
        .A3 (Rd),
        .rd1(Rd1),
        .rd2(Rd2),
        .wd (WD3)
    );

    // Wires for Data Path
    logic [31:0] ImmExt;
    logic [31:0] PC, OldPC;
    logic [31:0] PCNext;
    logic [31:0] A1, A2;
    logic [31:0] SrcA, SrcB;
    logic [31:0] ALUResult;
    logic [31:0] MULResult;
    logic [31:0] DIVResult;
    logic [31:0] MULExtResult;
    logic [31:0] MULExtResultOut;
    logic [31:0] ALUOut;
    logic [31:0] Result;
    logic [ 3:0] wmask;
    logic [31:0] Data;
    logic [31:0] DataLatched;
    logic [31:0] CSRData;
    logic [ 1:0] mem_addr_align_latch;
    logic [31:0] CSRDataOut;
    logic        div_by_zero_err;

    assign immb10      = ImmExt[10];
    assign ProgCounter = OldPC;
    assign mem_wstrb   = wmask & {4{MemWrite}};

    assign WD3         = Result;
    assign PCNext      = Result;

    // AMO Signals
    logic [31:0] amo_temporary_data;
    logic [31:0] alu_out_or_amo_scw;
    logic [31:0] DataLatched_or_AMOtempData;
    logic [31:0] muxed_A2_data;
    logic [31:0] muxed_Data_ALUResult;

    // CSR Exception Handler Signals
    logic [11:0] CSRAddr;
    assign CSRAddr = ImmExt[11:0];

    logic [31:0] exception_next_pc;

    // Address Mux
    mux2 #(
        .WIDTH(32)
    ) Addr_I (
        .a    (PC),
        .b    (Result),
        .sel  (AdrSrc),
        .y    (mem_addr)
    );

    // Data Latched or AMO Temporary Data Mux
    mux2 #(
        .WIDTH(32)
    ) DataLatched_or_AMOtempData_i (
        .a    (DataLatched),
        .b    (amo_temporary_data),
        .sel  (select_amo_temp),
        .y    (DataLatched_or_AMOtempData)
    );

    // Result Mux
    mux6 #(
        .WIDTH(32)
    ) Result_I (
        .a    (alu_out_or_amo_scw),
        .b    (DataLatched_or_AMOtempData),
        .c    (ALUResult),
        .d    (MULExtResultOut),
        .e    (CSRDataOut),
        .f    (amo_buffer_addr_value),
        .sel  (ResultSrc),
        .y    (Result)
    );

    // PC or Exception Next PC Mux
    logic [31:0] pc_or_exception_next;
    logic exception_select;
    mux2 #(
        .WIDTH(32)
    ) pc_next_or_exception_mux_I (
        .a    (PCNext),
        .b    (exception_next_pc),
        .sel  (exception_select),
        .y    (pc_or_exception_next)
    );

    // Program Counter Register
    dff_kianV #(
        .WIDTH(32),
        .RESET_VALUE(RESET_ADDR)
    ) PC_I (
        .resetn(resetn),
        .clk(clk),
        .en(PCWrite),
        .d(pc_or_exception_next),
        .q(PC)
    );

    // Instruction Register
    dff_kianV #(
        .WIDTH(32),
        .RESET_VALUE(`NOP_INSTR)
    ) Instr_I (
        .resetn(resetn),
        .clk(clk),
        .en(store_instr),
        .d(mem_rdata),
        .q(Instr)
    );

    // AMO Buffered Address Register
    dff_kianV #(
        .WIDTH(32)
    ) amo_buffered_addr_I (
        .resetn(resetn),
        .clk(clk),
        .d(ALUResult),
        .en(amo_buffered_address),
        .q(amo_buffer_addr_value)
    );

    // AMO Reserved State Load Register
    dff_kianV #(
        .WIDTH(1)
    ) amo_reserved_state_load_I (
        .resetn(resetn),
        .clk(clk),
        .d(amo_buffered_data),
        .en(amo_set_reserved_state_load),
        .q(amo_reserved_state_load)
    );

    // Old PC Register
    dff_kianV #(
        .WIDTH(32),
        .RESET_VALUE(RESET_ADDR)
    ) OldPC_I (
        .resetn(resetn),
        .clk(clk),
        .en(store_instr),
        .d(PC),
        .q(OldPC)
    );

    // ALU Output Register
    dff_kianV #(
        .WIDTH(32)
    ) ALUOut_I (
        .resetn(resetn),
        .clk(clk),
        .en(ALUOutWrite),
        .d(ALUResult),
        .q(ALUOut)
    );

    // ALU Output or AMO SCW Mux
    mux2 #(
        .WIDTH(32)
    ) Aluout_or_atomic_scw_I (
        .a    (ALUOut),
        .b    ({31'd0, amo_buffered_data}),
        .sel  (muxed_Aluout_or_amo_rd_wr),
        .y    (alu_out_or_amo_scw)
    );

    // Memory Address Alignment Latch
    dlatch_kianV #(
        .WIDTH(2)
    ) ADDR_I (
        .clk(clk),
        .d(mem_addr[1:0]),
        .q(mem_addr_align_latch)
    );

    // Register A1 Latch
    dlatch_kianV #(
        .WIDTH(32)
    ) A1_I (
        .clk(clk),
        .d(Rd1),
        .q(A1)
    );

    // Register A2 Latch
    dlatch_kianV #(
        .WIDTH(32)
    ) A2_I (
        .clk(clk),
        .d(Rd2),
        .q(A2)
    );

    // Data Latch
    dlatch_kianV #(
        .WIDTH(32)
    ) Data_I (
        .clk(clk),
        .d(Data),
        .q(DataLatched)
    );

    // CSR Data Output Latch
    dlatch_kianV #(
        .WIDTH(32)
    ) CSROut_I (
        .clk(clk),
        .d(CSRData),
        .q(CSRDataOut)
    );

    // MUL Extended Result Output Latch
    dlatch_kianV #(
        .WIDTH(32)
    ) MULExtResultOut_I (
        .clk(clk),
        .d(MULExtResult),
        .q(MULExtResultOut)
    );

    // Immediate Extension
    extend extend_I (
        .instr    (Instr[31:7]),
        .imm_src  (ImmSrc),
        .imm_ext  (ImmExt)
    );

    // AMO Temporary Data Mux
    mux2 #(
        .WIDTH(32)
    ) muxed_A2_data_I (
        .a    (A2),
        .b    (amo_temporary_data),
        .sel  (select_amo_temp),
        .y    (muxed_A2_data)
    );

    // Store Alignment
    store_alignment store_alignment_I (
        .addr       (mem_addr[1:0]),
        .store_op   (STOREop),
        .data_in    (muxed_A2_data),
        .data_out   (mem_wdata),
        .wmask      (wmask)
    );

    // Load Alignment
    load_alignment load_alignment_I (
        .addr_align (mem_addr_align_latch),
        .load_op    (LOADop),
        .data_in    (mem_rdata),
        .data_out   (Data)
    );

    // Data or ALU Result Mux
    mux2 #(
        .WIDTH(32)
    ) muxed_Data_ALUResult_I (
        .a    (Data),
        .b    (ALUResult),
        .sel  (select_ALUResult),
        .y    (muxed_Data_ALUResult)
    );

    // AMO Temporary Data Register
    dff_kianV #(
        .WIDTH(32)
    ) AMOTmpData_I (
        .resetn(resetn),
        .clk(clk),
        .en(amo_temp_write_operation),
        .d(muxed_Data_ALUResult),
        .q(amo_temporary_data)
    );

    // Source A Mux
    mux5 #(
        .WIDTH(32)
    ) SrcA_I (
        .a    (PC),
        .b    (OldPC),
        .c    (A1),            // Rd1
        .d    (amo_temporary_data),
        .e    (32'd0),
        .sel  (ALUSrcA),
        .y    (SrcA)
    );

    // Source B Mux
    mux4 #(
        .WIDTH(32)
    ) SrcB_I (
        .a    (A2),            // Rd2
        .b    (ImmExt),
        .c    (32'd4),
        .d    (32'd0),
        .sel  (ALUSrcB),
        .y    (SrcB)
    );

    // ALU Instance
    alu alu_I (
        .a         (SrcA),
        .b         (SrcB),
        .control   (ALUControl),
        .result    (ALUResult),
        .zero      (Zero)
    );

    // MUL or DIV Extended Result Mux
    mux2 #(
        .WIDTH(32)
    ) mul_ext_I (
        .a    (MULResult),
        .b    (DIVResult),
        .sel  (~mul_valid),
        .y    (MULExtResult)
    );

    // Multiplier Instance
    multiplier mul_I (
        .clk(clk),
        .resetn(resetn),
        .a    (SrcA),
        .b    (SrcB),
        .op   (MULop),
        .result(MULResult),
        .valid(mul_valid),
        .ready(mul_ready)
    );

    // Divider Instance
    divider div_I (
        .clk(clk),
        .resetn(resetn),
        .a       (SrcA),
        .b       (SrcB),
        .op      (DIVop),
        .result  (DIVResult),
        .valid   (div_valid),
        .ready   (div_ready),
        .div_by_zero_err(div_by_zero_err)  // todo:
    );

    // PC on Exception Mux
    logic [31:0] pc_on_exception;
    mux2 #(
        .WIDTH(32)
    ) mux_select_pc_on_exception_I (
        .a    (OldPC),
        .b    (PC),
        .sel  (selectPC),
        .y    (pc_on_exception)
    );

    // CSR Exception Handler Instance
    csr_exception_handler #(
        .SYSTEM_CLK(SYSTEM_CLK)
    ) csr_exception_handler_I (
        .clk              (clk),
        .resetn           (resetn),
        .incr_inst_retired(incr_inst_retired),
        .CSRAddr          (CSRAddr),
        .CSRop            (CSRop),
        .Rd1              (SrcA),
        .uimm             (Rs1),
        .we               (CSRwe),
        .re               (CSRre),
        .exception_event  (exception_event),
        .mret             (mret),
        .sret             (sret),
        .wfi_event        (wfi_event),
        .cause            (cause),
        .pc               (pc_on_exception),
        .badaddr          (badaddr),

        .privilege_mode   (privilege_mode),
        .rdata            (CSRData),
        .exception_next_pc(exception_next_pc),
        .exception_select (exception_select),
        .csr_access_fault (csr_access_fault),
        .satp             (satp),
        .tlb_flush        (tlb_flush),
        .mstatus          (mstatus),
        .timer_counter    (timer_counter),
        .IRQ3             (IRQ3),
        .IRQ7             (IRQ7),
        .IRQ9             (IRQ9),
        .IRQ11            (IRQ11),
        .IRQ_TO_CPU_CTRL1 (IRQ_TO_CPU_CTRL1),   // SSIP
        .IRQ_TO_CPU_CTRL3 (IRQ_TO_CPU_CTRL3),   // MSIP
        .IRQ_TO_CPU_CTRL5 (IRQ_TO_CPU_CTRL5),   // STIP
        .IRQ_TO_CPU_CTRL7 (IRQ_TO_CPU_CTRL7),   // MTIP
        .IRQ_TO_CPU_CTRL9 (IRQ_TO_CPU_CTRL9),   // SEIP
        .IRQ_TO_CPU_CTRL11(IRQ_TO_CPU_CTRL11)   // MEIP
    );

endmodule

