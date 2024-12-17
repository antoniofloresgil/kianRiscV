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
// Cache Module - SystemVerilog Implementation
//
// This module implements a cache system for the Harris multicycle RISC-V RV32IMA processor.
// It supports both instruction and data memory operations with an interface to an external memory.
//
// Features:
// - Handles instruction and data cache requests.
// - Supports a 2-way associative instruction cache.
// - Connects to an external RAM interface.
//

`default_nettype none

module cache #(
    parameter int ICACHE_ENTRIES_PER_WAY = 64  // Number of entries per way in the instruction cache
) (
    input  logic         clk,                 // Clock signal
    input  logic         resetn,              // Asynchronous active-low reset
    input  logic         is_instruction,      // Instruction/data flag

    input  logic [31:0]  cpu_addr_i,          // CPU address input
    input  logic [31:0]  cpu_din_i,           // CPU data input (write data)
    input  logic [3:0]   cpu_wmask_i,         // CPU write mask
    input  logic         cpu_valid_i,         // CPU valid signal
    output logic [31:0]  cpu_dout_o,          // CPU data output (read data)
    output logic         cpu_ready_o,         // CPU ready signal

    output logic [31:0]  cache_addr_o,        // Cache address output
    output logic [31:0]  cache_din_o,         // Cache data output (write data)
    output logic [3:0]   cache_wmask_o,       // Cache write mask
    output logic         cache_valid_o,       // Cache valid signal
    input  logic [31:0]  cache_dout_i,        // Cache data input (read data)
    input  logic         cache_ready_i        // Cache ready signal
);

    // Internal wires and registers for the instruction cache
    logic [31:0] icache_ram_addr_o;
    logic [31:0] icache_ram_rdata_i;
    logic [31:0] icache_cpu_dout_o;
    logic        icache_cpu_ready_o;
    logic        icache_cpu_valid_i;
    logic [31:0] icache_cpu_addr_i;
    logic        icache_ram_valid_o;
    logic        icache_ram_ready_i;

    // Cache logic
    always_comb begin
        // Default values
        cache_addr_o         = 32'b0;
        cache_din_o          = 32'b0;
        cache_valid_o        = 1'b0;
        cache_wmask_o        = 4'b0;

        cpu_dout_o           = 32'b0;
        cpu_ready_o          = 1'b0;

        icache_cpu_addr_i    = 32'b0;
        icache_cpu_valid_i   = 1'b0;
        icache_ram_rdata_i   = 32'b0;
        icache_ram_ready_i   = 1'b0;

        // Instruction cache logic
        if (is_instruction) begin
            cache_addr_o         = icache_ram_addr_o;
            cache_valid_o        = icache_ram_valid_o;

            cpu_dout_o           = icache_cpu_dout_o;
            cpu_ready_o          = icache_cpu_ready_o;

            icache_cpu_addr_i    = cpu_addr_i;
            icache_cpu_valid_i   = cpu_valid_i;
            icache_ram_rdata_i   = cache_dout_i;
            icache_ram_ready_i   = cache_ready_i;
        end
        // Data cache logic
        else begin
            cache_addr_o         = cpu_addr_i;
            cache_din_o          = cpu_din_i;
            cache_valid_o        = cpu_valid_i;
            cache_wmask_o        = cpu_wmask_i;

            cpu_dout_o           = cache_dout_i;
            cpu_ready_o          = cache_ready_i;
        end
    end

    // Instantiation of the instruction cache
    icache #(
        .ICACHE_ENTRIES_PER_WAY(ICACHE_ENTRIES_PER_WAY),
        .WAYS(2)
    ) icache_I (
        .clk         (clk),
        .resetn      (resetn),
        .cpu_addr_i  (icache_cpu_addr_i),
        .cpu_dout_o  (icache_cpu_dout_o),
        .cpu_valid_i (icache_cpu_valid_i),
        .cpu_ready_o (icache_cpu_ready_o),

        .ram_addr_o  (icache_ram_addr_o),
        .ram_rdata_i (icache_ram_rdata_i),
        .ram_valid_o (icache_ram_valid_o),
        .ram_ready_i (icache_ram_ready_i)
    );

endmodule
