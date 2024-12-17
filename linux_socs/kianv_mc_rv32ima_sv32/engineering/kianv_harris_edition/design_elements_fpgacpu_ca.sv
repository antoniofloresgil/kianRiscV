
//  Port to SystemVerilog copyright (c) 2024 Antonio Flores <aflores@um.es>
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  The software is provided "as is" and the author disclaims all warranties
//  with regard to this software including all implied warranties of
//  merchantability and fitness. In no event shall the author be liable for
//  any special, direct, indirect, or consequential damages or any damages
//  whatsoever resulting from loss of use, data or profits, whether in an
//  action of contract, negligence or other tortious action, arising out of
//  or in connection with the use or performance of this software.
//
// Design Elements - SystemVerilog Implementation
//
// This file provides several combinational logic modules that can be reused in various CPU design contexts,
// particularly for a RISC-V processor or similar architectures. The modules include:
//
// * Priority_Encoder: Given multiple request bits, finds the one with the highest priority (lowest index bit set)
//   and returns its index, along with a validity signal.
// * Bitmask_Isolate_Rightmost_1_Bit: Extracts the least significant set bit in a given mask.
// * Logarithm_of_Powers_of_Two: Computes the base-2 logarithm of a one-hot input, signaling undefined if none is set.
// * Word_Reducer and Bit_Reducer: Perform Boolean reductions (AND, OR, XOR, etc.) across multiple words or bits.
// * Multiplexer_Binary_Behavioural: Selects one of multiple input words based on a binary selector.
//
// These modules are generic and parameterizable, enabling reuse in arbiters, decoders, priority selectors, 
// and other logic where encoding and selecting set bits or reducing multiple signals into a single result are required.
//

