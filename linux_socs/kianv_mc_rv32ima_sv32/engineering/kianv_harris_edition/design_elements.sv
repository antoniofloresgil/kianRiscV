//
// copyright (c) 2022/23 hirosh dabui <hirosh@dabui.de>
// Port to SystemVerilog and additional documentation copyright (c) 2024 Antonio Flores <aflores@um.es>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// The software is provided "as is" and the author disclaims all warranties
// with regard to this software including all implied warranties of
// merchantability and fitness. In no event shall the author be liable for
// any special, direct, indirect, or consequential damages or any damages
// whatsoever resulting from loss of use, data or profits, whether in an
// action of contract, negligence or other tortious action, arising out of
// or in connection with the use or performance of this software.
//
//
// This file contains a set of multiplexer and register modules commonly used in RISC-V CPU designs.
// These modules handle selecting among multiple data inputs, capturing data on clock edges, and implementing counters.
// They form building blocks that can be reused throughout a CPU pipeline, memory interfaces, or other logic blocks.
//
// Modules included:
// * mux2: A 2-to-1 multiplexer selecting between two inputs based on a single-bit select signal.
// * mux3: A 3-to-1 multiplexer selecting among three inputs based on a 2-bit select signal.
// * mux4: A 4-to-1 multiplexer built from two mux2 modules and a final mux2 stage.
// * mux5: A 5-to-1 multiplexer selecting among five inputs based on a 3-bit select signal.
// * mux6: A 6-to-1 multiplexer selecting among six inputs based on a 3-bit select signal.
// * dlatch_kianV: A D-latch triggered on the rising edge of a clock.
// * dff_kianV: A D flip-flop with an enable signal and a reset input; it captures data on the rising clock edge.
// * counter: A counter register that increments on each clock if enabled.
//
// These blocks are parameterizable in width and can be easily integrated into larger systems.

`default_nettype none
/* verilator lint_off MULTITOP */

//============================================================
// 2-to-1 Multiplexer 
//============================================================
module mux2 #(
    parameter WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic             s,
    output logic [WIDTH-1:0] y
);

  always_comb begin
    y = s ? d1 : d0;
  end

endmodule

//============================================================
// 3-to-1 Multiplexer 
//============================================================
module mux3 #(
    parameter WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [1:0]       s,
    output logic [WIDTH-1:0] y
);

  always_comb begin
    y = s[1] ? d2 : (s[0] ? d1 : d0);
  end

endmodule

//============================================================
// 4-to-1 Multiplexer 
//============================================================
module mux4 #(
    parameter WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    input  logic [1:0]       s,
    output logic [WIDTH-1:0] y
);

  logic [WIDTH-1:0] low, high;

  mux2 #(.WIDTH(WIDTH)) lowmux (
    .d0(d0),
    .d1(d1),
    .s(s[0]),
    .y(low)
  );

  mux2 #(.WIDTH(WIDTH)) highmux (
    .d0(d2),
    .d1(d3),
    .s(s[0]),
    .y(high)
  );

  mux2 #(.WIDTH(WIDTH)) finalmux (
    .d0(low),
    .d1(high),
    .s(s[1]),
    .y(y)
  );

endmodule

//============================================================
// 5-to-1 Multiplexer 
//============================================================
module mux5 #(
    parameter WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    input  logic [WIDTH-1:0] d4,
    input  logic [2:0]       s,
    output logic [WIDTH-1:0] y
);

  always_comb begin
    case (s)
      3'd0: y = d0;
      3'd1: y = d1;
      3'd2: y = d2;
      3'd3: y = d3;
      3'd4: y = d4;
      default: y = d0;
    endcase
  end

endmodule

//============================================================
// 6-to-1 Multiplexer 
//============================================================
module mux6 #(
    parameter WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    input  logic [WIDTH-1:0] d4,
    input  logic [WIDTH-1:0] d5,
    input  logic [2:0]       s,
    output logic [WIDTH-1:0] y
);

  always_comb begin
    case (s)
      3'd0: y = d0;
      3'd1: y = d1;
      3'd2: y = d2;
      3'd3: y = d3;
      3'd4: y = d4;
      3'd5: y = d5;
      default: y = d0;
    endcase
  end

endmodule

//============================================================
// D Latch (Triggered on rising edge of clk) 
//============================================================
module dlatch_kianV #(
    parameter WIDTH = 32
) (
    input  logic             clk,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

  always_ff @(posedge clk) begin
    q <= d;
  end

endmodule

//============================================================
// D Flip-Flop with Enable and Reset 
//============================================================
module dff_kianV #(
    parameter WIDTH  = 32,
    parameter PRESET = 0
) (
    input  logic             resetn,
    input  logic             clk,
    input  logic             en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

  always_ff @(posedge clk) begin
    if (!resetn)
      q <= PRESET;
    else if (en)
      q <= d;
  end

endmodule

//============================================================
// Counter 
//============================================================
module counter #(
    parameter WIDTH = 32
) (
    input  logic             resetn,
    input  logic             clk,
    input  logic             inc,
    output logic [WIDTH-1:0] q
);

  always_ff @(posedge clk) begin
    if (!resetn)
      q <= '0;
    else if (inc)
      q <= q + 1;
  end

endmodule

/* verilator lint_on MULTITOP */
