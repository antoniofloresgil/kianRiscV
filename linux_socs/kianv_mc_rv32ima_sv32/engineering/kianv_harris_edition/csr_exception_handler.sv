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
    parameter MTVEC_INIT = 32'h0000_0000
) (
    input wire                     clk,
    input wire                     resetn,
    input wire                     incr_inst_retired,
    input wire [11:0]             CSRAddr,
    input wire [`CSR_OP_WIDTH-1:0] CSRop,
    input wire                     we,
    input wire                     re,
    input wire [31:0]             Rd1,
    input wire [4:0]              uimm,
    input wire                     exception_event,
    input wire                     mret,
    input wire                     wfi_event,
    input wire [31:0]             cause,
    input wire [31:0]             pc,
    input wire [31:0]             badaddr,
    output logic [31:0]             rdata,
    output logic [31:0]             exception_next_pc,
    output logic                     exception_select,
    output logic [1:0]              privilege_mode,
    output logic                     csr_access_fault,
    output logic [31:0]             mstatus,
    output logic [31:0]             mie,
    output logic [31:0]             mip,
    input wire                     IRQ3,
    input wire                     IRQ7
);

    logic is_reg_operand;
    assign is_reg_operand = CSRop == `CSR_OP_CSRRW || CSRop == `CSR_OP_CSRRS || CSRop == `CSR_OP_CSRRC;

    // Extract privilege level from CSR address (bits [9:8])
    // Check if the CSR is read-only by examining bits [11:10] of CSR address
    logic [1:0] csr_privilege_level = CSRAddr[9:8];
    logic csr_read_only = (CSRAddr[11:10] == 2'b11);
    assign csr_access_fault = (privilege_mode < csr_privilege_level) || (we & csr_read_only);

    logic [31:0] extended_uimm;
    assign extended_uimm = {{27{1'b0}}, uimm};
    logic [31:0] wdata;
    assign wdata = is_reg_operand ? Rd1 : extended_uimm;

    // CSR
    // csr rdcycle[H], rdtime[H], rdinstret[H]
    logic [63:0] cycle_counter;
    logic [63:0] instr_counter;

    logic increase_instruction = incr_inst_retired;

    // Contadores
    counter #(64) instr_cnt_I (
        .resetn(resetn),
        .clk(clk),
        .increment(incr_inst_retired),
        .count(instr_counter)
    );

    counter #(64) cycle_cnt_I (
        .resetn(resetn),
        .clk(clk),
        .increment(1'b1),
        .count(cycle_counter)
    );

    logic [1:0] privilege_mode_nxt;

    logic [31:0] misa;
    logic [31:0] mscratch;
    logic [31:0] mtvec;
    logic [31:0] mepc;
    logic [31:0] mcause;
    logic [31:0] mtval;
    //    logic [31:0] mcounteren;

    logic [31:0] mstatus_nxt;
    logic [31:0] mscratch_nxt;
    logic [31:0] mie_nxt;
    logic [31:0] mtvec_nxt;
    logic [31:0] mepc_nxt;
    logic [31:0] mcause_nxt;
    logic [31:0] mtval_nxt;
    logic [31:0] mip_nxt;
    //    logic [31:0] mcounteren_nxt;

    logic [31:0] exception_next_pc_nxt;
    logic exception_select_nxt;

    logic is_csrrw = (CSRop == `CSR_OP_CSRRW);
    logic is_csrrs = (CSRop == `CSR_OP_CSRRS);
    logic is_csrrc = (CSRop == `CSR_OP_CSRRC);

    logic is_csrrwi = (CSRop == `CSR_OP_CSRRWI);
    logic is_csrrsi = (CSRop == `CSR_OP_CSRRSI);
    logic is_csrrci = (CSRop == `CSR_OP_CSRRCI);

    logic is_csr_set;
    assign is_csr_set = is_csrrs || is_csrrsi;

    logic is_csr_clear;
    assign is_csr_clear = is_csrrc || is_csrrci;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            privilege_mode <= `PRIVILEGE_MODE_MACHINE;
            /* verilator lint_off WIDTHEXPAND */
            mstatus <= `SET_MSTATUS_MPP(0, `PRIVILEGE_MODE_MACHINE);
            /* verilator lint_on WIDTHEXPAND */
            mscratch <= 0;
            mie <= 0;
            mtvec <= MTVEC_INIT;
            mepc <= 0;
            mcause <= 0;
            mtval <= 0;
            mip <= 0;
            //            mcounteren <= 0;
            /* verilator lint_off WIDTHEXPAND */
            misa <= `SET_MISA_VALUE(`MISA_MXL_RV32) |
                 `MISA_EXTENSION_BIT(`MISA_EXTENSION_A) |
                 `MISA_EXTENSION_BIT(`MISA_EXTENSION_I) |
                 `MISA_EXTENSION_BIT(`MISA_EXTENSION_M) |
                 /* `MISA_EXTENSION_BIT(`MISA_EXTENSION_S) | */
                 `MISA_EXTENSION_BIT(`MISA_EXTENSION_U);
            /* verilator lint_on WIDTHEXPAND */
            exception_next_pc <= 0;
            exception_select <= 0;
        end else begin
            privilege_mode <= privilege_mode_nxt;
            mscratch <= mscratch_nxt;
            mie <= mie_nxt;
            mip <= mip_nxt;
            mtvec <= mtvec_nxt;
            mepc <= mepc_nxt;
            mcause <= mcause_nxt;
            mtval <= mtval_nxt;
            // mcounteren <= mcounteren_nxt;

            exception_next_pc <= exception_next_pc_nxt;
            exception_select <= exception_select_nxt;

            mstatus <= mstatus_nxt; // | ({31'b0, wfi_event} << 3);
        end
    end

    always_comb begin
        if (re) begin
            case (CSRAddr)
                `CSR_REG_INSTRET:   rdata = instr_counter[31:0];
                `CSR_REG_INSTRETH:  rdata = instr_counter[63:32];
                `CSR_REG_CYCLE:     rdata = cycle_counter[31:0];
                `CSR_REG_CYCLEH:    rdata = cycle_counter[63:32];
                `CSR_REG_TIME:      rdata = cycle_counter[31:0];
                `CSR_REG_TIMEH:     rdata = cycle_counter[63:32];

                `CSR_REG_MSTATUS:   rdata = mstatus;
                `CSR_REG_MSCRATCH:  rdata = mscratch;
                `CSR_REG_MISA:      rdata = misa;
                `CSR_REG_MIE:       rdata = mie;
                `CSR_REG_MTVEC:     rdata = mtvec;
                `CSR_REG_MEPC:      rdata = mepc;
                `CSR_REG_MCAUSE:    rdata = mcause;
                `CSR_REG_MTVAL:     rdata = mtval;
                `CSR_REG_MIP:       rdata = mip;
                // `CSR_REG_MCOUNTEREN: rdata = mcounteren;
                `CSR_REG_MHARTID:   rdata = 32'b0;
                `CSR_REG_MVENDORID: rdata = 32'h0;
                `CSR_REG_MARCHID:   rdata = 32'h2b;
                default:            rdata = 32'b0;
                // fixme exception
            endcase
        end else begin
            rdata = 32'b0;
        end
    end

    function automatic [31:0] calculate_exception_pc(
        input [1:0] mode,
        input [31:0] base_addr,
        input [31:0] cause_
    );
        begin
            case (mode)
                2'b00: // Direct mode
                    calculate_exception_pc = base_addr;
                2'b01: // Reserved mode (treated as direct mode in this example)
                    calculate_exception_pc = base_addr;
                2'b10: // Vectored mode
                    calculate_exception_pc = base_addr + (cause_ << 2); // fixme alu
                default: // Invalid mode value, handle the exception
                    // exception_controller(MCAUSE_ILLEGAL_INSTRUCTION, PC, csr_stvec);
                    calculate_exception_pc = base_addr;
            endcase
        end
    endfunction

    logic [31:0] wdata_nxt;
    logic [31:0] temp_mstatus;
    logic [31:0] temp_mip;

    /* verilator lint_off WIDTHEXPAND */
    /* verilator lint_off WIDTHTRUNC */
    wire [`MSTATUS_MPP_WIDTH -1:0] y = `GET_MSTATUS_MPP(mstatus);

    always_comb begin
        mstatus_nxt = mstatus;
        mscratch_nxt = mscratch;
        mie_nxt = mie;
        mtvec_nxt = mtvec;
        mepc_nxt = mepc;
        mcause_nxt = mcause;
        mtval_nxt = mtval;
        mip_nxt = mip;
        exception_next_pc_nxt = exception_next_pc;
        exception_select_nxt = 1'b0;
        privilege_mode_nxt = privilege_mode;
        temp_mstatus = 0;

        // fixme if (we & !rdonly)
        wdata_nxt = is_csr_clear ? (rdata & ~wdata) : (is_csr_set ? (rdata | wdata) : wdata);

        if (we && !mret && !exception_event && !csr_access_fault) begin
            case (CSRAddr)
                `CSR_REG_MSTATUS:    mstatus_nxt = wdata_nxt;
                `CSR_REG_MSCRATCH:   mscratch_nxt = wdata_nxt;
                `CSR_REG_MIE:        mie_nxt = wdata_nxt;
                `CSR_REG_MTVEC:      mtvec_nxt = wdata_nxt;
                `CSR_REG_MEPC:       mepc_nxt = wdata_nxt;
                //`CSR_REG_MCOUNTEREN: mcounteren_nxt = wdata_nxt;
                `CSR_REG_MCAUSE:     mcause_nxt = wdata_nxt;
                `CSR_REG_MTVAL:      mtval_nxt = wdata_nxt;
                `CSR_REG_MIP:        mip_nxt = wdata_nxt;
                default:             ;
                // fixme exception
            endcase
        end

        if (exception_event) begin
            temp_mstatus = (mstatus & ~(`MSTATUS_MIE_MASK | `MSTATUS_MPIE_MASK | `MSTATUS_MPP_MASK));

            mstatus_nxt = (temp_mstatus
                           | `SET_MSTATUS_MPIE(temp_mstatus, `GET_MSTATUS_MIE(mstatus))
                           | `SET_MSTATUS_MIE(temp_mstatus, 1'b0)
                           | `SET_MSTATUS_MPP(temp_mstatus, privilege_mode));

            privilege_mode_nxt = `PRIVILEGE_MODE_MACHINE;
            mepc_nxt = pc;
            mcause_nxt = cause;
            exception_next_pc_nxt = calculate_exception_pc(mtvec[1:0], {mtvec[31:2], 2'b0}, cause);
            mtval_nxt = &badaddr ? pc : badaddr; // if ~0 then pc
            exception_select_nxt = 1'b1;
        end

        if (mret) begin
            temp_mstatus = (mstatus & ~(`MSTATUS_MIE_MASK | `MSTATUS_MPIE_MASK | `MSTATUS_MPP_MASK | (!`IS_MACHINE(y) << `MSTATUS_MPRV_BIT)));

            mstatus_nxt = (temp_mstatus
                           | `SET_MSTATUS_MIE(temp_mstatus, `GET_MSTATUS_MPIE(mstatus))
                           | `SET_MSTATUS_MPIE(temp_mstatus, 1'b1)
                           | `SET_MSTATUS_MPP(temp_mstatus, `PRIVILEGE_MODE_USER));
            //  | (!`IS_MACHINE(y) << `MSTATUS_MPRV_BIT));

            privilege_mode_nxt = y;

            exception_next_pc_nxt = mepc;
            exception_select_nxt = 1'b1;
        end

        temp_mip = mip & ~(`MIP_MSIP_MASK | `MIP_MTIP_MASK);
        mip_nxt = `SET_MIP_MSIP(temp_mip, IRQ3) | `SET_MIP_MTIP(temp_mip, IRQ7);

        /* verilator lint_on WIDTHEXPAND */
        /* verilator lint_on WIDTHTRUNC */
    end

endmodule
