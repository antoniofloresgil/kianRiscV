//
// RX UART Module - SystemVerilog Implementation
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
// RX UART Module Description:
// This module implements a simple UART receiver with configurable baud rate
// using a divider (`div`) input. It includes an 8-bit FIFO buffer for data
// storage, synchronization of the RX input, and error handling.
//
// Features:
// - Synchronizes the RX input signal.
// - Samples incoming data bits and checks for start and stop bits.
// - Provides a FIFO buffer for received data.
// - Indicates errors for invalid stop bits.
//

`default_nettype none
module rx_uart (
    input  logic       clk,
    input  logic       resetn,
    input  logic       rx_in,
    input  logic       data_rd,
    input  logic [15:0] div,
    output logic       error,
    output logic [31:0] data
);

    logic [2:0] state;
    logic [2:0] return_state;
    logic [2:0] bit_idx;
    logic [7:0] rx_data;
    logic ready;

    logic [16:0] wait_states;

    logic [2:0] rx_in_sync;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rx_in_sync <= 3'd0;
        end else begin
            rx_in_sync <= {rx_in_sync[1:0], rx_in};
        end
    end

    logic fifo_full;
    logic fifo_empty;
    logic [7:0] fifo_out;

    fifo #(
        .DATA_WIDTH(8),
        .DEPTH     (16)
    ) fifo_i (
        .clk   (clk),
        .resetn(resetn),
        .din   (rx_data[7:0]),
        .dout  (fifo_out),
        .push  (ready & ~fifo_full),
        .pop   (data_rd & ~fifo_empty),
        .full  (fifo_full),
        .empty (fifo_empty)
    );

    assign data = fifo_empty ? 32'hFFFF_FFFF : {24'd0, fifo_out};

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= 3'd0;
            ready <= 1'b0;
            error <= 1'b0;
            wait_states <= 17'd1;
            bit_idx <= 3'd0;
            rx_data <= 8'd0;
        end else begin
            case (state)
                3'd0: begin // Idle state
                    ready <= 1'b0;
                    error <= 1'b0;
                    if (rx_in_sync[2:1] == 2'b10) begin // Start bit detection
                        wait_states <= {1'b0, div >> 1};
                        return_state <= 3'd1;
                        state <= 3'd4; // Wait state
                    end
                end

                3'd1: begin // Verify start bit
                    if (~rx_in_sync[2]) begin
                        wait_states <= {1'b0, div};
                        return_state <= 3'd2;
                        state <= 3'd4; // Wait state
                    end else begin
                        state <= 3'd0; // Back to idle
                    end
                end

                3'd2: begin // Sample data bits
                    rx_data[bit_idx] <= rx_in_sync[2];
                    bit_idx <= bit_idx + 1'b1;
                    wait_states <= {1'b0, div};
                    return_state <= (&bit_idx) ? 3'd3 : 3'd2; // Stop bit or continue
                    state <= 3'd4; // Wait state
                end

                3'd3: begin // Verify stop bit
                    if (~rx_in_sync[2]) begin
                        error <= 1'b1; // Stop bit error
                        state <= 3'd0; // Back to idle
                    end else begin
                        wait_states <= {1'b0, div};
                        return_state <= 3'd0; // Back to idle
                        state <= 3'd4; // Wait state
                    end
                end

                3'd4: begin // Wait state
                    if (wait_states == 17'd1) begin
                        if (return_state == 3'd0) begin
                            ready <= 1'b1;
                        end
                        state <= return_state;
                    end
                    wait_states <= wait_states - 1'b1;
                end

                default: begin
                    state <= 3'd0; // Default to idle
                end
            endcase
        end
    end

endmodule
