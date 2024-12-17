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
// MERCHANTABILITY AND FITNESS.
//
// Block RAM (BRAM) Module - SystemVerilog Implementation
//
// This module implements a parameterizable Block RAM (BRAM) with 4 byte-wide memory banks.
// Supports initialization from external memory files and write masking.
//
// Features:
// - Parameterized address width and initialization files.
// - Write masking for byte-level granularity.
// - Synchronous read and write operations.
//

`default_nettype none

module bram #(
    parameter int unsigned WIDTH = 8,            // Address width (log2 of memory depth)
    parameter string INIT_FILE0 = "",            // Initialization file for bank 0
    parameter string INIT_FILE1 = "",            // Initialization file for bank 1
    parameter string INIT_FILE2 = "",            // Initialization file for bank 2
    parameter string INIT_FILE3 = ""             // Initialization file for bank 3
)(
    input  logic                      clk,       // Clock signal
    input  logic [WIDTH-1:0]          addr,      // Memory address
    input  logic [31:0]               wdata,     // Write data
    input  logic [3:0]                wmask,     // Write mask
    output logic [31:0]               rdata      // Read data
);

    // Memory depth based on address width
    localparam int unsigned MEM_DEPTH = (1 << WIDTH);

    // Memory banks for 4 bytes
    logic [7:0] mem0 [0:MEM_DEPTH-1];  // Bank 0
    logic [7:0] mem1 [0:MEM_DEPTH-1];  // Bank 1
    logic [7:0] mem2 [0:MEM_DEPTH-1];  // Bank 2
    logic [7:0] mem3 [0:MEM_DEPTH-1];  // Bank 3

    // Initialization
    initial begin
        if (INIT_FILE0 != "") $readmemh(INIT_FILE0, mem0, 0, MEM_DEPTH-1);
        if (INIT_FILE1 != "") $readmemh(INIT_FILE1, mem1, 0, MEM_DEPTH-1);
        if (INIT_FILE2 != "") $readmemh(INIT_FILE2, mem2, 0, MEM_DEPTH-1);
        if (INIT_FILE3 != "") $readmemh(INIT_FILE3, mem3, 0, MEM_DEPTH-1);
    end

    // Synchronous Read and Write Logic
    always_ff @(posedge clk) begin
        // Write logic with byte masking
        if (wmask[0]) mem0[addr] <= wdata[7:0];
        if (wmask[1]) mem1[addr] <= wdata[15:8];
        if (wmask[2]) mem2[addr] <= wdata[23:16];
        if (wmask[3]) mem3[addr] <= wdata[31:24];

        // Read data combining all memory banks
        rdata <= {mem3[addr], mem2[addr], mem1[addr], mem0[addr]};
    end

endmodule
