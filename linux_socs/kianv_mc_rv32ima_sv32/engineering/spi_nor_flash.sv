//
// SPI NOR Flash Module - SystemVerilog Implementation
//
// Copyright (c) 2021 Hirosh Dabui <hirosh@dabui.de>
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
// SPI NOR Flash Module Description:
// This module provides an interface for accessing SPI NOR flash memory,
// allowing read operations using the 0x03 Read Command.
//
// Features:
// - Supports 4M-word addressable space.
// - Outputs 32-bit word-aligned data.
// - Implements SPI communication using a prescaler for clock division.
// - Handles SPI data shifts and manages the CS and clock signals.
//
// Notes:
// - The `SPI_NOR_PRESCALER_DIVIDER` parameter controls the SPI clock frequency.
//

`default_nettype none
`timescale 1ns / 1ps
`define SPI_NOR_PRESCALER_DIVIDER 7

module spi_nor_flash (
    input  logic clk,
    input  logic resetn,

    input  logic [21:0] addr,   // 4MWords
    output logic [31:0] data,
    output logic        ready,
    input  logic        valid,

    // External SPI signals
    output logic        spi_cs,
    input  logic        spi_miso,
    output logic        spi_mosi,
    output logic        spi_sclk
);

    logic [31:0] shift_reg;
    assign spi_mosi = shift_reg[31];
    logic clk_latch;
    logic [2:0] div_clk;

    assign spi_sclk = clk_latch && !spi_cs;

    logic [31:0] rcv_buff;
    logic done;
    assign data  = rcv_buff;

    assign ready = done && clk_latch && &div_clk;

    logic spi_miso_;
    assign spi_miso_ = spi_miso;

    logic [2:0] state;
    logic [4:0] shift_cnt;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rcv_buff  <= 32'b0;
            state     <= 3'd0;
            shift_reg <= 32'b0;
            spi_cs    <= 1'b1;
            clk_latch <= 1'b0;
            div_clk   <= 3'b0;
            done      <= 1'b0;
        end else begin
            div_clk <= div_clk + 1'b1;

            if (div_clk == `SPI_NOR_PRESCALER_DIVIDER) begin
                div_clk   <= 3'b0;
                clk_latch <= ~clk_latch;

                if (clk_latch) begin
                    case (state)

                        3'd0: begin
                            done   <= 1'b0;
                            spi_cs <= 1'b1;

                            if (valid && !ready) begin
                                shift_cnt <= 5'd31;
                                shift_reg <= {8'h03, addr[21:0], 2'b00};  // Read 0x03 command
                                spi_cs    <= 1'b0;
                                state     <= 3'd1;
                            end
                        end

                        3'd1: begin
                            shift_cnt <= shift_cnt - 1'b1;
                            shift_reg <= {shift_reg[30:0], 1'b0};

                            if (!(|shift_cnt)) begin
                                shift_cnt <= 5'd7;
                                state     <= 3'd2;
                            end
                        end

                        3'd2: begin
                            shift_cnt     <= shift_cnt - 1'b1;
                            rcv_buff[7:0] <= {rcv_buff[6:0], spi_miso_};

                            if (!(|shift_cnt)) begin
                                shift_cnt <= 5'd7;
                                state     <= 3'd3;
                            end
                        end

                        3'd3: begin
                            shift_cnt      <= shift_cnt - 1'b1;
                            rcv_buff[15:8] <= {rcv_buff[14:8], spi_miso_};

                            if (!(|shift_cnt)) begin
                                shift_cnt <= 5'd7;
                                state     <= 3'd4;
                            end
                        end

                        3'd4: begin
                            shift_cnt       <= shift_cnt - 1'b1;
                            rcv_buff[23:16] <= {rcv_buff[22:16], spi_miso_};

                            if (!(|shift_cnt)) begin
                                shift_cnt <= 5'd7;
                                state     <= 3'd5;
                            end
                        end

                        3'd5: begin
                            shift_cnt       <= shift_cnt - 1'b1;
                            rcv_buff[31:24] <= {rcv_buff[30:24], spi_miso_};

                            if (!(|shift_cnt)) begin
                                done  <= 1'b1;
                                state <= 3'd0;
                            end
                        end

                        default: state <= 3'd0;

                    endcase
                end
            end
        end
    end

endmodule
