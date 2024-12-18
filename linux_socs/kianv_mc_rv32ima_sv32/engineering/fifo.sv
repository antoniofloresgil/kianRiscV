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
// FIFO Module - SystemVerilog Implementation
//
// This module implements a generic First-In-First-Out (FIFO) buffer. 
// It is parameterizable in both data width and depth, allowing it to be 
// adapted to a variety of use cases. The FIFO supports push and pop 
// operations, with flags to indicate when it is full or empty.
//
// Features:
// - Configurable data width and depth.
// - Push (write) and pop (read) operations.
// - Full and empty status indicators.
// - Circular buffer implementation.
//

`default_nettype none
module fifo #(
    parameter int DATA_WIDTH = 8,  // Ancho de datos en bits
    parameter int DEPTH = 4        // Profundidad de la FIFO
) (
    input  logic clk,                             // Reloj
    input  logic resetn,                          // Reset activo en bajo
    input  logic [DATA_WIDTH-1:0] din,            // Entrada de datos
    output logic [DATA_WIDTH-1:0] dout,           // Salida de datos
    input  logic push,                            // Señal de escritura
    input  logic pop,                             // Señal de lectura
    output logic full,                            // Señal de FIFO llena
    output logic empty                            // Señal de FIFO vacía
);

    logic [DATA_WIDTH-1:0] ram [0:DEPTH-1];       // Memoria interna de la FIFO

    logic [$clog2(DEPTH):0] cnt;                  // Contador de elementos en la FIFO
    logic [$clog2(DEPTH)-1:0] rd_ptr;             // Puntero de lectura
    logic [$clog2(DEPTH)-1:0] wr_ptr;             // Puntero de escritura

    logic [$clog2(DEPTH):0] cnt_next;             // Próximo valor del contador
    logic [$clog2(DEPTH)-1:0] rd_ptr_next;        // Próximo puntero de lectura
    logic [$clog2(DEPTH)-1:0] wr_ptr_next;        // Próximo puntero de escritura

    assign empty = (cnt == 0);                    // Indica si la FIFO está vacía
    assign full  = (cnt == DEPTH);                // Indica si la FIFO está llena

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rd_ptr <= 0;
            wr_ptr <= 0;
            cnt    <= 0;
        end else begin
            rd_ptr <= rd_ptr_next;
            wr_ptr <= wr_ptr_next;
            cnt    <= cnt_next;
        end
    end

    always_comb begin
        rd_ptr_next = rd_ptr;
        wr_ptr_next = wr_ptr;
        cnt_next    = cnt;

        if (push) begin
            wr_ptr_next = wr_ptr + 1;
            if (!pop || empty) cnt_next = cnt + 1;
        end

        if (pop) begin
            rd_ptr_next = rd_ptr + 1;
            if (!push || full) cnt_next = cnt - 1;
        end
    end

    always_ff @(posedge clk) begin
        if (push) ram[wr_ptr] <= din;
    end

    assign dout = ram[rd_ptr];

endmodule