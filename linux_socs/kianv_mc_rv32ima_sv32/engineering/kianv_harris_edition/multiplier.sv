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
// RISC-V Multiplier Module - SystemVerilog Implementation
//
// This module implements the multiplication unit for the RISC-V RV32IM architecture.
// It supports signed and unsigned multiplication, as well as high-result operations.
//
// Features:
// - Supports MUL, MULH, MULHSU, and MULHU operations.
// - Optional FPGA-specific optimization for faster multipliers.
// - Implements a state machine for sequential multiplication.
//

`default_nettype none
`include "riscv_defines.svh"

module multiplier (
    input wire                      clk,              // Clock signal
    input wire                      resetn,           // Active-low reset
    input wire [31:0]               factor1,          // Operand 1
    input wire [31:0]               factor2,          // Operand 2
    input wire [`MUL_OP_WIDTH-1:0]  MULop,            // Multiplier operation
    output logic [31:0]               product,          // Result product
    input wire                      valid,            // Valid input signal
    output logic                      ready             // Ready output signal
);

    // Internal signals
    logic is_mulh, is_mulsu, is_mulu;
    logic factor1_is_signed, factor2_is_signed;

    assign is_mulh  = (MULop == `MUL_OP_MULH);
    assign is_mulsu = (MULop == `MUL_OP_MULSU);
    assign is_mulu  = (MULop == `MUL_OP_MULU);

    assign factor1_is_signed = is_mulh | is_mulsu;
    assign factor2_is_signed = is_mulh;

    // Registers for calculation
    logic [63:0] rslt;                 // 64-bit result register
    logic [31:0] factor1_abs;          // Absolute value of factor1
    logic [31:0] factor2_abs;          // Absolute value of factor2
    logic [4:0]  bit_idx;              // Bit index for sequential calculation

    // State machine definition
    typedef enum logic [2:0] {
        IDLE  = 3'b001,                // Idle state
        CALC  = 3'b010,                // Calculation state
        READY = 3'b100                 // Ready state
    } state_t;

    state_t state;

    // Assign result output
    logic [31:0] rslt_upper_low;
    assign rslt_upper_low = (is_mulh | is_mulsu | is_mulu) ? rslt[63:32] : rslt[31:0];
    assign product        = rslt_upper_low;

    // State Machine
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state   <= IDLE;
            ready   <= 1'b0;
            bit_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    if (valid) begin
                        factor1_abs <= (factor1_is_signed & factor1[31]) ? ~factor1 + 1 : factor1;
                        factor2_abs <= (factor2_is_signed & factor2[31]) ? ~factor2 + 1 : factor2;
                        bit_idx     <= 0;
                        rslt        <= 64'd0;
                        state       <= CALC;
                    end
                end

                CALC: begin
`ifndef FPGA_MULTIPLIER
                    rslt <= rslt + ((factor1_abs & {32{factor2_abs[bit_idx]}}) << bit_idx);
                    bit_idx <= bit_idx + 1;
                    if (&bit_idx) begin
                        state <= READY;
                    end
`else
                    rslt  <= factor1_abs * factor2_abs;
                    state <= READY;
`endif
                end

                READY: begin
                    if ((factor1[31] & factor1_is_signed) ^ (factor2[31] & factor2_is_signed)) begin
                        rslt <= ~rslt + 1;  // Adjust for signed multiplication result
                    end
                    ready <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
