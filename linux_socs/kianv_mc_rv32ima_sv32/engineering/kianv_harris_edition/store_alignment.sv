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
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
// RISC-V Store Alignment - SystemVerilog Implementation
//
// This module implements the alignment logic for store operations in the
// RISC-V RV32IM architecture. It handles byte, halfword, and word-aligned
// store instructions, generating the appropriate write mask and data.
//
// Features:
// - Supports SB (Store Byte), SH (Store Halfword), and SW (Store Word).
// - Generates the write mask for the specific memory alignment.
// - Outputs aligned data based on the address bits.

`default_nettype none
`include "riscv_defines.svh"

module store_alignment (
    input wire [1:0]                   addr,     // Address alignment bits
    input wire [`STORE_OP_WIDTH-1:0]   STOREop,  // Store operation code
    input wire [31:0]                  data,     // Data to be stored
    output logic [31:0]                  result,   // Aligned data output
    output logic [3:0]                   wmask     // Write mask
);

    always_comb begin
        // Default outputs
        wmask  = 4'b0000;
        result = 32'b0;

        case (STOREop)
            `STORE_OP_SB: begin
                // Store Byte
                result = 32'b0;  // Reset result
                case (addr[1:0])
                    2'b00: begin
                        result[7:0]  = data[7:0];
                        wmask        = 4'b0001;
                    end
                    2'b01: begin
                        result[15:8] = data[7:0];
                        wmask        = 4'b0010;
                    end
                    2'b10: begin
                        result[23:16] = data[7:0];
                        wmask         = 4'b0100;
                    end
                    2'b11: begin
                        result[31:24] = data[7:0];
                        wmask         = 4'b1000;
                    end
                endcase
            end

            `STORE_OP_SH: begin
                // Store Halfword
                result = 32'b0;  // Reset result
                if (!addr[1]) begin
                    result[15:0] = data[15:0];
                    wmask        = 4'b0011;
                end else begin
                    result[31:16] = data[15:0];
                    wmask         = 4'b1100;
                end
            end

            `STORE_OP_SW: begin
                // Store Word
                result = data;
                wmask  = 4'b1111;
            end

            default: begin
                // Undefined operation
                result = 'x;
                wmask  = 4'b0000;
            end
        endcase
    end

endmodule
