//
// Copyright (c) 2024 Hirosh Dabui <hirosh@dabui.de>
// Port to SystemVerilog Copyright (c) 2024 Antonio Flores <aflores@um.es>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS.
//
// Instruction Cache (I-Cache) Module - SystemVerilog Implementation
//
// This module implements an instruction cache (I-Cache) for the Harris multicycle RISC-V RV32IMA processor.
// The cache is parameterized for associativity and number of entries per way, and it provides
// low-latency instruction fetches with a direct connection to external memory.
//
// Features:
// - Supports configurable entries per way (`ICACHE_ENTRIES_PER_WAY`) and associativity (`WAYS`).
// - Implements a Least Recently Used (LRU) replacement policy for cache eviction.
// - Manages instruction fetches with hit/miss detection and replacement.
// - Provides an interface to an external memory for cache misses.
// - Tag-based addressing with validation for hit detection.
//
`default_nettype none

module icache #(
    parameter ICACHE_ENTRIES_PER_WAY = 64,
    parameter WAYS = 2
) (
    input  logic        clk,
    input  logic        resetn,
    input  logic [31:0] cpu_addr_i,
    input  logic        cpu_valid_i,
    output logic [31:0] cpu_dout_o,
    output logic        cpu_ready_o,

    output logic [31:0] ram_addr_o,
    input  logic [31:0] ram_rdata_i,
    output logic        ram_valid_o,
    input  logic        ram_ready_i
);

    logic [31:0] block_address;
    localparam BLOCK_SIZE = 4;
    localparam BLOCK_OFFSET = $clog2(BLOCK_SIZE);
    localparam ICACHE_ENTRIES_PER_WAY_WIDTH = $clog2(ICACHE_ENTRIES_PER_WAY);
    localparam TAG_WIDTH = (32 - ICACHE_ENTRIES_PER_WAY_WIDTH - BLOCK_OFFSET);

    logic [ICACHE_ENTRIES_PER_WAY_WIDTH-1:0] idx;
    logic we;
    logic valid[WAYS-1:0];
    logic hit[WAYS-1:0];
    logic [31:0] payload_i;
    logic [31:0] payload_o[WAYS-1:0];

    logic [TAG_WIDTH-1:0] tag;
    logic [ICACHE_ENTRIES_PER_WAY-1:0] lru;
    logic [ICACHE_ENTRIES_PER_WAY-1:0] lru_nxt;

    genvar i;
    generate
        for (i = 0; i < WAYS; i++) begin : CACHE_TAG_RAM_WAYS
            tag_ram #(
                .TAG_RAM_ADDR_WIDTH(ICACHE_ENTRIES_PER_WAY_WIDTH),
                .TAG_WIDTH(TAG_WIDTH),
                .PAYLOAD_WIDTH(32)
            ) cache_I0 (
                .clk      (clk),
                .resetn   (resetn),
                .idx      (idx),
                .tag      (tag),
                .we       (we),
                .valid_i  (valid[i]),
                .hit_o    (hit[i]),
                .payload_i(payload_i),
                .payload_o(payload_o[i])
            );
        end
    endgenerate

    localparam S0 = 0, S1 = 1, S2 = 2, S_LAST = 3;
    logic [$clog2(S_LAST)-1:0] state, next_state;
    logic hit_occured;
    logic hit_occured_nxt;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= S0;
            hit_occured <= 1'b0;
            lru <= '0;
        end else begin
            state <= next_state;
            hit_occured <= hit_occured_nxt;
            lru <= lru_nxt;
        end
    end

    wire fetch_valid;
    assign fetch_valid = cpu_valid_i && !cpu_ready_o;

    always_comb begin
        next_state = state;

        case (state)
            S0: next_state = !fetch_valid ? S0 : (hit[0] || hit[1] ? S2 : S1);
            S1: next_state = ram_ready_i ? S0 : S1;
            S2: next_state = S0;
            default: next_state = S0;
        endcase
    end

    always_comb begin
        block_address = cpu_addr_i >> BLOCK_OFFSET;
        tag = block_address >> ICACHE_ENTRIES_PER_WAY_WIDTH;
        idx = block_address & ((1 << ICACHE_ENTRIES_PER_WAY_WIDTH) - 1);

        cpu_dout_o = ram_rdata_i;
        cpu_ready_o = 1'b0;

        payload_i = ram_rdata_i;

        ram_addr_o = cpu_addr_i;
        ram_valid_o = 1'b0;

        valid[0] = 1'b0;
        valid[1] = 1'b0;
        we = 1'b0;
        lru_nxt = lru;
        hit_occured_nxt = hit_occured;

        case (state)
            S0: begin
                valid[0] = fetch_valid;
                valid[1] = fetch_valid;
                hit_occured_nxt = hit[1];
            end
            S1: begin
                if (ram_ready_i) begin
                    we = 1'b1;
                    valid[lru[idx]] = 1'b1;
                    lru_nxt[idx] = ~lru[idx];
                    cpu_ready_o = 1'b1;
                end else begin
                    ram_valid_o = 1'b1;
                end
            end
            S2: begin
                valid[hit_occured] = 1'b1;
                lru_nxt[idx] = ~hit_occured;
                cpu_ready_o = 1'b1;
                cpu_dout_o = payload_o[hit_occured];
            end
        endcase
    end

endmodule
