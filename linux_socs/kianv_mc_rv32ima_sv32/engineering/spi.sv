//
// SPI Module - SystemVerilog Implementation
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
// SPI Module Description:
// This module provides an SPI interface with optional Quad-mode support and configurable clock polarity.
//
// Features:
// - Configurable SPI clock polarity (CPOL).
// - Supports single and quad SPI modes.
// - Full-duplex data transfer with configurable prescaler.
// - SPI Control and data register interface.
// - Tick-based clock divider for timing control.
//

`default_nettype none

module spi #(
    parameter QUAD_MODE = 1'b1,
    parameter CPOL = 1'b0
) (
    input  logic clk,
    input  logic resetn,

    input  logic ctrl,  // 0: CS control, 1: Data
    output logic [31:0] rdata,
    input  logic [31:0] wdata,
    input  logic [3:0] wstrb,
    input  logic [15:0] div,
    input  logic valid,
    output logic ready,

    output logic cen,
    output logic sclk,
    inout  logic sio1_so_miso,
    inout  logic sio0_si_mosi,
    inout  logic sio2,
    inout  logic sio3
);

    logic [5:0] xfer_cycles;
    logic [31:0] rx_data;
    logic [31:0] rx_data_next;
    logic spi_cen;
    logic spi_cen_nxt;

    logic [3:0] sio_oe;
    logic [3:0] sio_out;
    logic [3:0] sio_in;

    logic state, next_state;
    logic [7:0] spi_buf;
    logic is_quad;

    logic sclk_next;
    logic [3:0] sio_oe_next;
    logic [3:0] sio_out_next;
    logic [7:0] spi_buf_next;
    logic is_quad_next;
    logic [5:0] xfer_cycles_next;
    logic ready_xfer_next;
    logic ready_xfer;

    logic [3:0] sio;
    assign {sio3, sio2, sio1_so_miso, sio0_si_mosi} = sio;

    logic ready_ctrl;
    logic ready_ctrl_next;

    assign ready = ready_xfer || ready_ctrl;
    assign cen   = spi_cen;
    assign rdata = ctrl ? rx_data : {1'b0, 30'b0, spi_cen};

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : SIO_BIDIRECTION_CTRL
            assign sio[i] = sio_oe[i] ? sio_out[i] : 1'bz;
        end
    endgenerate

    assign sio_in = {sio3, sio2, sio1_so_miso, sio0_si_mosi};

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            spi_cen <= 1'b1;
            ready_ctrl <= 1'b0;
        end else begin
            spi_cen <= spi_cen_nxt;
            ready_ctrl <= ready_ctrl_next;
        end
    end

    always_comb begin
        ready_ctrl_next = 1'b0;
        spi_cen_nxt = spi_cen;
        if (!ctrl && valid) begin
            if (wstrb[0]) spi_cen_nxt = ~wdata[0];
            ready_ctrl_next = 1'b1;
        end
    end

    localparam S0_IDLE = 1'b0;
    localparam S1_WAIT_FOR_XFER_DONE = 1'b1;

    logic [17:0] tick_cnt;
    wire tick = tick_cnt == ({2'b0, div} - 1);

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sclk <= CPOL;
            sio_oe <= 4'b1111;
            sio_out <= 4'b0000;
            spi_buf <= 8'b0;
            is_quad <= 1'b0;
            xfer_cycles <= 6'b0;
            ready_xfer <= 1'b0;
            rx_data <= 32'b0;
            state <= S0_IDLE;
        end else begin
            state <= next_state;
            sclk <= sclk_next;
            sio_oe <= sio_oe_next;
            sio_out <= sio_out_next;
            spi_buf <= spi_buf_next;
            is_quad <= is_quad_next;
            xfer_cycles <= xfer_cycles_next;
            rx_data <= rx_data_next;
            ready_xfer <= ready_xfer_next;
        end
    end

    always_comb begin
        next_state = state;
        sclk_next = sclk;
        sio_oe_next = sio_oe;
        sio_out_next = sio_out;
        spi_buf_next = spi_buf;
        is_quad_next = is_quad;
        ready_xfer_next = ready_xfer;
        rx_data_next = rx_data;
        xfer_cycles_next = xfer_cycles;

        if (xfer_cycles > 0) begin
            if (tick || (div == 0)) begin
                sio_out_next = is_quad ? spi_buf[7:4] : {3'b0, spi_buf[7]};
                if (sclk) begin
                    sclk_next = 1'b0;
                end else begin
                    sclk_next = 1'b1;
                    spi_buf_next = is_quad ? {spi_buf[3:0], sio_in[3:0]} : {spi_buf[6:0], sio_in[1]};
                    xfer_cycles_next = is_quad ? xfer_cycles - 4 : xfer_cycles - 1;
                end
            end
        end else begin
            case (state)
                S0_IDLE: begin
                    if (valid && ctrl) begin
                        is_quad_next = QUAD_MODE;
                        if (wstrb[0]) begin
                            spi_buf_next = wdata[7:0];
                            sio_oe_next = QUAD_MODE ? 4'b1111 : 4'b0001;
                            xfer_cycles_next = 6'd8;  // Byte transfer
                        end
                        ready_xfer_next = 1'b1;
                        next_state = S1_WAIT_FOR_XFER_DONE;
                    end else begin
                        sclk_next = CPOL;
                        ready_xfer_next = 1'b0;
                    end
                end

                S1_WAIT_FOR_XFER_DONE: begin
                    rx_data_next = {24'b0, spi_buf};
                    next_state = S0_IDLE;
                end

                default: next_state = S0_IDLE;
            endcase
        end
    end

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn || tick || (xfer_cycles == 0)) begin
            tick_cnt <= 0;
        end else begin
            tick_cnt <= tick_cnt + 1;
        end
    end

endmodule