`default_nettype none

//######################################
//# Priority Encoder
//######################################
//
// A Priority Encoder takes a bitmask of multiple requests and returns the zero-based index of
// the highest-priority bit that is set. The least-significant bit has the highest priority.
// If no bits are set, the output is zero but signaled as invalid.
//
// For example:
//
// * 11111 --> 00000 (0), valid
// * 00010 --> 00001 (1), valid
// * 01100 --> 00010 (2), valid
// * 11000 --> 00011 (3), valid
// * 10000 --> 00011 (4), valid
// * 00000 --> 00000 (0), invalid
//
module Priority_Encoder #(
    parameter WORD_WIDTH = 32
) (
    input  wire [WORD_WIDTH-1:0] word_in,
    output wire [WORD_WIDTH-1:0] word_out,
    output logic                 word_out_valid
);

  localparam WORD_ZERO = {WORD_WIDTH{1'b0}};

  initial begin
    word_out_valid = 1'b0;
  end

  // First, isolate the least-significant set bit
  wire [WORD_WIDTH-1:0] lsb_1;

  Bitmask_Isolate_Rightmost_1_Bit #(
      .WORD_WIDTH(WORD_WIDTH)
  ) find_lsb_1 (
      .word_in (word_in),
      .word_out(lsb_1)
  );

  // For a single set bit (a power of two), its index is the base-2 logarithm.
  wire logarithm_undefined;

  Logarithm_of_Powers_of_Two #(
      .WORD_WIDTH(WORD_WIDTH)
  ) calc_bit_index (
      .one_hot_in         (lsb_1),
      .logarithm_out      (word_out),
      .logarithm_undefined(logarithm_undefined)
  );

  always_comb begin
    word_out_valid = (logarithm_undefined == 1'b0);
  end

endmodule


//######################################
//# Bitmask: Isolate Rightmost 1 Bit
//######################################
//
// Isolates the rightmost set bit of a word. If none is set, returns 0.
// Example: 01011000 -> 00001000
//
module Bitmask_Isolate_Rightmost_1_Bit #(
    parameter WORD_WIDTH = 0
) (
    input  wire [WORD_WIDTH-1:0]  word_in,
    output logic [WORD_WIDTH-1:0] word_out
);

  initial begin
    word_out = {WORD_WIDTH{1'b0}};
  end

  always_comb begin
    // This takes advantage of two's complement: -word_in isolates the LSB set bit.
    word_out = word_in & (-word_in);
  end

endmodule


//######################################
//# Logarithm of Powers of Two
//######################################
//
// Given a one-hot input (a single set bit), this module returns the zero-based index of that bit.
// If the input is not a power-of-two or is zero, it signals that the logarithm is undefined.
//
module Logarithm_of_Powers_of_Two #(
    parameter WORD_WIDTH = 0
) (
    input  wire [WORD_WIDTH-1:0] one_hot_in,
    output wire [WORD_WIDTH-1:0] logarithm_out,
    output logic                 logarithm_undefined
);

  localparam WORD_ZERO = {WORD_WIDTH{1'b0}};

  initial begin
    logarithm_undefined = 1'b0;
  end

  localparam LOGARITHM_WIDTH = $clog2(WORD_WIDTH);
  localparam PAD_WIDTH = WORD_WIDTH - LOGARITHM_WIDTH;
  localparam PAD = {PAD_WIDTH{1'b0}};

  localparam TOTAL_WIDTH = WORD_WIDTH * WORD_WIDTH;
  localparam TOTAL_ZERO  = {TOTAL_WIDTH{1'b0}};

  logic [TOTAL_WIDTH-1:0] all_logarithms = TOTAL_ZERO;

  generate
    genvar i;
    for (i = 0; i < WORD_WIDTH; i = i + 1) begin : per_input_bit
      always_comb begin
        all_logarithms[WORD_WIDTH*i +: WORD_WIDTH] = (one_hot_in[i] == 1'b1) ? {PAD, i[LOGARITHM_WIDTH-1:0]} : {WORD_WIDTH{1'b0}};
      end
    end
  endgenerate

  // Reduce all potential logarithms by OR-ing them together
  Word_Reducer #(
      .OPERATION ("OR"),
      .WORD_WIDTH(WORD_WIDTH),
      .WORD_COUNT(WORD_WIDTH)
  ) combine_logarithms (
      .words_in(all_logarithms),
      .word_out(logarithm_out)
  );

  // If input is zero, the logarithm is undefined.
  always_comb begin
    logarithm_undefined = (one_hot_in == WORD_ZERO);
  end

endmodule


//######################################
//# Word_Reducer
//######################################
//
// Reduces multiple words into a single word using a specified Boolean operation 
// (AND, NAND, OR, NOR, XOR, XNOR). Each bit position of the output is reduced across 
// the corresponding bits of all input words.
//
module Word_Reducer #(
    parameter OPERATION  = "",
    parameter WORD_WIDTH = 0,
    parameter WORD_COUNT = 0,
    parameter TOTAL_WIDTH = WORD_WIDTH * WORD_COUNT
) (
    input  wire [TOTAL_WIDTH-1:0] words_in,
    output wire [WORD_WIDTH-1:0]  word_out
);

  localparam BIT_ZERO = {WORD_COUNT{1'b0}};

  generate
    genvar i, j;
    for (j = 0; j < WORD_WIDTH; j = j + 1) begin : per_bit
      logic [WORD_COUNT-1:0] bit_word = BIT_ZERO;

      for (i = 0; i < WORD_COUNT; i = i + 1) begin : per_word
        always_comb begin
          bit_word[i] = words_in[(WORD_WIDTH*i)+j];
        end
      end

      Bit_Reducer #(
          .OPERATION  (OPERATION),
          .INPUT_COUNT(WORD_COUNT)
      ) bit_position (
          .bits_in(bit_word),
          .bit_out(word_out[j])
      );
    end
  endgenerate

endmodule


//######################################
//# Bit_Reducer
//######################################
//
// Performs a Boolean reduction on an array of bits, with operations: AND, NAND, OR, NOR, XOR, XNOR.
//
module Bit_Reducer #(
    parameter OPERATION   = "",
    parameter INPUT_COUNT = 0
) (
    input  wire [INPUT_COUNT-1:0] bits_in,
    output reg                    bit_out
);

  initial begin
    bit_out = 1'b0;
  end

  reg [INPUT_COUNT-1:0] partial_reduction;

  integer i;

  initial begin
    for (i = 0; i < INPUT_COUNT; i = i + 1) begin
      partial_reduction[i] = 1'b0;
    end
  end

  always_comb begin
    partial_reduction[0] = bits_in[0];
    bit_out              = partial_reduction[INPUT_COUNT-1];
  end

  generate
    if (OPERATION == "AND") begin
      always_comb begin
        for (i = 1; i < INPUT_COUNT; i = i + 1) begin
          partial_reduction[i] = partial_reduction[i-1] & bits_in[i];
        end
      end
    end else
    if (OPERATION == "NAND") begin
      always_comb begin
        for (i = 1; i < INPUT_COUNT; i = i + 1) begin
          partial_reduction[i] = ~(partial_reduction[i-1] & bits_in[i]);
        end
      end
    end else
    if (OPERATION == "OR") begin
      always_comb begin
        for (i = 1; i < INPUT_COUNT; i = i + 1) begin
          partial_reduction[i] = partial_reduction[i-1] | bits_in[i];
        end
      end
    end else
    if (OPERATION == "NOR") begin
      always_comb begin
        for (i = 1; i < INPUT_COUNT; i = i + 1) begin
          partial_reduction[i] = ~(partial_reduction[i-1] | bits_in[i]);
        end
      end
    end else
    if (OPERATION == "XOR") begin
      always_comb begin
        for (i = 1; i < INPUT_COUNT; i = i + 1) begin
          partial_reduction[i] = partial_reduction[i-1] ^ bits_in[i];
        end
      end
    end else
    if (OPERATION == "XNOR") begin
      always_comb begin
        for (i = 1; i < INPUT_COUNT; i = i + 1) begin
          partial_reduction[i] = ~(partial_reduction[i-1] ^ bits_in[i]);
        end
      end
    end
  endgenerate
endmodule


//######################################
//# Multiplexer_Binary_Behavioural
//######################################
//
// A binary multiplexer that selects one of multiple input words based on a binary address.
//
module Multiplexer_Binary_Behavioural #(
    parameter WORD_WIDTH  = 1,
    parameter ADDR_WIDTH  = 1,
    parameter INPUT_COUNT = 1,

    parameter TOTAL_WIDTH = WORD_WIDTH * INPUT_COUNT
) (
    input  wire [ADDR_WIDTH-1:0] selector,
    input  wire [TOTAL_WIDTH-1:0] words_in,
    output logic [WORD_WIDTH-1:0] word_out
);

  initial begin
    word_out = {WORD_WIDTH{1'b0}};
  end

  always_comb begin
    word_out = words_in[(selector*WORD_WIDTH)+:WORD_WIDTH];
  end

endmodule

