/*
*  w9864g6jt_ctrl - A SDRAM controller
*
*  Copyright (C) 2024  Hirosh Dabui <hirosh@dabui.de>
*
*  Permission to use, copy, modify, and/or distribute this software for any
*  purpose with or without fee is hereby granted, provided that the above
*  copyright notice and this permission notice appear in all copies.
*
*  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
*  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
*  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
*  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
*  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
*  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
*  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*
*  SDRAM w9864g6jt controller Module - SystemVerilog Implementation
*
*  Description:
*  This module implements an SDRAM controller for the w9864g6jt memory device.
*  It handles initialization, auto-refresh, and read/write operations with
*  proper timing constraints. The controller sequences SDRAM commands such as
*  mode register set, active, read, write, precharge, and refresh, while
*  driving the data bus during write operations.
*
*/

`default_nettype none
`timescale 1ns / 1ps

// ===============================
// 1Mx4x16 = 8MByte
// Row addressing 4k (A0-A11)
// Bank Switching 4 (BA0, BA1)
// Column Addressing 256 (A0-A7)
// ===============================
module w9864g6jt_ctrl #(
   parameter SDRAM_CLK_FREQ = 64,
   parameter TRP_NS         = 20,
   parameter TRC_NS         = 66,
   parameter TRCD_NS        = 20,
   parameter TCH_NS         = 2,
   parameter CAS            = 3'd2
) (
   input  logic               clk,
   input  logic               resetn,

   input  logic [22:0]        addr,
   input  logic [31:0]        din,
   input  logic [3:0]         wmask,
   input  logic               valid,
   output logic [31:0]        dout,
   output logic             ready,

   output logic               sdram_clk,
   output logic               sdram_cke,
   output logic [1:0]         sdram_dqm,
   output logic [11:0]        sdram_addr,
   output logic [1:0]         sdram_ba,
   output logic               sdram_csn,
   output logic               sdram_wen,
   output logic               sdram_rasn,
   output logic               sdram_casn,
   inout  logic [15:0]        sdram_dq
);

 // Timing parameters
 localparam ONE_MICROSECOND = SDRAM_CLK_FREQ;
 localparam WAIT_100US      = 100 * ONE_MICROSECOND;  // 100 us wait
 localparam TRP  = ((TRP_NS  * ONE_MICROSECOND / 1000) + 1);
 localparam TRC  = ((TRC_NS  * ONE_MICROSECOND / 1000) + 1);
 localparam TRCD = ((TRCD_NS * ONE_MICROSECOND / 1000) + 1);
 localparam TCH  = ((TCH_NS  * ONE_MICROSECOND / 1000) + 1);

 // SDRAM mode settings
 localparam BURST_LENGTH   = 3'b001;  // 000=1, 001=2, 010=4, 011=8
 localparam ACCESS_TYPE    = 1'b0;      // 0=sequential, 1=interleaved
 localparam CAS_LATENCY    = CAS;       // 2/3 allowed, tRCD=20ns -> 3 cycles@128MHz
 localparam OP_MODE        = 2'b00;     // only 00 (standard operation) allowed
 localparam NO_WRITE_BURST = 1'b0;      // 0= write burst enabled, 1=only single access write
 localparam sdram_mode     = {1'b0, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH};

 // Display timing parameters
 initial begin
   $display("Clk frequence: %d MHz", SDRAM_CLK_FREQ);
   $display("WAIT_100US: %d cycles", WAIT_100US);
   $display("TRP: %d cycles", TRP);
   $display("TRC: %d cycles", TRC);
   $display("TRCD: %d cycles", TRCD);
   $display("TCH: %d cycles", TCH);
   $display("CAS_LATENCY: %d cycles", CAS_LATENCY);
 end

 // SDRAM command definitions (CS, RAS, CAS, WE)
 localparam CMD_MRS  = 4'b0000;  // mode register set
 localparam CMD_ACT  = 4'b0011;  // bank active
 localparam CMD_READ = 4'b0101;  // read with autoprecharge (A10=H)
 localparam CMD_WRITE= 4'b0100;  // write with autoprecharge (A10=H)
 localparam CMD_BST  = 4'b0110;  // burst stop
 localparam CMD_PRE  = 4'b0010;  // precharge selected bank, A10=H for both banks
 localparam CMD_REF  = 4'b0001;  // auto refresh (cke=H), selfrefresh assigns cke=L
 localparam CMD_NOP  = 4'b0111;
 localparam CMD_DSEL = 4'b1xxx;

 // Internal control signals
 logic [3:0]  command, command_nxt;
 logic        cke, cke_nxt;
 logic [1:0]  dqm, dqm_nxt;
 logic [11:0] saddr, saddr_nxt;
 logic [1:0]  ba, ba_nxt;

 assign sdram_clk  = clk;
 assign sdram_cke  = cke;
 assign sdram_addr = saddr;
 assign sdram_dqm  = dqm;
 assign {sdram_csn, sdram_rasn, sdram_casn, sdram_wen} = command;
 assign sdram_ba   = ba;

 // State machine definitions
 localparam RESET               = 0;
 localparam ASSERT_CKE          = 1;
 localparam INIT_SEQ_PRE_CHARGE_ALL = 2;
 localparam INIT_SEQ_AUTO_REFRESH0  = 3;
 localparam INIT_SEQ_AUTO_REFRESH1  = 4;
 localparam INIT_SEQ_LOAD_MODE      = 5;
 localparam IDLE                = 6;
 localparam COL_READ            = 7;
 localparam COL_READL           = 8;
 localparam COL_READH           = 9;
 localparam COL_WRITEL          = 10;
 localparam COL_WRITEH          = 11;
 localparam AUTO_REFRESH        = 12;
 localparam PRE_CHARGE_ALL      = 13;
 localparam WAIT_STATE          = 14;
 localparam LAST_STATE          = 15;

 localparam STATE_WIDTH = $clog2(LAST_STATE);
 logic [STATE_WIDTH-1:0] state, state_nxt;
 logic [STATE_WIDTH-1:0] ret_state, ret_state_nxt;

 localparam WAIT_STATE_WIDTH = $clog2(WAIT_100US);
 logic [WAIT_STATE_WIDTH-1:0] wait_states, wait_states_nxt;

 logic         ready_nxt;
 logic [31:0]  dout_nxt;
 logic [1:0]   dqm_nxt;

 logic         update_ready, update_ready_nxt;

 logic [15:0]  dq, dq_nxt;
 logic         oe, oe_nxt;
 assign sdram_dq = oe ? dq : 16'hz;

 // Additional address selections for column, row, and bank
 wire [11:0] select_col = {4'b0100, addr[8:2], 1'b0};
 wire [11:0] select_row = addr[22:11];
 wire [1:0]  select_bank = addr[10:9];

 // Sequential logic: state and register updates
 always_ff @(posedge clk) begin
   if (~resetn) begin
     state        <= RESET;
     ret_state    <= RESET;
     ready        <= 1'b0;
     wait_states  <= 0;
     dout         <= 0;
     command      <= CMD_NOP;
     dqm          <= 2'b11;
     dq           <= 0;
     ba           <= 2'b11;
     oe           <= 1'b0;
     saddr        <= 0;
     update_ready <= 1'b0;
   end else begin
     dq           <= dq_nxt;
     dout         <= dout_nxt;
     state        <= state_nxt;
     ready        <= ready_nxt;
     dqm          <= dqm_nxt;
     cke          <= cke_nxt;
     command      <= command_nxt;
     wait_states  <= wait_states_nxt;
     ret_state    <= ret_state_nxt;
     ba           <= ba_nxt;
     oe           <= oe_nxt;
     saddr        <= saddr_nxt;
     update_ready <= update_ready_nxt;
   end
 end

 // Combinational logic for next state calculation
 always_comb begin
   wait_states_nxt  = wait_states;
   state_nxt        = state;
   ready_nxt        = ready;
   ret_state_nxt    = ret_state;
   dout_nxt         = dout;
   command_nxt      = command;
   cke_nxt          = cke;
   saddr_nxt        = saddr;
   ba_nxt           = ba;
   dqm_nxt          = dqm;
   oe_nxt           = oe;
   dq_nxt           = dq;
   update_ready_nxt = update_ready;

   case (state)
     RESET: begin
       cke_nxt         = 1'b0;
       wait_states_nxt = WAIT_100US;
       ret_state_nxt   = ASSERT_CKE;
       state_nxt       = WAIT_STATE;
     end

     ASSERT_CKE: begin
       cke_nxt         = 1'b1;
       wait_states_nxt = 2;
       ret_state_nxt   = INIT_SEQ_PRE_CHARGE_ALL;
       state_nxt       = WAIT_STATE;
     end

     INIT_SEQ_PRE_CHARGE_ALL: begin
       cke_nxt         = 1'b1;
       command_nxt     = CMD_PRE;
       saddr_nxt[10]   = 1'b1;  // select all banks
       wait_states_nxt = TRP;
       ret_state_nxt   = INIT_SEQ_AUTO_REFRESH0;
       state_nxt       = WAIT_STATE;
     end

     INIT_SEQ_AUTO_REFRESH0: begin
       command_nxt     = CMD_REF;
       wait_states_nxt = TRC;
       ret_state_nxt   = INIT_SEQ_AUTO_REFRESH1;
       state_nxt       = WAIT_STATE;
     end

     INIT_SEQ_AUTO_REFRESH1: begin
       command_nxt     = CMD_REF;
       wait_states_nxt = TRC;
       ret_state_nxt   = INIT_SEQ_LOAD_MODE;
       state_nxt       = WAIT_STATE;
     end

     INIT_SEQ_LOAD_MODE: begin
       command_nxt     = CMD_MRS;
       saddr_nxt       = sdram_mode;
       wait_states_nxt = TCH;
       ret_state_nxt   = IDLE;
       state_nxt       = WAIT_STATE;
     end

     IDLE: begin
       oe_nxt         = 1'b0;
       dqm_nxt        = 2'b11;
       ready_nxt      = 1'b0;
       if (valid && !ready) begin
         command_nxt      = CMD_ACT;
         ba_nxt           = select_bank;
         saddr_nxt        = select_row;
         wait_states_nxt  = TRCD;
         ret_state_nxt    = |wmask ? COL_WRITEL : COL_READ;
         update_ready_nxt = 1'b1;
         state_nxt        = WAIT_STATE;
       end else begin
         // autorefresh cycle
         command_nxt      = CMD_REF;
         saddr_nxt        = 0;
         ba_nxt           = 0;
         wait_states_nxt  = TRC;
         ret_state_nxt    = IDLE;
         update_ready_nxt = 1'b0;
         state_nxt        = WAIT_STATE;
       end
     end

     COL_READ: begin
       command_nxt     = CMD_READ;
       dqm_nxt         = 2'b00;
       ba_nxt          = select_bank;
       saddr_nxt       = select_col;
       wait_states_nxt = CAS_LATENCY;
       ret_state_nxt   = COL_READL;
       state_nxt       = WAIT_STATE;
     end

     COL_READL: begin
       command_nxt    = CMD_NOP;
       dqm_nxt        = 2'b00;
       dout_nxt[15:0] = sdram_dq;
       state_nxt      = COL_READH;
     end

     COL_READH: begin
       command_nxt     = CMD_NOP;
       dqm_nxt         = 2'b00;
       dout_nxt[31:16] = sdram_dq;
       wait_states_nxt = TRP;
       ret_state_nxt   = IDLE;
       state_nxt       = WAIT_STATE;
     end

     COL_WRITEL: begin
       command_nxt = CMD_WRITE;
       dqm_nxt     = ~wmask[1:0];
       ba_nxt      = select_bank;
       saddr_nxt   = select_col;
       dq_nxt      = din[15:0];
       oe_nxt      = 1'b1;
       state_nxt   = COL_WRITEH;
     end

     COL_WRITEH: begin
       command_nxt     = CMD_NOP;
       dqm_nxt         = ~wmask[3:2];
       ba_nxt          = select_bank;
       saddr_nxt       = select_col;
       dq_nxt          = din[31:16];
       oe_nxt          = 1'b1;
       wait_states_nxt = TRP;
       ret_state_nxt   = IDLE;
       state_nxt       = WAIT_STATE;
     end

     PRE_CHARGE_ALL: begin
       command_nxt = CMD_PRE;
       saddr_nxt[10] = 1'b1;  // select all banks
       ba_nxt      = 0;
       wait_states_nxt = TRP;
       ret_state_nxt   = IDLE;
       state_nxt       = WAIT_STATE;
     end

     WAIT_STATE: begin
       command_nxt = CMD_NOP;
       wait_states_nxt = wait_states - 1;
       if (wait_states == 1) begin
         state_nxt = ret_state;
         if ((ret_state == IDLE) && update_ready) begin
           update_ready_nxt = 1'b0;
           ready_nxt        = 1'b1;
         end
       end
     end

     default: begin
       state_nxt = state;
     end
   endcase
 end

endmodule
