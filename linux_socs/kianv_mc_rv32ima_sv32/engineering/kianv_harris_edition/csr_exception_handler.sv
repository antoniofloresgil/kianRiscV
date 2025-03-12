//
//  kianv.v - RISC-V rv32ima
//
//  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
//  Port to SystemVerilog copyright (c) 2024 Antonio Flores <aflores@um.es>
//
//  permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  the software is provided "as is" and the author disclaims all warranties
//  with regard to this software including all implied warranties of
//  merchantability and fitness. in no event shall the author be liable for
//  any special, direct, indirect, or consequential damages or any damages
//  whatsoever resulting from loss of use, data or profits, whether in an
//  action of contract, negligence or other tortious action, arising out of
//  or in connection with the use or performance of this software.
//
//  CSR Exception Handler - SystemVerilog Implementation
//
`default_nettype none
`include "riscv_defines.svh"

module csr_exception_handler #(
    parameter SYSTEM_CLK = 50_000_00
) (
    input  wire                      clk,
    input  wire                      resetn,
    input  wire                      incr_inst_retired,
    input  wire [11:0]               CSRAddr,
    input  wire [`CSR_OP_WIDTH -1:0] CSRop,
    input  wire                      we,
    input  wire                      re,
    input  wire [31:0]               Rd1,
    input  wire [4:0]                uimm,
    input  wire                      exception_event,
    input  wire                      mret,
    input  wire                      sret,
    input  wire                      wfi_event,
    input  wire [31:0]               cause,
    input  wire [31:0]               pc,
    input  wire [31:0]               badaddr,
    output logic [31:0]              rdata,
    output logic [31:0]              exception_next_pc,
    output logic                     exception_select,
    output logic [1:0]               privilege_mode,
    output wire                      csr_access_fault,
    output logic [31:0]              mstatus,
    output wire [63:0]              timer_counter  /* verilator public_flat_rw */,

    output logic [31:0]              satp,
    output logic                     tlb_flush,

    input  wire                      IRQ3,
    input  wire                      IRQ7,
    input  wire                      IRQ9,
    input  wire                      IRQ11,

    output logic                     IRQ_TO_CPU_CTRL1,
    output logic                     IRQ_TO_CPU_CTRL3,
    output logic                     IRQ_TO_CPU_CTRL5,
    output logic                     IRQ_TO_CPU_CTRL7,
    output logic                     IRQ_TO_CPU_CTRL9,
    output logic                     IRQ_TO_CPU_CTRL11
);

  // Determine if the CSR operand comes from a register.
  wire is_reg_operand;
  assign is_reg_operand = (CSRop == `CSR_OP_CSRRW) ||
                          (CSRop == `CSR_OP_CSRRS) ||
                          (CSRop == `CSR_OP_CSRRC);

  // Extract privilege level from CSR address (bits [9:8])
  // Check if the CSR is read-only by examining bits [11:10] of CSR address.
  logic csr_not_exist;
  wire [1:0] csr_privilege_level;
  assign csr_privilege_level = CSRAddr[9:8];
  wire csr_read_only;
  assign csr_read_only = (CSRAddr[11:10] == 2'b11);
  assign csr_access_fault = (privilege_mode < csr_privilege_level) ||
                            (we & csr_read_only) ||
                            csr_not_exist;
  wire csr_write_valid;
  assign csr_write_valid = we && !csr_access_fault;

  // Extend immediate value to 32 bits.
  wire [31:0] extended_uimm;
  assign extended_uimm = {{27{1'b0}}, uimm};
  wire [31:0] wdata;
  assign wdata = is_reg_operand ? Rd1 : extended_uimm;

  // CSR: rdcycle[H], rdtime[H], rdinstret[H]
  wire [63:0] instr_counter;
  wire increase_instruction;
  assign increase_instruction = incr_inst_retired;

  // Instruction counter instantiation
  counter #(64) instr_cnt_I (
      resetn,
      clk,
      incr_inst_retired,
      instr_counter
  );

  // Timer generation using a tick counter.
  logic [17:0] tick_cnt;
  /* verilator lint_off WIDTHTRUNC */
  wire [15:0] div = (SYSTEM_CLK / 1_000_000);
  /* verilator lint_on WIDTHTRUNC */
  wire tick = (tick_cnt == ({2'b0, div} - 1));
  always_ff @(posedge clk) begin
    if (!resetn || tick) begin
      tick_cnt <= 0;
    end else begin
      tick_cnt <= tick_cnt + 1;
    end
  end

  // Timer counter instantiation.
  counter #(64) timer_cnt_I (
      resetn,
      clk,
      tick,
      timer_counter
  );

  // Cycle counter instantiation.
  wire [63:0] cycle_counter;
  counter #(64) cycle_counter_I (
      resetn,
      clk,
      1'b1,
      cycle_counter
  );

  // Next state signals.
  logic [1:0] privilege_mode_nxt;

  // Machine-Level CSRs
  logic [31:0] mtimecmp;
  logic [31:0] mtimecmph;
  // Machine Trap Handling CSRs
  logic [31:0] mscratch;
  logic [31:0] mtvec;
  logic [31:0] mepc;
  logic [31:0] mcause;
  logic [31:0] mtval;
  logic [31:0] medeleg;
  logic [31:0] mideleg;

  logic [31:0] mie;
  logic [31:0] mip;

  logic [31:0] menvcfg;
  logic [31:0] menvcfgh;
  logic [31:0] mcounteren;
  logic [31:0] mcountinhibit;

  logic [31:0] mtimecmp_nxt;
  logic [31:0] mtimecmph_nxt;

  logic [31:0] mscratch_nxt;
  logic [31:0] mtvec_nxt;
  logic [31:0] mepc_nxt;
  logic [31:0] mtval_nxt;
  logic [31:0] mcause_nxt;
  logic [31:0] mstatus_nxt;
  logic [31:0] mie_nxt;
  logic [31:0] mip_nxt;
  logic [31:0] medeleg_nxt;
  logic [31:0] mideleg_nxt;

  logic [31:0] menvcfg_nxt;
  logic [31:0] menvcfgh_nxt;
  logic [31:0] mcounteren_nxt;
  logic [31:0] mcountinhibit_nxt;

  // Supervisor-Level CSRs
  logic [31:0] sscratch;
  logic [31:0] stvec;
  logic [31:0] sepc;
  logic [31:0] scause;
  logic [31:0] stval;

  logic [31:0] stimecmp;
  logic [31:0] stimecmph;
  logic [31:0] scounteren;

  logic [31:0] sscratch_nxt;
  logic [31:0] stvec_nxt;
  logic [31:0] sepc_nxt;
  logic [31:0] scause_nxt;
  logic [31:0] stval_nxt;
  logic [31:0] satp_nxt;

  logic [31:0] stimecmp_nxt;
  logic [31:0] stimecmph_nxt;
  logic [31:0] scounteren_nxt;

  logic [31:0] exception_next_pc_nxt;
  logic         exception_select_nxt;

  // CSR operation decoding.
  wire is_csrrw, is_csrrs, is_csrrc;
  wire is_csrrwi, is_csrrsi, is_csrrci;
  assign is_csrrw  = (CSRop == `CSR_OP_CSRRW);
  assign is_csrrs  = (CSRop == `CSR_OP_CSRRS);
  assign is_csrrc  = (CSRop == `CSR_OP_CSRRC);
  assign is_csrrwi = (CSRop == `CSR_OP_CSRRWI);
  assign is_csrrsi = (CSRop == `CSR_OP_CSRRSI);
  assign is_csrrci = (CSRop == `CSR_OP_CSRRCI);

  wire is_csr_set;
  assign is_csr_set = is_csrrs || is_csrrsi;
  wire is_csr_clear;
  assign is_csr_clear = is_csrrc || is_csrrci;

  // Synchronous sequential logic with synchronous reset.
  always_ff @(posedge clk) begin
    if (!resetn) begin
      privilege_mode <= `PRIVILEGE_MODE_MACHINE;
      /* verilator lint_off WIDTHEXPAND */
      mstatus <= 0;  // `SET_MSTATUS_MPP(`PRIVILEGE_MODE_MACHINE);
      /* verilator lint_on WIDTHEXPAND */
      mtimecmp <= 0;
      mtimecmph <= 0;

      mscratch <= 0;
      mtvec <= 0;
      mepc <= 0;
      mcause <= 0;
      mtval <= 0;
      mie <= 0;
      mip <= 0;

      menvcfg <= 0;
      menvcfgh <= 0;
      mcounteren <= 0;
      mcountinhibit <= 0;

      medeleg <= 0;
      mideleg <= 0;

      sscratch <= 0;
      stvec <= 0;
      sepc <= 0;
      scause <= 0;
      stval <= 0;

      satp <= 0;

      stimecmp <= 0;
      stimecmph <= 0;
      scounteren <= 0;

      exception_next_pc <= 0;
      exception_select <= 1'b0;
    end else begin
      privilege_mode <= privilege_mode_nxt;

      mtimecmp <= mtimecmp_nxt;
      mtimecmph <= mtimecmph_nxt;

      mscratch <= mscratch_nxt;
      mtvec <= mtvec_nxt;
      mepc <= mepc_nxt;
      mcause <= mcause_nxt;
      mtval <= mtval_nxt;
      mie <= mie_nxt;
      mip <= mip_nxt;

      menvcfg <= menvcfg_nxt;
      menvcfgh <= menvcfgh_nxt;
      mcounteren <= mcounteren_nxt;
      mcountinhibit <= mcountinhibit_nxt;

      medeleg <= medeleg_nxt;
      mideleg <= mideleg_nxt;

      sscratch <= sscratch_nxt;
      stvec <= stvec_nxt;
      sepc <= sepc_nxt;
      scause <= scause_nxt;
      stval <= stval_nxt;

      satp <= satp_nxt;

      stimecmp <= stimecmp_nxt;
      stimecmph <= stimecmph_nxt;
      scounteren <= scounteren_nxt;

      exception_next_pc <= exception_next_pc_nxt;
      exception_select <= exception_select_nxt;

      mstatus <= mstatus_nxt;  // | ({31'b0, wfi_event} << 3);
    end
  end

  // Combinational logic for CSR read.
  always_comb begin
    csr_not_exist = 1'b0;
    rdata = 32'b0;
    case (CSRAddr)
      `CSR_MISA:
        rdata = 
          /* verilator lint_off WIDTHEXPAND */
          `SET_MISA_VALUE(`MISA_MXL_RV32) |
          `MISA_EXTENSION_BIT(`MISA_EXTENSION_A) |
          `MISA_EXTENSION_BIT(`MISA_EXTENSION_I) |
          `MISA_EXTENSION_BIT(`MISA_EXTENSION_M) |
          `MISA_EXTENSION_BIT(`MISA_EXTENSION_S) |
          `MISA_EXTENSION_BIT(`MISA_EXTENSION_U);
          /* verilator lint_on WIDTHEXPAND */

      // Unprivileged and User-Level CSRs
      `CSR_INSTRET:    rdata = instr_counter[31:0];
      `CSR_INSTRETH:   rdata = instr_counter[63:32];
      `CSR_CYCLE:      rdata = cycle_counter[31:0];
      `CSR_CYCLEH:     rdata = cycle_counter[63:32];
      `CSR_TIME:       rdata = timer_counter[31:0];
      `CSR_TIMEH:      rdata = timer_counter[63:32];

      // Machine-Level CSRs - Machine Information Register
      `CSR_MHARTID:    rdata = 32'b0;
      `CSR_MVENDORID:  rdata = 32'h0;
      `CSR_MARCHID:    rdata = 32'h2b; // registered kianV
      `CSR_MIMPID:     rdata = 0;

      // Machine Trap Setup and Handling
      `CSR_MSTATUS:    rdata = mstatus;
      `CSR_MSCRATCH:   rdata = mscratch;
      `CSR_MIE:        rdata = mie;
      `CSR_MIP:        rdata = mip;
      `CSR_MTVEC:      rdata = mtvec;
      `CSR_MEPC:       rdata = mepc;
      `CSR_MCAUSE:     rdata = mcause;
      `CSR_MTVAL:      rdata = mtval;

      `CSR_MENVCFG:        rdata = menvcfg;
      `CSR_MENVCFGH:       rdata = menvcfgh;
      `CSR_MCOUNTEREN:     rdata = mcounteren;
      `CSR_MCOUNTINHIBIT:  rdata = mcountinhibit;

      /* verilator lint_off WIDTHEXPAND */
      `CSR_MEDELEG:   rdata = medeleg & `MEDELEG_MASK;
      `CSR_MIDELEG:   rdata = mideleg & `MIDELEG_MASK;
      /* verilator lint_on WIDTHEXPAND */

      `CSR_MTIMECMP:   rdata = mtimecmp;
      `CSR_MTIMECMPH:  rdata = mtimecmph;

      // Supervisor Trap Setup and Handling
      `CSR_SSTATUS:      rdata = mstatus & `SSTATUS_MASK;
      `CSR_SSCRATCH:     rdata = sscratch;
      `CSR_SIE:          rdata = mie & `SIE_MASK;
      `CSR_SIP:          rdata = mip & `SIP_MASK;
      `CSR_STVEC:        rdata = stvec;
      `CSR_SEPC:         rdata = sepc;
      `CSR_SCAUSE:       rdata = scause;
      `CSR_STVAL:        rdata = stval;
      `CSR_SATP:         rdata = satp;
      `CSR_STIMECMP:     rdata = stimecmp;
      `CSR_STIMECMPH:    rdata = stimecmph;
      `CSR_SCOUNTEREN:   rdata = scounteren;

      default: begin
        csr_not_exist = 1'b1;
      end
    endcase
  end

  // Function to calculate exception PC based on mode.
  function automatic [31:0] calculate_exception_pc (
      input [1:0] mode,
      input [31:0] base_addr,
      input [31:0] cause_
  );
    begin
      case (mode)
        2'b00:  // Direct mode
          calculate_exception_pc = base_addr;
        2'b01:  // Vectored mode
          calculate_exception_pc = base_addr | (cause_ << 2);
        default: // Reserved mode (treated as direct mode in this example)
          calculate_exception_pc = base_addr;
      endcase
    end
  endfunction

  // Internal signals for interrupt and CSR update handling.
  logic [31:0] deleg;
  logic [31:0] mask;
  logic [31:0] pending_irqs;
  logic [31:0] temp_mip;
  logic [31:0] temp_restricted;
  logic [31:0] temp_xstatus;
  logic [31:0] wdata_nxt;

  logic m_enabled;
  logic s_enabled;

  logic [31:0] m_interrupts;
  logic [31:0] s_interrupts;
  logic [31:0] interrupts;

  /* verilator lint_off WIDTHEXPAND */
  /* verilator lint_off WIDTHTRUNC */
  wire [`MSTATUS_MPP_WIDTH -1:0] y;
  assign y = `GET_MSTATUS_MPP(mstatus);
  /* verilator lint_on WIDTHTRUNC */
  /* verilator lint_on WIDTHEXPAND */

  // Combinational logic to update next state values.
  always_comb begin
    mstatus_nxt       = mstatus;
    mscratch_nxt      = mscratch;
    mie_nxt           = mie;
    mip_nxt           = mip;
    mtvec_nxt         = mtvec;
    mepc_nxt          = mepc;
    mcause_nxt        = mcause;
    mtval_nxt         = mtval;

    menvcfg_nxt       = menvcfg;
    menvcfgh_nxt      = menvcfgh;
    mcounteren_nxt    = mcounteren;
    mcountinhibit_nxt = mcountinhibit;

    medeleg_nxt       = medeleg;
    mideleg_nxt       = mideleg;

    mtimecmp_nxt      = mtimecmp;
    mtimecmph_nxt     = mtimecmph;

    temp_restricted   = 0;
    sscratch_nxt      = sscratch;
    stvec_nxt         = stvec;
    sepc_nxt          = sepc;
    scause_nxt        = scause;
    stval_nxt         = stval;
    satp_nxt          = satp;

    stimecmp_nxt      = stimecmp;
    stimecmph_nxt     = stimecmph;
    scounteren_nxt    = scounteren;

    deleg             = 0;
    mask              = 0;
    exception_next_pc_nxt = exception_next_pc;
    exception_select_nxt  = 1'b0;
    privilege_mode_nxt     = privilege_mode;
    temp_xstatus      = 0;

    // Compute the new write data based on CSR operation.
    wdata_nxt = is_csr_clear ? (rdata & ~wdata) : (is_csr_set ? (rdata | wdata) : wdata);

    temp_mip = 0;
    tlb_flush = 1'b0;

    if (exception_event) begin
      mask  = 1 << `GET_MCAUSE_CAUSE(cause);
      deleg = `IS_MCAUSE_INTERRUPT(cause) ? mideleg : medeleg;

      if ((`IS_USER(privilege_mode) || `IS_SUPERVISOR(privilege_mode)) && (|(deleg & mask))) begin
        // Update status for Supervisor trap.
        temp_xstatus = (mstatus & ~(`XSTATUS_SIE_MASK | `XSTATUS_SPIE_MASK | `XSTATUS_SPP_MASK));
        mstatus_nxt = temp_xstatus |
                      `SET_XSTATUS_SPIE(`GET_XSTATUS_SIE(mstatus)) |
                      `SET_XSTATUS_SIE(1'b0) |
                      `SET_XSTATUS_SPP(`IS_SUPERVISOR(privilege_mode));
        privilege_mode_nxt = `PRIVILEGE_MODE_SUPERVISOR;
        sepc_nxt = pc;
        scause_nxt = cause;
        exception_next_pc_nxt = calculate_exception_pc(stvec[1:0], {stvec[31:2], 2'b0}, cause);
        stval_nxt = badaddr;
        exception_select_nxt = 1'b1;
      end else begin
        // Update status for Machine trap.
        temp_xstatus = (mstatus & ~(`MSTATUS_MIE_MASK | `MSTATUS_MPIE_MASK | `MSTATUS_MPP_MASK));
        mstatus_nxt = temp_xstatus |
                      `SET_MSTATUS_MPIE(`GET_MSTATUS_MIE(mstatus)) |
                      `SET_MSTATUS_MIE(1'b0) |
                      `SET_MSTATUS_MPP(privilege_mode);
        privilege_mode_nxt = `PRIVILEGE_MODE_MACHINE;
        mepc_nxt = pc;
        mcause_nxt = cause;
        exception_next_pc_nxt = calculate_exception_pc(mtvec[1:0], {mtvec[31:2], 2'b0}, cause);
        mtval_nxt = badaddr;
        exception_select_nxt = 1'b1;
      end

    end else if (mret) begin
      // Machine return handling.
      temp_xstatus = (mstatus & ~(`MSTATUS_MIE_MASK | `MSTATUS_MPIE_MASK | `MSTATUS_MPP_MASK | ((!`IS_MACHINE(y)) << `MSTATUS_MPRV_BIT)));
      mstatus_nxt = temp_xstatus |
                    `SET_MSTATUS_MIE(`GET_MSTATUS_MPIE(mstatus)) |
                    `SET_MSTATUS_MPIE(1'b1) |
                    `SET_MSTATUS_MPP(`PRIVILEGE_MODE_USER);
      privilege_mode_nxt = y;
      exception_next_pc_nxt = mepc;
      exception_select_nxt = 1'b1;
    end else if (sret) begin
      // Supervisor return handling.
      temp_xstatus = (mstatus & ~(`XSTATUS_SIE_MASK | `XSTATUS_SPIE_MASK | `XSTATUS_SPP_MASK | ((!`IS_MACHINE(y)) << `MSTATUS_MPRV_BIT)));
      mstatus_nxt = temp_xstatus |
                    `SET_XSTATUS_SIE(`GET_XSTATUS_SPIE(mstatus)) |
                    `SET_XSTATUS_SPIE(1'b1) |
                    `SET_XSTATUS_SPP(1'b0);
      privilege_mode_nxt = `GET_XSTATUS_SPP(mstatus);
      exception_next_pc_nxt = sepc;
      exception_select_nxt = 1'b1;
    end else if (csr_write_valid) begin
      // CSR write operations.
      case (CSRAddr)
        `CSR_MSTATUS:        mstatus_nxt = wdata_nxt;
        `CSR_MSCRATCH:       mscratch_nxt = wdata_nxt;
        `CSR_MIE:            mie_nxt = wdata_nxt;
        `CSR_MIP:            mip_nxt = wdata_nxt;
        `CSR_MTVEC:          mtvec_nxt = wdata_nxt;
        `CSR_MEPC:           mepc_nxt = wdata_nxt;
        `CSR_MCAUSE:         mcause_nxt = wdata_nxt;
        `CSR_MTVAL:          mtval_nxt = wdata_nxt;

        `CSR_MENVCFG:        menvcfg_nxt = wdata_nxt;
        `CSR_MENVCFGH:       menvcfgh_nxt = wdata_nxt;
        `CSR_MCOUNTEREN:     mcounteren_nxt = wdata_nxt;
        `CSR_MCOUNTINHIBIT:  mcountinhibit_nxt = wdata_nxt;

        `CSR_MEDELEG:        medeleg_nxt = wdata_nxt & `MEDELEG_MASK;
        `CSR_MIDELEG:        mideleg_nxt = wdata_nxt & `MIDELEG_MASK;

        `CSR_MTIMECMP:       mtimecmp_nxt = wdata_nxt;
        `CSR_MTIMECMPH:      mtimecmph_nxt = wdata_nxt;

        `CSR_SSTATUS: begin
          temp_restricted = mstatus & ~(`SSTATUS_MASK);
          mstatus_nxt = temp_restricted | (wdata_nxt & `SSTATUS_MASK);
        end
        `CSR_SSCRATCH:       sscratch_nxt = wdata_nxt;
        `CSR_SIE: begin
          temp_restricted = mie & ~(`SIE_MASK);
          mie_nxt = temp_restricted | (wdata_nxt & `SIE_MASK);
        end
        `CSR_SIP: begin
          temp_restricted = mip & ~(`SIP_MASK);
          mip_nxt = temp_restricted | (wdata_nxt & `SIP_MASK);
        end
        `CSR_STVEC:          stvec_nxt = wdata_nxt;
        `CSR_SEPC:           sepc_nxt = wdata_nxt;
        `CSR_SCAUSE:         scause_nxt = wdata_nxt;
        `CSR_STVAL:          stval_nxt = wdata_nxt;
        `CSR_SATP: begin
          tlb_flush = 1'b1;
          satp_nxt  = wdata_nxt;
        end
        `CSR_STIMECMP:       stimecmp_nxt = wdata_nxt;
        `CSR_STIMECMPH:      stimecmph_nxt = wdata_nxt;
        `CSR_SCOUNTEREN:     scounteren_nxt = wdata_nxt;
        default: ;
        // fixme: exception handling for undefined CSR writes.
      endcase

    end else begin
      // Update mip for timer and interrupt signals.
      temp_mip = mip & ~(`MIP_MTIP_MASK | `MIP_MEIP_MASK | `XIP_SEIP_MASK |
                   (`CHECK_SSTC_CONDITIONS(menvcfgh, mcounteren) << `XIP_STIP_BIT));
      mip_nxt = temp_mip |
                `SET_MIP_MSIP(IRQ3) |
                `SET_XIP_STIP(`CHECK_SSTC_TM_AND_CMP(timer_counter, stimecmph, stimecmp, menvcfgh, mcounteren)) |
                `SET_MIP_MTIP(IRQ7) |
                `SET_MIP_MEIP(IRQ11) |
                `SET_XIP_SEIP(IRQ9);
    end

    pending_irqs = mip & mie;

    /* verilog_format: off */
    m_enabled = (!`IS_MACHINE(privilege_mode)) || (`IS_MACHINE(privilege_mode) && `GET_MSTATUS_MIE(mstatus));
    s_enabled = `IS_USER(privilege_mode) || (`IS_SUPERVISOR(privilege_mode) && `GET_XSTATUS_SIE(mstatus));
    /* verilog_format: on */

    m_interrupts = pending_irqs & (~mideleg) & {32{m_enabled}};
    s_interrupts = pending_irqs & (mideleg)  & {32{s_enabled}};
    interrupts  = (|m_interrupts ? m_interrupts : s_interrupts);

    IRQ_TO_CPU_CTRL1 = `GET_XIP_SSIP(interrupts);
    IRQ_TO_CPU_CTRL3 = `GET_MIP_MSIP(interrupts);
    IRQ_TO_CPU_CTRL5 = `GET_XIP_STIP(interrupts);
    IRQ_TO_CPU_CTRL7 = `GET_MIP_MTIP(interrupts);
    IRQ_TO_CPU_CTRL9 = `GET_XIP_SEIP(interrupts);
    IRQ_TO_CPU_CTRL11 = `GET_MIP_MEIP(interrupts);
  end

endmodule

