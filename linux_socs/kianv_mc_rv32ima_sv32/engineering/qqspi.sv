//
// Copyright (c) 2022 Hirosh Dabui <hirosh@dabui.de>
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
// QQSPI Module - SystemVerilog Implementation
//
// This module implements a quad-SPI (Serial Peripheral Interface) controller
// with support for both PSRAM and SPI Flash devices. It supports read and write
// operations in both standard and quad modes.
//
// Features:
// - Configurable support for quad-SPI mode.
// - Read and write operations with configurable cycle lengths.
// - Handles byte and word-aligned writes with an `align_wdata` submodule.
// - Allows for PSRAM and SPI Flash-specific handling.
//
// Dependencies:
// - `align_wdata`: A helper module to manage write data alignment. It is
//    responsible for aligning write data (wdata) based on the 
//    write strobe (wstrb) signal. It calculates the appropriate byte offset, 
//    determines the number of write cycles, and adjusts the write buffer (wr_buffer)
//    for operations.
//
// Features:
// - Supports single-byte, half-word, and word-aligned writes.
// - Generates the number of write cycles required for the specified operation.
//
//
`default_nettype none

module qqspi #(
    parameter logic QUAD_MODE = 1'b1,
    parameter logic CEN_NPOL = 0,
    parameter logic PSRAM_SPIFLASH = 1'b1
) (
    input  logic [22:0] addr,  // 8Mx32
    output logic [31:0] rdata,
    input  logic [31:0] wdata,
    input  logic [3:0] wstrb,
    output logic ready,
    input  logic valid,
    input  logic clk,
    input  logic resetn,

    output logic cen,
    output logic sclk,
    inout  wire sio1_so_miso,
    inout  wire sio0_si_mosi,
    inout  wire sio2,
    inout  wire sio3,
    output logic [1:0] cs
);

    // Local parameters for commands
    localparam logic [7:0] CMD_QUAD_WRITE = 8'h38;
    localparam logic [7:0] CMD_FAST_READ_QUAD = 8'hEB;
    localparam logic [7:0] CMD_WRITE = 8'h02;
    localparam logic [7:0] CMD_READ = 8'h03;

    // Signal definitions
    logic [3:0] sio_oe;
    logic [3:0] sio_out;
    wire [3:0] sio_in;

    assign cen = ce ^ CEN_NPOL;

    logic write, read;
    assign write = |wstrb;
    assign read = ~write;

    logic [3:0] sio;
    assign {sio3, sio2, sio1_so_miso, sio0_si_mosi} = sio;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : SIO_BIDIRECTION_CTRL
            assign sio[i] = sio_oe[i] ? sio_out[i] : 1'bz;
        end
    endgenerate

    assign sio_in = {sio3, sio2, sio1_so_miso, sio0_si_mosi};

    // FSM States
    typedef enum logic [2:0] {
        S0_IDLE,
        S1_SELECT_DEVICE,
        S2_CMD,
        S4_ADDR,
        S5_WAIT,
        S6_XFER,
        S7_WAIT_FOR_XFER_DONE
    } state_t;
    state_t state, next_state;

    // Registers for control and data
    logic [31:0] spi_buf;
    logic [5:0] xfer_cycles;
    logic is_quad;
    logic ce;

    // Next state registers
    logic [31:0] rdata_next;
    logic [1:0] cs_next;
    logic ce_next;
    logic sclk_next;
    logic [3:0] sio_oe_next;
    logic [3:0] sio_out_next;
    logic [31:0] spi_buf_next;
    logic is_quad_next;
    logic [5:0] xfer_cycles_next;
    logic ready_next;

    wire [1:0] byte_offset;
    wire [5:0] wr_cycles;
    wire [31:0] wr_buffer;

    // Write data alignment
    align_wdata align_wdata_i (
        .wstrb      (wstrb),
        .wdata      (wdata),
        .byte_offset(byte_offset),
        .wr_cycles  (wr_cycles),
        .wr_buffer  (wr_buffer)
    );

    // Sequential block
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cs <= 2'b00;
            ce <= 1'b1;
            sclk <= 1'b1;
            sio_oe <= 4'b1111;
            sio_out <= 4'b0000;
            spi_buf <= 0;
            is_quad <= 0;
            xfer_cycles <= 0;
            ready <= 0;
            state <= S0_IDLE;
        end else begin
            state <= next_state;
            cs <= cs_next;
            ce <= ce_next;
            sclk <= sclk_next;
            sio_oe <= sio_oe_next;
            sio_out <= sio_out_next;
            spi_buf <= spi_buf_next;
            is_quad <= is_quad_next;
            xfer_cycles <= xfer_cycles_next;
            rdata <= rdata_next;
            ready <= ready_next;
        end
    end

    // Combinational logic
    always_comb begin
        // Default values
        next_state = state;
        cs_next = cs;
        ce_next = ce;
        sclk_next = sclk;
        sio_oe_next = sio_oe;
        sio_out_next = sio_out;
        spi_buf_next = spi_buf;
        is_quad_next = is_quad;
        xfer_cycles_next = xfer_cycles;
        ready_next = ready;
        sio_out_next = sio_out;
        rdata_next = rdata;

        if (|xfer_cycles) begin
            // Quad or single-bit transfers
            sio_out_next = is_quad ? spi_buf[31:28] : {3'b0, spi_buf[31]};
            if (sclk) begin
                sclk_next = 1'b0;
            end else begin
                sclk_next = 1'b1;
                spi_buf_next = is_quad ? {spi_buf[27:0], sio_in} : {spi_buf[30:0], sio_in[0]};
                xfer_cycles_next = is_quad ? xfer_cycles - 4 : xfer_cycles - 1;
            end
        end else begin
            case (state)
                S0_IDLE: begin
                    if (valid && !ready) begin
                        next_state = S1_SELECT_DEVICE;
                    end else if (!valid && ready) begin
                        ready_next = 1'b0;
                        ce_next = 1'b1;
                    end else begin
                        ce_next = 1'b1;
                    end
                end
                S1_SELECT_DEVICE: begin
                    sio_oe_next = 4'b0001;
                    cs_next = addr[22:21];
                    ce_next = 1'b0;
                    next_state = S2_CMD;
                end
                S2_CMD: begin
                    spi_buf_next[31:24] = QUAD_MODE ? (write ? CMD_QUAD_WRITE : CMD_FAST_READ_QUAD) : (write ? CMD_WRITE : CMD_READ);
                    xfer_cycles_next = 8;
                    is_quad_next = 0;
                    next_state = S4_ADDR;
                end
                S4_ADDR: begin
                    spi_buf_next[31:8] = {1'b0, addr[20:0], write ? byte_offset : 2'b00};
                    sio_oe_next = 4'b1111;
                    xfer_cycles_next = 24;
                    is_quad_next = QUAD_MODE;
                    next_state = QUAD_MODE && read ? S5_WAIT : S6_XFER;
                end
                S5_WAIT: begin
                    sio_oe_next = 4'b0000;
                    xfer_cycles_next = 6;
                    is_quad_next = 0;
                    next_state = S6_XFER;
                end
                S6_XFER: begin
                    is_quad_next = QUAD_MODE;
                    if (write) begin
                        sio_oe_next = 4'b1111;
                        spi_buf_next = wr_buffer;
                    end else begin
                        sio_oe_next = 4'b0000;
                    end
                    xfer_cycles_next = write ? wr_cycles : 32;
                    next_state = S7_WAIT_FOR_XFER_DONE;
                end
                S7_WAIT_FOR_XFER_DONE: begin
                    rdata_next = {spi_buf[7:0], spi_buf[15:8], spi_buf[23:16], spi_buf[31:24]};
                    ready_next = 1'b1;
                    next_state = S0_IDLE;
                end
                default: next_state = S0_IDLE;
            endcase
        end
    end

endmodule

module align_wdata (
    input  logic [ 3:0] wstrb,
    input  logic [31:0] wdata,
    output logic [ 1:0] byte_offset,
    output logic [ 5:0] wr_cycles,
    output logic [31:0] wr_buffer
);

    always_comb begin
        wr_buffer = wdata;  // Initialize write buffer with input data
        case (wstrb)
            4'b0001: begin
                byte_offset = 2'd3;
                wr_buffer[31:24] = wdata[7:0];
                wr_cycles = 6'd8;
            end
            4'b0010: begin
                byte_offset = 2'd2;
                wr_buffer[31:24] = wdata[15:8];
                wr_cycles = 6'd8;
            end
            4'b0100: begin
                byte_offset = 2'd1;
                wr_buffer[31:24] = wdata[23:16];
                wr_cycles = 6'd8;
            end
            4'b1000: begin
                byte_offset = 2'd0;
                wr_buffer[31:24] = wdata[31:24];
                wr_cycles = 6'd8;
            end
            4'b0011: begin
                byte_offset = 2'd2;
                wr_buffer[31:16] = wdata[15:0];
                wr_cycles = 6'd16;
            end
            4'b1100: begin
                byte_offset = 2'd0;
                wr_buffer[31:16] = wdata[31:16];
                wr_cycles = 6'd16;
            end
            4'b1111: begin
                byte_offset = 2'd0;
                wr_buffer[31:0] = wdata[31:0];
                wr_cycles = 6'd32;
            end
            default: begin
                byte_offset = 2'd0;
                wr_buffer = wdata;
                wr_cycles = 6'd32;
            end
        endcase
    end

endmodule
