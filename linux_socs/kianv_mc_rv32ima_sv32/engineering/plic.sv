//
// Copyright (c) 2024 Hirosh Dabui <hirosh@dabui.de>
// Port to SystemVerilog Copyright (c) 2024 Antonio Flores <aflores@um.es>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS.
//
// Platform-Level Interrupt Controller (PLIC) - SystemVerilog Implementation
//
// This module implements a Platform-Level Interrupt Controller (PLIC) for the Harris multicycle RISC-V RV32IMA processor.
// It manages interrupt requests and prioritization across multiple contexts such as machine and supervisor modes.
//
// Features:
// - Memory-mapped priority and enable registers for interrupts.
// - Handles interrupt claims and completion for two contexts (Machine and Supervisor modes).
// - Provides an interrupt pending bit array.
// - Supports priority-based interrupt selection via priority encoders.
//
`default_nettype none

module plic (
    input  logic       clk,
    input  logic       resetn,
    input  logic       valid,
    input  logic [23:0] addr,
    input  logic [3:0]  wmask,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    input  logic [31:1] interrupt_request,  // Interrupt source 0 is reserved
    output logic        is_valid,
    output logic        ready,
    output logic        interrupt_request_ctx0,  // Machine mode interrupt request
    output logic        interrupt_request_ctx1   // Supervisor mode interrupt request
);

    logic we;
    assign we = |wmask;

    // Address decoding
    logic is_pending_0_31;
    logic is_enable_ctx0_0_31;
    logic is_enable_ctx1_0_31;
    logic is_claim_complete_ctx0;
    logic is_claim_complete_ctx1;

    assign is_pending_0_31         = (addr == 24'h001000);
    assign is_enable_ctx0_0_31     = (addr == 24'h002000);
    assign is_enable_ctx1_0_31     = (addr == 24'h002080);
    assign is_claim_complete_ctx0  = (addr == 24'h200004);
    assign is_claim_complete_ctx1  = (addr == 24'h201004);

    // Ready signal logic
    assign is_valid = !ready && valid;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            ready <= 1'b0;
        else
            ready <= is_valid;
    end

    // Context 0 enable register
    logic [31:0] enable_ctx0_0_31;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            enable_ctx0_0_31 <= 32'b0;
        else if (valid && is_enable_ctx0_0_31) begin
            foreach (wmask[i])
                if (wmask[i])
                    enable_ctx0_0_31[i*8+:8] <= wdata[i*8+:8];
        end
    end

    // Context 1 enable register
    logic [31:0] enable_ctx1_0_31;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            enable_ctx1_0_31 <= 32'b0;
        else if (valid && is_enable_ctx1_0_31) begin
            foreach (wmask[i])
                if (wmask[i])
                    enable_ctx1_0_31[i*8+:8] <= wdata[i*8+:8];
        end
    end

    // Pending interrupt registers for context 0
    logic [31:0] pending_ctx0;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            pending_ctx0 <= 32'b0;
        else if (is_claim_complete_ctx0 && we && valid)
            pending_ctx0 <= pending_ctx0 & ~(1 << wdata[7:0]);
        else
            pending_ctx0 <= pending_ctx0 | ({interrupt_request, 1'b0} & enable_ctx0_0_31);
    end

    // Pending interrupt registers for context 1
    logic [31:0] pending_ctx1;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            pending_ctx1 <= 32'b0;
        else if (is_claim_complete_ctx1 && we && valid)
            pending_ctx1 <= pending_ctx1 & ~(1 << wdata[7:0]);
        else
            pending_ctx1 <= pending_ctx1 | ({interrupt_request, 1'b0} & enable_ctx1_0_31);
    end

    // Claim logic for context 0
    logic [31:0] claim_ctx0;
    Priority_Encoder #(
        .WORD_WIDTH(32)
    ) priority_encoder_ctx0 (
        .word_in(pending_ctx0 & -pending_ctx0),
        .word_out(claim_ctx0),
        .word_out_valid()
    );

    // Claim logic for context 1
    logic [31:0] claim_ctx1;
    Priority_Encoder #(
        .WORD_WIDTH(32)
    ) priority_encoder_ctx1 (
        .word_in(pending_ctx1 & -pending_ctx1),
        .word_out(claim_ctx1),
        .word_out_valid()
    );

    // Read logic
    always_comb begin
        case (1'b1)
            is_pending_0_31:         rdata = pending_ctx0 | pending_ctx1;
            is_enable_ctx0_0_31:     rdata = enable_ctx0_0_31;
            is_enable_ctx1_0_31:     rdata = enable_ctx1_0_31;
            is_claim_complete_ctx0:  rdata = claim_ctx0;
            is_claim_complete_ctx1:  rdata = claim_ctx1;
            default:                 rdata = 32'b0;
        endcase
    end

    // Interrupt request outputs
    assign interrupt_request_ctx0 = |pending_ctx0;
    assign interrupt_request_ctx1 = |pending_ctx1;

endmodule
