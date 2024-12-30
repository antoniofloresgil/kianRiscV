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
// RISC-V SV32 Data to Physical Address Translation - SystemVerilog Implementation
//
// This module performs SV32 page-based virtual-to-physical address translation for
// RISC-V RV32IMA. It includes privilege mode checks, page fault detection, and integration
// with the page table walker.
//
// Features:
// - Handles MSTATUS privilege overrides (MPRV, MPP).
// - Supports user and supervisor mode page accesses.
// - Detects and signals page faults for invalid or misconfigured PTEs.
//

`default_nettype none
`include "riscv_defines.svh"

module sv32_translate_data_to_physical (
    input wire        clk,
    input wire        resetn,
    input wire [31:0] address,           // Virtual address
    output logic [33:0] physical_address,  // Physical address output
    input wire        is_write,          // Write operation flag
    output logic        page_fault,        // Page fault signal
    input wire [1:0]  privilege_mode,    // Current privilege mode
    input wire [31:0] satp,              // SATP register
    input wire [31:0] mstatus,           // MSTATUS register
    input wire        valid,             // Translation valid signal
    output logic        ready,             // Translation ready signal
    output logic        walk_valid,        // Page table walk valid signal
    input wire        walk_ready,        // Page table walk ready signal
    input wire [31:0] pte_               // Page Table Entry input
);

    // FSM States
    typedef enum logic [1:0] { S0, S1 } state_t;
    state_t state, next_state;

    // Registers
    logic [31:0] pte, pagebase_addr;
    logic [11:0] page_offset;
    logic [1:0]  priv;
    logic        page_fault_nxt, ready_nxt;
    logic [33:0] physical_address_nxt;

    // Sequential Logic: State and Outputs
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state            <= S0;
            page_fault       <= 1'b0;
            physical_address <= 34'b0;
            ready            <= 1'b0;
        end else begin
            state            <= next_state;
            page_fault       <= page_fault_nxt;
            physical_address <= physical_address_nxt;
            ready            <= ready_nxt;
        end
    end

    // FSM Next-State Logic
    always_comb begin
        next_state = state;
        case (state)
            S0: if (valid && !ready) next_state = walk_ready ? S1 : S0;
            S1: next_state = S0;
            default: next_state = S0;
        endcase
    end

    // Combinational Logic
    always_comb begin
        // Defaults
        physical_address_nxt = physical_address;
        page_fault_nxt       = 1'b0;
        ready_nxt            = 1'b0;
        walk_valid           = 1'b0;

        priv = privilege_mode;
        pte  = 32'b0;
        page_offset    = 12'b0;
        pagebase_addr  = 32'b0;

        case (state)
            S0: begin
                if (valid && !ready) begin
                    // MSTATUS MPRV Override
                    if (`GET_MSTATUS_MPRV(mstatus))
                        priv = `GET_MSTATUS_MPP(mstatus);

                    if (`IS_MACHINE(priv)) begin
                        physical_address_nxt = {2'b00, address};
                        ready_nxt            = 1'b1;
                    end else begin
                        walk_valid = 1'b1;  // Trigger Page Table Walk
                    end
                end
            end

            S1: begin
                walk_valid = 1'b0;

                // Adjust PTE based on MXR flag for readable execute-only pages
                pte = pte_ | ((`GET_MSTATUS_MXR(mstatus) && `GET_PTE_X(pte_)) ? `PTE_R_MASK : 1'b0);

                // Reserved PTE Configurations Check
                if ((!`GET_PTE_X(pte) && `GET_PTE_W(pte) && !`GET_PTE_R(pte)) ||
                    (`GET_PTE_X(pte) && `GET_PTE_W(pte) && !`GET_PTE_R(pte))) begin
                    page_fault_nxt = 1'b1;
                end else if (`IS_SUPERVISOR(priv)) begin
                    // Supervisor Mode Access Checks
                    if (`GET_PTE_U(pte) && !`GET_XSTATUS_SUM(mstatus)) begin
                        page_fault_nxt = 1'b1;
                    end else if ((is_write && !`GET_PTE_W(pte)) || (!is_write && !`GET_PTE_R(pte))) begin
                        page_fault_nxt = 1'b1;
                    end
                end else begin
                    // User Mode Access Checks
                    if ((is_write && !( `GET_PTE_W(pte) && `GET_PTE_U(pte))) ||
                        (!is_write && !( `GET_PTE_R(pte) && `GET_PTE_U(pte)))) begin
                        page_fault_nxt = 1'b1;
                    end
                end

                // Calculate Physical Address
                page_offset       = address & (`SV32_PAGE_SIZE - 1);
                pagebase_addr     = (pte >> `SV32_PAGE_OFFSET_BITS) << `SV32_PAGE_OFFSET_BITS;
                physical_address_nxt = page_fault_nxt ? 34'h3FFFF_FFFF : {2'b00, pagebase_addr | page_offset};
                ready_nxt         = 1'b1;
            end
        endcase
    end

endmodule


