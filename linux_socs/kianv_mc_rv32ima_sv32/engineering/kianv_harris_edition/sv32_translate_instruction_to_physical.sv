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
// ANY DAMAGES ARISING OUT OF THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// RISC-V SV32 Instruction to Physical Address Translation - SystemVerilog Implementation
//
// This module performs SV32-based virtual-to-physical address translation for instructions.
// It includes privilege mode checks, page fault detection, and page table walking.
//
// Features:
// - Supports machine and supervisor privilege modes.
// - Detects reserved PTE configurations.
// - Ensures valid executable permissions.
//

`default_nettype none
`include "riscv_defines.svh"

module sv32_translate_instruction_to_physical (
    input wire          clk,
    input wire          resetn,
    input wire [31:0]   address,            // Virtual instruction address
    output logic [33:0] physical_address,   // Translated physical address
    output logic        page_fault,         // Page fault indication
    input wire [1:0]    privilege_mode,     // Privilege mode: machine/supervisor
    input wire [31:0]   satp,               // SATP register for page table base
    input wire          valid,              // Translation request valid
    output logic        ready,              // Translation ready signal
    output logic        walk_valid,         // Page table walk start signal
    input wire          walk_ready,         // Page table walk ready signal
    input wire [31:0]   pte                 // Page Table Entry result
);

    // FSM State Definitions
    typedef enum logic [1:0] {
        S0,  // Idle/Start State
        S1   // Page Table Entry (PTE) Processing
    } state_t;

    state_t state, next_state;

    // Internal Signals
    logic [1:0]  priv;
    logic        page_fault_nxt, ready_nxt;
    logic [33:0] physical_address_nxt;
    logic [11:0] page_offset;
    logic [31:0] pagebase_addr;

    // State Register Update
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

    // Next-State Logic
    always_comb begin
        next_state = state;
        case (state)
            S0: if (valid && !ready) next_state = walk_ready ? S1 : S0;
            S1: next_state = S0;
            default: next_state = S0;
        endcase
    end

    // Output and Logic Calculation
    always_comb begin
        // Default values
        physical_address_nxt = physical_address;
        page_fault_nxt       = 1'b0;
        ready_nxt            = 1'b0;
        walk_valid           = 1'b0;

        priv          = privilege_mode;
        page_offset   = 12'b0;
        pagebase_addr = 32'b0;

        case (state)
            S0: begin
                if (valid && !ready) begin
                    if (`IS_MACHINE(priv)) begin
                        physical_address_nxt = {2'b00, address};
                        ready_nxt            = 1'b1;
                    end else begin
                        walk_valid = 1'b1;  // Trigger page table walk
                    end
                end
            end

            S1: begin
                walk_valid = 1'b0;

                // Reserved PTE configurations check
                if ((!`GET_PTE_X(pte) && `GET_PTE_W(pte) && !`GET_PTE_R(pte)) ||
                    (`GET_PTE_X(pte) && `GET_PTE_W(pte) && !`GET_PTE_R(pte))) begin
                    page_fault_nxt = 1'b1;
                end else if (`IS_SUPERVISOR(priv)) begin
                    // Supervisor mode checks
                    if (`GET_PTE_U(pte) || !`GET_PTE_X(pte)) begin
                        page_fault_nxt = 1'b1;
                    end
                end else begin
                    // User mode checks
                    if (!( `GET_PTE_X(pte) && `GET_PTE_U(pte) )) begin
                        page_fault_nxt = 1'b1;
                    end
                end

                // Calculate physical address
                page_offset       = address & (`SV32_PAGE_SIZE - 1);
                pagebase_addr     = (pte >> `SV32_PAGE_OFFSET_BITS) << `SV32_PAGE_OFFSET_BITS;
                physical_address_nxt = page_fault_nxt ? 34'h3FFF_FFFF : {2'b00, pagebase_addr | page_offset};
                ready_nxt         = 1'b1;
            end
        endcase
    end

endmodule
