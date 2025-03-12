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

// 2-to-1 multiplexer module
module mux2 #(
    parameter int WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic             sel,
    output logic [WIDTH-1:0] y
);
  // If s is high, select d1; otherwise, select d0.
  assign y = sel ? d1 : d0;
endmodule

// 3-to-1 multiplexer module
module mux3 #(
    parameter int WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] y
);
  // Select d2 if s[1] is high; if not, select d1 when s[0] is high; otherwise, select d0.
  assign y = sel[1] ? d2 : (sel[0] ? d1 : d0);
endmodule

// 4-to-1 multiplexer module using three 2-to-1 muxes
module mux4 #(
    parameter int WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] y
);

  // Intermediate signals for the lower and upper mux outputs.
  logic [WIDTH-1:0] low, high;

  // Lower 2-to-1 multiplexer: selects between d0 and d1 based on s[0]
  mux2 #(.WIDTH(WIDTH)) lowmux (
      .d0(d0),
      .d1(d1),
      .sel (sel[0]),
      .y (low)
  );
  // Upper 2-to-1 multiplexer: selects between d2 and d3 based on s[0]
  mux2 #(.WIDTH(WIDTH)) highmux (
      .d0(d2),
      .d1(d3),
      .sel (sel[0]),
      .y (high)
  );
  // Final multiplexer: selects between low and high based on s[1]
  mux2 #(.WIDTH(WIDTH)) finalmux (
      .d0(low),
      .d1(high),
      .sel (sel[1]),
      .y (y)
  );
endmodule

// 5-to-1 multiplexer module
module mux5 #(
    parameter int WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    input  logic [WIDTH-1:0] d4,
    input  logic [2:0]       sel,
    output logic [WIDTH-1:0] y
);
  // Select one of five inputs based on the 3-bit select signal s.
  assign y = (sel == 3'd0) ? d0 :
             (sel == 3'd1) ? d1 :
             (sel == 3'd2) ? d2 :
             (sel == 3'd3) ? d3 : d4;
endmodule

// 6-to-1 multiplexer module
module mux6 #(
    parameter int WIDTH = 32
) (
    input  logic [WIDTH-1:0] d0,
    input  logic [WIDTH-1:0] d1,
    input  logic [WIDTH-1:0] d2,
    input  logic [WIDTH-1:0] d3,
    input  logic [WIDTH-1:0] d4,
    input  logic [WIDTH-1:0] d5,
    input  logic [2:0]       sel,
    output logic [WIDTH-1:0] y
);
  // Select one of six inputs based on the value of s.
  assign y = (sel == 3'd0) ? d0 :
             (sel == 3'd1) ? d1 :
             (sel == 3'd2) ? d2 :
             (sel == 3'd3) ? d3 :
             (sel == 3'd4) ? d4 : d5;
endmodule

// D-latch module (clocked) for kianV
module dlatch_kianV #(
    parameter int WIDTH = 32
) (
    input  logic              clk,
    input  logic [WIDTH-1:0]  d,
    output logic [WIDTH-1:0]  q
);
  // This process updates q on the rising edge of clk.
  always_ff @(posedge clk) begin
      q <= d;
  end
endmodule

// D flip-flop with synchronous reset and enable for kianV
module dff_kianV #(
    parameter int WIDTH  = 32,
    parameter int PRESET = 0
) (
    input  logic             resetn,
    input  logic             clk,
    input  logic             en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
  // On each rising edge, if reset is low, q is set to PRESET.
  // Otherwise, if enable is high, q is updated with d.
  always_ff @(posedge clk) begin
    if (!resetn)
      q <= PRESET;
    else if (en)
      q <= d;
  end
endmodule

// Counter module: increments when inc is asserted, with synchronous reset.
module counter #(
    parameter int WIDTH = 32
) (
    input  logic             resetn,
    input  logic             clk,
    input  logic             inc,
    output logic [WIDTH-1:0] q
);
  // On the rising edge of clk, reset q to 0 if resetn is low, otherwise increment q if inc is high.
  always_ff @(posedge clk) begin
    if (!resetn)
      q <= 0;
    else if (inc)
      q <= q + 1;
  end
endmodule
