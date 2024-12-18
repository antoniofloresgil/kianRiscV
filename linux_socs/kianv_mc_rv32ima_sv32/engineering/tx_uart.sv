//
// TX UART Module - SystemVerilog Implementation
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
// TX UART Module Description:
// This module implements a simple UART transmitter.
// It supports configurable baud rates and outputs a serial stream of data.
//
// Features:
// - Start, data, and stop bit generation.
// - Configurable baud rate through a divisor input.
// - Status signals for ready and busy states.
//

`default_nettype none

module tx_uart (
    input  logic       clk,
    input  logic       resetn,
    input  logic       valid,
    input  logic [7:0] tx_data,
    input  logic [15:0] div,  // SYSTEM_CYCLES/BAUDRATE
    output logic       tx_out,
    output logic       ready,
    output logic       busy
);

    logic [2:0] state;
    logic [2:0] return_state;
    logic [2:0] bit_idx;
    logic [7:0] tx_data_reg;
    logic       txfer_done;

    assign ready = txfer_done;
    assign busy  = |state;

    logic [15:0] wait_states;
    logic [15:0] CYCLES_PER_SYMBOL;
    assign CYCLES_PER_SYMBOL = div;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            tx_out      <= 1'b1;
            state       <= 0;
            txfer_done  <= 1'b0;
            bit_idx     <= 0;
            tx_data_reg <= 0;
        end else begin
            case (state)
                0: begin  // Idle state
                    txfer_done <= 1'b0;
                    if (valid && !txfer_done) begin
                        tx_out <= 1'b0;  // Start bit
                        tx_data_reg <= tx_data;
                        wait_states <= CYCLES_PER_SYMBOL - 1;
                        return_state <= 1;
                        state <= 3;
                    end else begin
                        tx_out <= 1'b1;
                    end
                end

                1: begin  // Data transmission
                    tx_out <= tx_data_reg[bit_idx];  // LSB first
                    bit_idx <= bit_idx + 1;
                    wait_states <= CYCLES_PER_SYMBOL - 1;
                    return_state <= &bit_idx ? 2 : 1;
                    state <= 3;
                end

                2: begin  // Stop bit
                    tx_out <= 1'b1;  // Stop bit
                    wait_states <= (CYCLES_PER_SYMBOL << 1) - 1;
                    return_state <= 0;
                    state <= 3;
                end

                3: begin  // Wait states
                    wait_states <= wait_states - 1;
                    if (wait_states == 1) begin
                        if (~(|return_state)) txfer_done <= 1'b1;
                        state <= return_state;
                    end
                end

                default: begin
                    state <= 0;
                end
            endcase
        end
    end

endmodule
