//
// Copyright (c) 2024 Hirosh Dabui <hirosh@dabui.de>
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
// RISC-V Tag RAM Module - SystemVerilog Implementation
//
// This module implements a tag RAM for cache or TLB usage, supporting tag matching,
// payload storage, and hit detection.
//
// Features:
// - Configurable tag, payload, and address widths.
// - Supports write enable and validity flags.
// - Hit detection logic to determine cache or TLB hits.
//
`default_nettype none
`include "riscv_defines.svh"

module tag_ram #(
    parameter int unsigned TAG_RAM_ADDR_WIDTH = 6,
    parameter int unsigned TAG_WIDTH          = 20,
    parameter int unsigned PAYLOAD_WIDTH      = 32
)(
    input  logic                          clk,
    input  logic                          resetn,
    input  logic [TAG_RAM_ADDR_WIDTH-1:0] idx,        // Address index
    input  logic [TAG_WIDTH-1:0]          tag,        // Tag input
    input  logic [PAYLOAD_WIDTH-1:0]      payload_i,  // Payload input
    input  logic                          we,         // Write enable
    input  logic                          valid_i,    // Validity input
    output logic                          hit_o,      // Hit flag
    output logic [PAYLOAD_WIDTH-1:0]      payload_o   // Payload output
);

    // Number of lines based on address width
    localparam int unsigned LINES = 2 ** TAG_RAM_ADDR_WIDTH;

    // Tag, Payload, and Validity storage
    logic [TAG_WIDTH-1:0]          tags     [0:LINES-1];
    logic [PAYLOAD_WIDTH-1:0]      payloads [0:LINES-1];
    logic [LINES-1:0]              valid;

    // Hit Detection and Payload Output
    always_comb begin
        hit_o      = (tags[idx] == tag) && valid[idx];
        payload_o  = hit_o ? payloads[idx] : '0;  // Return payload if hit, otherwise zero
    end

    // Write Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            valid <= '0;  // Reset validity flags
        end else if (valid_i && we) begin
            tags[idx]     <= tag;        // Write tag
            payloads[idx] <= payload_i;  // Write payload
            valid[idx]    <= 1'b1;       // Mark entry as valid
        end
    end

endmodule
