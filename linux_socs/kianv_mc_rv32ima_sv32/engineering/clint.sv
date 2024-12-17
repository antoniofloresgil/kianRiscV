//
// Copyright (c) 2023 Hirosh Dabui <hirosh@dabui.de>
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
// CLINT Module - SystemVerilog Implementation
//
// This module implements the Core Local Interruptor (CLINT) for the RISC-V RV32IMA processor.
// It supports timer interrupts and software interrupts.
//
// Features:
// - Handles Machine Timer Interrupts (IRQ7) and Machine Software Interrupts (IRQ3).
// - Supports reading and writing to timer compare registers and software interrupt registers.
//

`default_nettype none

module clint (
    input  logic        clk,               // Clock signal
    input  logic        resetn,            // Asynchronous active-low reset
    input  logic        valid,             // Valid signal
    input  logic [23:0] addr,              // Address input
    input  logic [3:0]  wmask,             // Write mask
    input  logic [31:0] wdata,             // Write data
    input  logic [15:0] div,               // Divider input (unused)
    output logic [31:0] rdata,             // Read data output
    output logic        is_valid,          // Validity signal for accesses
    output logic        ready,             // Ready signal
    output logic        IRQ3,              // Software interrupt (MSIP)
    output logic        IRQ7,              // Timer interrupt (MTIME >= MTIMECMP)
    input  logic [63:0] timer_counter      // Timer counter input
);

    // Address decoding
    logic is_msip, is_mtimecmpl, is_mtimecmph, is_mtimel, is_mtimeh;
    assign is_msip       = (addr == 24'h00_0000);
    assign is_mtimecmpl  = (addr == 24'h00_4000);
    assign is_mtimecmph  = (addr == 24'h00_4004);
    assign is_mtimel     = (addr == 24'h00_bff8);
    assign is_mtimeh     = (addr == 24'h00_bffc);

    assign is_valid      = valid && (is_msip || is_mtimecmpl || is_mtimecmph || is_mtimel || is_mtimeh);

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            ready <= 1'b0;
        else
            ready <= is_valid;
    end

    // Timer and compare logic
    logic [63:0] mtimecmp;
    logic        msip;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            mtimecmp <= 64'b0;
            msip     <= 1'b0;
        end else if (is_valid) begin
            if (is_mtimecmpl) begin
                if (wmask[0]) mtimecmp[7:0]   <= wdata[7:0];
                if (wmask[1]) mtimecmp[15:8]  <= wdata[15:8];
                if (wmask[2]) mtimecmp[23:16] <= wdata[23:16];
                if (wmask[3]) mtimecmp[31:24] <= wdata[31:24];
            end else if (is_mtimecmph) begin
                if (wmask[0]) mtimecmp[39:32] <= wdata[7:0];
                if (wmask[1]) mtimecmp[47:40] <= wdata[15:8];
                if (wmask[2]) mtimecmp[55:48] <= wdata[23:16];
                if (wmask[3]) mtimecmp[63:56] <= wdata[31:24];
            end else if (is_msip) begin
                if (wmask[0]) msip <= wdata[0];
            end
        end
    end

    // Read logic
    always_comb begin
        case (1'b1)
            is_mtimecmpl: rdata = mtimecmp[31:0];
            is_mtimecmph: rdata = mtimecmp[63:32];
            is_mtimel:    rdata = timer_counter[31:0];
            is_mtimeh:    rdata = timer_counter[63:32];
            is_msip:      rdata = {31'b0, msip};
            default:      rdata = 32'b0;
        endcase
    end

    // Interrupt signals
    assign IRQ3 = msip;
    assign IRQ7 = (timer_counter >= mtimecmp);

endmodule
