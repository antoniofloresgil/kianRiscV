//
// SPI Module - SystemVerilog Implementation
//
// Copyright (c) 2023 Hirosh Dabui <hirosh@dabui.de>
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
// SPI Module Description:
// This module provides an SPI interface with optional Quad-mode support and configurable clock polarity.
//
// Features:
// - Configurable SPI clock polarity (CPOL).
// - Supports single and quad SPI modes.
// - Full-duplex data transfer with configurable prescaler.
// - SPI Control and data register interface.
// - Tick-based clock divider for timing control.
//

`default_nettype none

module spi #(
    // Parameter indicating if quad mode is enabled and the clock polarity
    parameter bit QUAD_MODE = 1'b1,
    parameter bit CPOL      = 1'b0
) (
    input  logic         clk,
    input  logic         resetn,

    // Control signal: 0 = chip-select control, 1 = data mode
    input  logic         ctrl,
    output logic [31:0]  rdata,
    input  logic [31:0]  wdata,
    input  logic [3:0]   wstrb,
    input  logic [15:0]  div,
    input  logic         valid,
    output logic         ready,

    output logic         cen,
    output logic         sclk,  // SPI clock output
    inout  logic         sio1_so_miso,
    inout  logic         sio0_si_mosi,
    inout  logic         sio2,
    inout  logic         sio3
);

  // Internal registers and signals
  logic [5:0]   xfer_cycles;
  logic [31:0]  rx_data, rx_data_next;
  logic         spi_cen, spi_cen_nxt;

  logic [3:0]   sio_oe;
  logic [3:0]   sio_out;
  logic [3:0]   sio_in;

  // One-bit state registers for SPI state machine
  logic         state, next_state;
  logic [7:0]   spi_buf, spi_buf_next;
  logic         is_quad, is_quad_next;

  logic         sclk_next;
  logic [3:0]   sio_oe_next, sio_out_next;
  logic [5:0]   xfer_cycles_next;
  logic         ready_xfer, ready_xfer_next;

  // Bidirectional bus for SIO lines
  logic [3:0] sio;
  // Drive the bidirectional lines. When the output enable (sio_oe) is high,
  // drive the signal from sio_out; otherwise, leave the line in high impedance.
  assign {sio3, sio2, sio1_so_miso, sio0_si_mosi} = sio;

  // A transfer is in progress if any bit of xfer_cycles is set.
  logic in_xfer;
  assign in_xfer = |xfer_cycles;

  // rdata: if in data mode (ctrl high), output rx_data; otherwise, output status bits.
  assign rdata = ctrl ? rx_data : {in_xfer, 30'b0, spi_cen};

  // Generate bidirectional control for each SIO bit
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : SIO_BIDIRECTION_CTRL
      assign sio[i] = sio_oe[i] ? sio_out[i] : 1'bz;
    end
  endgenerate

  // Read back the SIO bus as an input
  assign sio_in = {sio3, sio2, sio1_so_miso, sio0_si_mosi};

  logic ready_ctrl, ready_ctrl_next;

  // Overall ready signal is asserted if either a transfer is ready or control is ready.
  assign ready = ready_xfer || ready_ctrl;
  assign cen   = spi_cen;

  // Synchronous process for chip enable and control ready signals
  always_ff @(posedge clk) begin
    if (!resetn) begin
      spi_cen    <= 1'b1;
      ready_ctrl <= 1'b0;
    end else begin
      spi_cen    <= spi_cen_nxt;
      ready_ctrl <= ready_ctrl_next;
    end
  end

  // Combinational logic for control access.
  // When ctrl is low (chip select control) and valid is asserted,
  // update spi_cen based on wdata.
  logic ctrl_access;
  assign ctrl_access = !ctrl & valid;
  always_comb begin
    ready_ctrl_next = 1'b0;
    spi_cen_nxt = spi_cen;
    if (ctrl_access) begin
      if (wstrb[0])
        spi_cen_nxt = ~wdata[0];
      ready_ctrl_next = 1'b1;
    end
  end

  // State encoding for the SPI state machine
  localparam logic S0_IDLE              = 1'b0;
  localparam logic S1_WAIT_FOR_XFER_DONE = 1'b1;

  // Tick counter for generating SPI timing based on the divider.
  logic [17:0] tick_cnt;
  /* verilator lint_off WIDTHEXPAND */
  logic tick;
  assign tick = (tick_cnt == ({2'b0, div} - 1));
  /* verilator lint_on WIDTHEXPAND */

  // Sequential process: update SPI signals and state on each clock edge.
  always_ff @(posedge clk) begin
    if (!resetn) begin
      sclk        <= CPOL;
      sio_oe      <= 4'b1111;
      sio_out     <= 4'b0000;
      spi_buf     <= 8'b0;
      is_quad     <= 1'b0;
      xfer_cycles <= 6'b0;
      ready_xfer  <= 1'b0;
      rx_data     <= 32'b0;
      state       <= S0_IDLE;
    end else begin
      state       <= next_state;
      sclk        <= sclk_next;
      sio_oe      <= sio_oe_next;
      sio_out     <= sio_out_next;
      spi_buf     <= spi_buf_next;
      is_quad     <= is_quad_next;
      xfer_cycles <= xfer_cycles_next;
      rx_data     <= rx_data_next;
      ready_xfer  <= ready_xfer_next;
    end
  end

  // Combinational process: determine next state and SPI transfer operations.
  always_comb begin
    // Default assignments: retain current values.
    next_state         = state;
    sclk_next          = sclk;
    sio_oe_next        = sio_oe;
    sio_out_next       = sio_out;
    spi_buf_next       = spi_buf;
    is_quad_next       = is_quad;
    ready_xfer_next    = ready_xfer;
    rx_data_next       = rx_data;
    xfer_cycles_next   = xfer_cycles;
    
    if (in_xfer) begin
      // During an active transfer, update on tick or if divider is zero.
      if (tick || (div == 16'b0)) begin
        // Drive SIO output: in quad mode use upper 4 bits; otherwise, drive a single bit.
        sio_out_next = is_quad ? {spi_buf[7:4]} : {3'b0, spi_buf[7]};
        if (sclk) begin
          sclk_next = 1'b0;
        end else begin
          sclk_next = 1'b1;
          // Shift in data from SIO bus.
          spi_buf_next = is_quad ? {spi_buf[3:0], sio_in} 
                                 : {spi_buf[6:0], sio_in[1]};
          // Decrement transfer cycle count: 4 bits per cycle in quad mode, 1 bit otherwise.
          xfer_cycles_next = is_quad ? xfer_cycles - 4 : xfer_cycles - 1;
        end
      end

    end else begin
      // When no transfer is active, handle state machine.
      case (state)
        S0_IDLE: begin
          // If a new transfer is requested (valid and in data mode)
          if (valid && ctrl) begin
            is_quad_next = QUAD_MODE;
            if (wstrb[0]) begin
              // Load the SPI buffer with the lower 8 bits of wdata.
              spi_buf_next = wdata[7:0];
              // Set output enable: all bits active in quad mode; only bit0 active otherwise.
              sio_oe_next = QUAD_MODE ? 4'b1111 : 4'b0001;
              xfer_cycles_next = 6'd8;  // Transfer one byte (8 bits)
            end else begin
              xfer_cycles_next = 6'd0;
            end
            ready_xfer_next = 1'b1;
            next_state = S1_WAIT_FOR_XFER_DONE;
          end else begin
            // Remain idle: reset clock and clear transfer cycles.
            sclk_next = CPOL;
            xfer_cycles_next = 6'd0;
            ready_xfer_next = 1'b0;
          end
        end

        S1_WAIT_FOR_XFER_DONE: begin
          // After transfer completion, capture received data.
          rx_data_next = {24'b0, spi_buf};
          next_state   = S0_IDLE;
        end

        default: next_state = S0_IDLE;
      endcase
    end
  end

  // Synchronous tick counter for SPI clock division.
  always_ff @(posedge clk) begin
    if (!resetn || tick || ~in_xfer)
      tick_cnt <= 18'b0;
    else if (in_xfer)
      tick_cnt <= tick_cnt + 1;
  end

endmodule
