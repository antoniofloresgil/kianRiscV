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
// PWM Module - SystemVerilog Implementation
//
// This module implements a Pulse Width Modulation (PWM) generator for the Harris multicycle RISC-V RV32IMA processor.
// It uses a FIFO to buffer pulse width values and generates a PWM output signal.
//
// Features:
// - Configurable FIFO depth for buffering PCM input data.
// - Supports 8-bit PCM input data to drive the PWM output.
// - Internal clock divider to manage the PWM signal generation rate.
// - Simple and efficient PWM accumulator-based implementation.
//

`default_nettype none
`include "defines_soc.svh"

module pwm #(
    parameter DEPTH = 8192
) (
    input  logic clk,
    input  logic resetn,
    input  logic we,
    input  logic [7:0] pcm_i,
    output logic pwm_o,
    output logic fifo_full
);

    logic fifo_empty;
    logic [7:0] fifo_out;

    fifo #(
        .DATA_WIDTH(8),
        .DEPTH     (DEPTH)
    ) fifo_i (
        .clk   (clk),
        .resetn(resetn),
        .din   (pcm_i),
        .dout  (fifo_out),
        .push  (we),
        .pop   (tick & ~fifo_empty),
        .full  (fifo_full),
        .empty (fifo_empty)
    );

    logic [17:0] tick_cnt;
    /* verilator lint_off WIDTHEXPAND */
    logic tick = (tick_cnt == (`SYSTEM_CLK / 8000) - 1);
    /* verilator lint_on WIDTHEXPAND */
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn || tick)
            tick_cnt <= 0;
        else
            tick_cnt <= tick_cnt + 1;
    end

    // PWM accumulator and output generation
    // https://www.fpga4fun.com/PWM_DAC_3.html
    logic [8:0] pwm_accumulator;
    logic [7:0] fifo_out_r;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn || fifo_empty)
            fifo_out_r <= 0;
        else
            fifo_out_r <= fifo_out;
    end

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            pwm_accumulator <= 0;
        else
            pwm_accumulator <= pwm_accumulator[7:0] + fifo_out_r;
    end

    assign pwm_o = pwm_accumulator[8];

endmodule
