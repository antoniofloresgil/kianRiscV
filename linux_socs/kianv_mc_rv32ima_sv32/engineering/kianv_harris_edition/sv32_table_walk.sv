//
// Copyright (c) 2023/2024 Hirosh Dabui <hirosh@dabui.de>
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
// RISC-V SV32 Table Walk - SystemVerilog Implementation
//
// This module implements the SV32 page table walk for the RISC-V RV32IMA architecture.
// It supports virtual-to-physical address translation using two-level page tables.
//
// Features:
// - Implements TLBs for instruction and data translations (ITLB, DTLB).
// - Handles page table walks for valid, invalid, and fault cases.
// - Supports MMU translation and TLB flushing mechanisms.
//

`default_nettype none

`include "riscv_defines.svh"

module sv32_table_walk #(
    parameter NUM_ENTRIES_ITLB = 64,
    parameter NUM_ENTRIES_DTLB = 64
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] address,
    input  wire [31:0] satp,
    output logic [31:0] pte,
    input  wire        is_instruction,  // differ tlb
    input  wire        tlb_flush,

    input  wire        valid,
    output logic       ready,

    output logic       walk_mem_valid,
    input  wire        walk_mem_ready,
    output logic [31:0] walk_mem_addr,
    input  wire [31:0] walk_mem_rdata
);

  localparam ITLB_ENTRY_COUNT_WIDTH = $clog2(NUM_ENTRIES_ITLB);
  localparam DTLB_ENTRY_COUNT_WIDTH = $clog2(NUM_ENTRIES_DTLB);

  // Define states using an enum for clarity
  typedef enum logic [1:0] {
    S0 = 2'd0,
    S1 = 2'd1,
    S2 = 2'd2
  } state_e;

  state_e state, next_state;

  logic [31:0] base, base_nxt;
  logic [3:0]  vpn_shift;
  logic [9:0]  idx;
  logic [31:0] ppn;
  logic [9:0]  pte_flags;
  logic [20:0] vpn;

  logic [31:0] pte_nxt;
  logic        ready_nxt;

  logic [1:0]  level, level_nxt;
  logic [19:0] tag;

  logic [ITLB_ENTRY_COUNT_WIDTH-1:0] itlb_idx;
  logic [DTLB_ENTRY_COUNT_WIDTH-1:0] dtlb_idx;
  logic                              tlb_we;
  logic                              tlb_valid [1:0];
  logic                              tlb_hit   [1:0];
  logic [31:0]                       tlb_pte_i;
  logic [31:0]                       tlb_pte_o [1:0];

  // tag_ram instantiations
  tag_ram #(
      .TAG_RAM_ADDR_WIDTH(ITLB_ENTRY_COUNT_WIDTH),
      .TAG_WIDTH(20),
      .PAYLOAD_WIDTH(32)
  ) itlb_I (
      .clk      (clk),
      .resetn   (resetn && !tlb_flush),
      .idx      (itlb_idx),
      .tag      (tag),
      .we       (tlb_we),
      .valid_i  (tlb_valid[0]),
      .hit_o    (tlb_hit[0]),
      .payload_i(tlb_pte_i),
      .payload_o(tlb_pte_o[0])
  );

  tag_ram #(
      .TAG_RAM_ADDR_WIDTH(DTLB_ENTRY_COUNT_WIDTH),
      .TAG_WIDTH(20),
      .PAYLOAD_WIDTH(32)
  ) dtlb_I (
      .clk      (clk),
      .resetn   (resetn && !tlb_flush),
      .idx      (dtlb_idx),
      .tag      (tag),
      .we       (tlb_we),
      .valid_i  (tlb_valid[1]),
      .hit_o    (tlb_hit[1]),
      .payload_i(tlb_pte_i),
      .payload_o(tlb_pte_o[1])
  );

  wire is_itlb = !is_instruction;

  // State register
  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn)
      state <= S0;
    else
      state <= next_state;
  end

  // Registers for pte, ready, level, base
  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      pte   <= 32'b0;
      ready <= 1'b0;
      level <= 2'd1;
      base  <= 32'b0;
    end else begin
      pte   <= pte_nxt;
      ready <= ready_nxt;
      level <= level_nxt;
      base  <= base_nxt;
    end
  end

  // Determine if MMU translation is enabled
  wire mmu_translate_enable;
  assign mmu_translate_enable = `GET_SATP_MODE(satp);

  // Next state logic
  always_comb begin
    next_state = state;

    case (state)
      S0: next_state = mmu_translate_enable && valid && !ready ? S1 : S0;
      S1: next_state = tlb_hit[is_itlb] ? S0 : ((!(&level)) ? S2 : S0);
      S2: next_state = !walk_mem_ready ? S2 : ((!ready_nxt) ? S1 : S0);
      default: next_state = S0;
    endcase
  end

  integer j;
  // Combinational logic
  always_comb begin
    pte_nxt        = pte;
    base_nxt       = base;
    vpn_shift      = 4'b0;
    vpn            = 21'b0;
    pte_flags      = 10'b0;
    ready_nxt      = ready;

    walk_mem_valid = 1'b0;
    walk_mem_addr  = 32'b0;
    level_nxt      = level;
    ppn            = 32'b0;
    tlb_we         = 1'b0;
    for (j = 0; j < 2; j = j + 1) begin
      tlb_valid[j] = 1'b0;
    end
    tlb_pte_i = 32'b0;

    tag      = address >> (`SV32_PAGE_OFFSET_BITS);
    itlb_idx = tag & (NUM_ENTRIES_ITLB - 1);
    dtlb_idx = tag & (NUM_ENTRIES_DTLB - 1);

    vpn_shift   = level ? `SV32_VPN0_BITS : 0;
    idx         = (tag >> vpn_shift) & ((1 << `SV32_VPN0_BITS) - 1);
    walk_mem_addr = base + (idx << `SV32_PTE_SHIFT);  // word aligned

    case (state)
      S0: begin
        base_nxt = `GET_SATP_PPN(satp) << `SV32_PAGE_OFFSET_BITS;
        // bare mode
        if (!`GET_SATP_MODE(satp) && valid && !ready) begin
          pte_nxt   = `PTE_V_MASK | `PTE_R_MASK | `PTE_W_MASK | `PTE_X_MASK |
                      ((address >> `SV32_OFFSET_BITS) << `SV32_OFFSET_BITS);
          ready_nxt = 1'b1;
        end else begin
          ready_nxt = 1'b0;
          level_nxt = 2'd1;
        end
      end

      S1: begin
        tlb_valid[is_itlb] = 1'b1;
        if (tlb_hit[is_itlb]) begin
          pte_nxt   = tlb_pte_o[is_itlb];
          ready_nxt = 1'b1;
        end else begin
          walk_mem_valid = 1'b1;
        end
      end

      S2: begin
        // load pte
        walk_mem_valid = 1'b1;
        pte_nxt = walk_mem_rdata;
        ppn     = pte_nxt >> `SV32_PTE_PPN_SHIFT;

        if (walk_mem_ready) begin
          // pte invalid
          if (!`GET_PTE_V(pte_nxt)) begin
            pte_nxt   = 32'b0;
            ready_nxt = 1'b1;
          end else begin
            // Pointer to next level of page table
            if ((!`GET_PTE_R(pte_nxt)) &&
                (!`GET_PTE_W(pte_nxt)) &&
                (!`GET_PTE_X(pte_nxt))) begin
              ready_nxt = 1'b0;
              level_nxt = level - 1;
              base_nxt  = ppn << `SV32_PAGE_OFFSET_BITS;
            end else begin
              // actual pte
              pte_flags = pte_nxt & `PTE_FLAGS;
              vpn = address >> `SV32_PAGE_OFFSET_BITS;
              pte_nxt = ((level ? (ppn | (vpn & ((1 << `SV32_VPN0_SHIFT) - 1))) : ppn) 
                        << `SV32_PAGE_OFFSET_BITS) | pte_flags;
              level_nxt = 2'd1;
              ready_nxt = 1'b1;
              tlb_valid[is_itlb] = 1'b1;
              tlb_we = 1'b1;
              tlb_pte_i = pte_nxt;
            end
          end
        end
      end

      default: begin
        level_nxt = 2'd1;
        ready_nxt = 1'b0;
      end
    endcase
  end

endmodule
