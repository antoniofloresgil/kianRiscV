
//
// Copyright (c) 2023/2024 Hirosh Dabui <hirosh@dabui.de>
// Port to SystemVerilog Copyright (c) 2024 Antonio Flores <aflores@um.es>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS.
//
// RISC-V SV32 Virtual to Physical Address Translation - SystemVerilog Implementation
//
// This module translates virtual addresses to physical addresses using the SV32 page table format.
// It supports instruction and data address translation, TLB entries, and page fault detection.
//
// Features:
// - Handles translation for both instructions and data addresses.
// - Integrates a table walk mechanism for SV32 page tables.
// - Includes page fault detection and privilege mode checks.
//

`default_nettype none
`include "riscv_defines.svh"

module sv32 #(
    parameter NUM_ENTRIES_ITLB = 64,
    parameter NUM_ENTRIES_DTLB = 64
)(
    input  logic        clk,
    input  logic        resetn,

    // CPU Interface
    input  logic        cpu_valid,
    output logic        cpu_ready,
    input  logic [ 3:0] cpu_wstrb,
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_wdata,
    output logic [31:0] cpu_rdata,

    // Memory Interface
    output logic        mem_valid,
    input  logic        mem_ready,
    output logic [ 3:0] mem_wstrb,
    output logic [33:0] mem_addr,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,

    // MMU Control Signals
    input  logic        is_instruction,
    input  logic        tlb_flush,
    output logic        stall,

    // Privilege and MMU Configuration
    input  logic [31:0] satp,
    input  logic [31:0] mstatus,
    input  logic [ 1:0] privilege_mode,

    // Fault Handling
    output logic [31:0] fault_address,
    output logic        page_fault
);

    // State Machine Definition
    typedef enum logic [1:0] {
        S0, S1, S2
    } state_t;

    state_t state, next_state;

    // Internal Signals
    logic [33:0] physical_instruction_address, physical_data_address;
    logic        translate_instr_valid, translate_instr_ready;
    logic        translate_data_valid, translate_data_ready;

    logic        page_fault_instruction, page_fault_data;
    logic        walk_mem_valid, walk_mem_ready;
    logic [31:0] walk_mem_addr, walk_mem_rdata;

    logic        walk_valid, walk_ready;
    logic        trans_instr_to_phy_walk_valid, trans_instr_to_phy_walk_ready;
    logic        trans_data_to_phy_walk_valid, trans_data_to_phy_walk_ready;

    logic [31:0] pte;
    logic        mmu_enable;
    logic        translation_complete;

    assign mmu_enable = `GET_SATP_MODE(satp);
    assign translation_complete = translate_instr_ready || translate_data_ready;

    // State Register
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            state <= S0;
        else
            state <= next_state;
    end

    // State Transition Logic
    always_comb begin
        next_state = state;
        case (state)
            S0: if (cpu_valid && mmu_enable) next_state = S1;
            S1: if (translation_complete || page_fault) next_state = S2;
            S2: if (mem_ready) next_state = S0;
        endcase
    end

    // CPU and Memory Interface Control
    always_comb begin
        // Default values
        stall            = 1'b0;
        mem_valid        = 1'b0;
        cpu_ready        = mem_ready;
        mem_wstrb        = 4'b0;
        mem_wdata        = 32'b0;
        mem_addr         = 34'b0;
        cpu_rdata        = 32'b0;
        walk_mem_rdata   = mem_rdata;
        walk_mem_ready   = mem_ready;

        translate_instr_valid = 1'b0;
        translate_data_valid  = 1'b0;

        case (state)
            S0: begin
                if (cpu_valid && mmu_enable) begin
                    translate_instr_valid = is_instruction;
                    translate_data_valid  = !is_instruction;
                    cpu_ready             = 1'b0;
                end else begin
                    mem_valid = cpu_valid;
                    mem_addr  = {2'b00, cpu_addr};
                    mem_wstrb = cpu_wstrb;
                    mem_wdata = cpu_wdata;
                    cpu_rdata = mem_rdata;
                end
            end
            S1: begin
                stall = 1'b1;
                mem_addr  = {2'b00, walk_mem_addr};
                mem_valid = walk_mem_valid;
            end
            S2: begin
                mem_valid = cpu_valid;
                mem_addr  = is_instruction ? physical_instruction_address : physical_data_address;
                mem_wstrb = cpu_wstrb;
                mem_wdata = cpu_wdata;
                cpu_rdata = mem_rdata;
            end
        endcase
    end

    // Fault Detection Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            page_fault    <= 1'b0;
            fault_address <= 32'b0;
        end else if (page_fault_instruction || page_fault_data) begin
            page_fault    <= 1'b1;
            fault_address <= cpu_addr;
        end else begin
            page_fault <= 1'b0;
        end
    end

    // Table Walk Instantiation
    sv32_table_walk #(
        .NUM_ENTRIES_ITLB(NUM_ENTRIES_ITLB),
        .NUM_ENTRIES_DTLB(NUM_ENTRIES_DTLB)
    ) table_walk_inst (
        .clk             (clk),
        .resetn          (resetn),
        .address         (cpu_addr),
        .satp            (satp),
        .pte             (pte),
        .is_instruction  (is_instruction),
        .tlb_flush       (tlb_flush),
        .valid           (walk_valid),
        .ready           (walk_ready),
        .walk_mem_valid  (walk_mem_valid),
        .walk_mem_ready  (walk_mem_ready),
        .walk_mem_addr   (walk_mem_addr),
        .walk_mem_rdata  (walk_mem_rdata)
    );

    sv32_translate_instruction_to_physical instr_translate_inst (
        .clk             (clk),
        .resetn          (resetn),
        .address         (cpu_addr),
        .physical_address(physical_instruction_address),
        .page_fault      (page_fault_instruction),
        .privilege_mode  (privilege_mode),
        .satp            (satp),
        .valid           (translate_instr_valid),
        .ready           (translate_instr_ready),
        .walk_valid      (trans_instr_to_phy_walk_valid),
        .walk_ready      (trans_instr_to_phy_walk_ready),
        .pte             (pte)
    );

    sv32_translate_data_to_physical data_translate_inst (
        .clk             (clk),
        .resetn          (resetn),
        .address         (cpu_addr),
        .physical_address(physical_data_address),
        .is_write        (|cpu_wstrb),
        .page_fault      (page_fault_data),
        .privilege_mode  (privilege_mode),
        .satp            (satp),
        .mstatus         (mstatus),
        .valid           (translate_data_valid),
        .ready           (translate_data_ready),
        .walk_valid      (trans_data_to_phy_walk_valid),
        .walk_ready      (trans_data_to_phy_walk_ready),
        .pte_            (pte)
    );

endmodule

