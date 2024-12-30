
//
// Copyright (c) 2022 Hirosh Dabui <hirosh@dabui.de>
// Port to SystemVerilog Copyright (c) 2024 Antonio Flores <aflores@um.es>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// RISC-V Divider Module - SystemVerilog Implementation
//
// This module implements a Radix-2 restoring division algorithm for the RISC-V RV32IM architecture.
// It supports both signed and unsigned division/remainder operations, controlled by the `DIVop` signal.
// The design processes division over multiple clock cycles using a state machine.
//

`default_nettype none
`include "riscv_defines.svh"

module divider (
    input wire                     clk,            // System clock
    input wire                     resetn,         // Active-low synchronous reset

    input wire [31:0]              divident,       // Dividend input
    input wire [31:0]              divisor,        // Divisor input
    input wire [`DIV_OP_WIDTH-1:0] DIVop,          // Division operation control
    output logic [31:0]              divOrRemRslt,   // Division or remainder result
    input wire                     valid,          // Input valid signal
    output logic                     ready,          // Output ready signal
    output logic                     div_by_zero_err // Divide-by-zero error flag
);

    // State Machine Definitions
    localparam logic [2:0] IDLE  = 3'b001;
    localparam logic [2:0] CALC  = 3'b010;
    localparam logic [2:0] READY = 3'b100;

    logic [2:0] div_state; // Current state of the divider

    // Registers
    logic [31:0] rem_rslt;    // Remainder result
    logic [31:0] div_rslt;    // Division result
    logic [4:0]  bit_idx;     // Counter for division steps

    // Operation Decoding
    logic is_div, is_divu, is_rem, is_remu;
    logic is_signed;

    assign is_div  = (DIVop == `DIV_OP_DIV);   // Signed Division
    assign is_divu = (DIVop == `DIV_OP_DIVU);  // Unsigned Division
    assign is_rem  = (DIVop == `DIV_OP_REM);   // Signed Remainder
    assign is_remu = (DIVop == `DIV_OP_REMU);  // Unsigned Remainder

    assign is_signed = is_div | is_rem;

    // Absolute values for signed operations
    logic [31:0] divident_abs, divisor_abs;
    assign divident_abs = (is_signed && divident[31]) ? ~divident + 1 : divident;
    assign divisor_abs  = (is_signed && divisor[31])  ? ~divisor + 1  : divisor;

    // Divide-by-Zero Detection
    assign div_by_zero_err = (divisor_abs == 32'b0);

    // Next State Signals
    logic [31:0] div_rslt_next;
    logic [31:0] rem_rslt_next;
    logic [32:0] rem_rslt_sub_divident;

    assign div_rslt_next = div_rslt << 1;
    assign rem_rslt_next = {rem_rslt[30:0], div_rslt[31]};
    assign rem_rslt_sub_divident = rem_rslt_next - divisor_abs;

    // State Machine Implementation
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            div_rslt  <= 32'b0;
            rem_rslt  <= 32'b0;
            div_state <= IDLE;
            ready     <= 1'b0;
            bit_idx   <= 5'd0;
        end else begin
            case (1'b1)
                // Idle State: Wait for valid input
                div_state[0]: begin
                    ready <= 1'b0;
                    if (valid) begin
                        div_rslt  <= divident_abs;
                        rem_rslt  <= 32'b0;
                        bit_idx   <= 5'd0;
                        div_state <= CALC;
                    end
                end

                // Calculation State: Perform division bit-by-bit
                div_state[1]: begin
                    bit_idx <= bit_idx + 1'b1;
                    if (rem_rslt_sub_divident[32]) begin
                        rem_rslt <= rem_rslt_next;
                        div_rslt <= div_rslt_next | 1'b0;
                    end else begin
                        rem_rslt <= rem_rslt_sub_divident[31:0];
                        div_rslt <= div_rslt_next | 1'b1;
                    end

                    if (&bit_idx) begin
                        div_state <= READY;
                    end
                end

                // Ready State: Finalize the result and handle sign correction
                div_state[2]: begin
                    if (is_signed && (divident[31] ^ divisor[31]) && |divisor) begin
                        div_rslt <= ~div_rslt + 1;
                    end
                    if (is_signed && divident[31]) begin
                        rem_rslt <= ~rem_rslt + 1;
                    end
                    ready     <= 1'b1;
                    div_state <= IDLE;
                end
            endcase
        end
    end

    // Final Result Selection
    assign divOrRemRslt = (is_div | is_divu) ? div_rslt : rem_rslt;

endmodule
