// RISC-V Main Finite State Machine (FSM) - SystemVerilog Implementation
//
// This module implements the main control finite state machine (FSM) for the RISC-V
// Harris multicycle RV32IMA processor. It orchestrates instruction fetch, decode,
// execution, memory access, and writeback stages.
//
// Features:
// - Supports RISC-V instruction types: R-type, I-type, S-type, B-type, J-type, and U-type.
// - Manages control signals for ALU operations, memory access, and CSR operations.
// - Handles unaligned memory accesses, page faults, and other exceptions.
// - Includes support for Atomic Memory Operations (AMO) and privileged instructions.
//
// Copyright (c) 2022/2023/2024 Hirosh Dabui <hirosh@dabui.de>
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
`default_nettype none
`timescale 1 ns / 100 ps
`include "riscv_defines.svh"

module main_fsm (
        input  logic                        clk,
        input  logic                        resetn,
        input  logic [                 6:0] op,
        input  logic [                 6:0] funct7,
        input  logic [                 2:0] funct3,
        input  logic [                 4:0] Rs1,
        input  logic [                 4:0] Rs2,
        input  logic [                 4:0] Rd,
        input  logic                        Zero,
        output logic                        AdrSrc,
        output logic                        fetched_instr,
        output logic                        incr_inst_retired,
        output logic [`SRCA_WIDTH     -1:0] ALUSrcA,
        output logic [`SRCB_WIDTH     -1:0] ALUSrcB,
        output logic [`ALU_OP_WIDTH   -1:0] ALUOp,
        output logic [`AMO_OP_WIDTH   -1:0] AMOop,
        output logic [`RESULT_WIDTH   -1:0] ResultSrc,
        output logic [                 2:0] ImmSrc,
        output logic                        CSRvalid,
        output logic                        PCUpdate,
        output logic                        Branch,
        output logic                        RegWrite,
        output logic                        MemWrite,
        input  logic                        unaligned_access_load,
        input  logic                        unaligned_access_store,
        input  logic                        access_fault,
        output logic                        ALUOutWrite,
        output logic                        mem_valid,
        output logic                        amo_temp_write_operation,
        // AMO
        output logic                        amo_data_load,
        output logic                        amo_operation_store,
        output logic                        muxed_Aluout_or_amo_rd_wr,
        output logic                        amo_set_reserved_state_load,
        output logic                        amo_buffered_data,
        output logic                        amo_buffered_address,
        output logic                        select_ALUResult,
        output logic                        select_amo_temp,
        input  logic                        amo_reserved_state_load,

        // Exception Handler
        output logic                        exception_event,
        output logic [31:0]                 cause,
        output logic [31:0]                 badaddr,
        output logic                        mret,
        output logic                        wfi_event,
        input  logic [1:0]                  privilege_mode,
        input  logic                        csr_access_fault,
        input  logic [31:0]                 mie,
        input  logic [31:0]                 mip,
        input  logic [31:0]                 mstatus,

        output logic                        mul_ext_valid,
        input  logic                        mul_ext_ready,

        input  logic                        mem_ready
    );
    // S0  --> Fetch
    // S1  --> Decode
    // S2  --> MemAddr
    // S3  --> MemRead
    // S4  --> MemWb
    // S5  --> MemWrite
    // S6  --> ExecuteR
    // S7  --> AluWB
    // S8  --> ExecuteI
    // S9  --> J-TYPE
    // S10 --> B-TYPE
    // S11 --> JALR
    // S12 --> LUI
    // S13 --> AUPIC
    // S14 --> ExecuteMul
    // S15 --> MulWB
    // S16 --> ExecuteSystem
    // S17 --> SystemWB
    //
    // amo stuff
    // amo memaddr
    // amoLoadLR
    // -> S18 (mem addr)
    // -> S19 (load)
    // -> S20 (LoadLR wb)
    // amoStoreSC
    // -> S18 (mem addr) if r; S21; e; S23
    // -> S21 (store) -> S22 -> S0
    // -> S23 -> S0 -> S0
    //
    // amo op: S0 (is amo)
    // amo
    // tmp = mem[rs1d]
    // mem[rs1d] = tmp & rs2d;
    // rd = tmp
    // -> S18 (mem addr)
    // -> S24 (amo load)
    // -> S25 (wb)
    // -> S26 (alu exec amo)
    // -> S27 (mem addr)
    // -> S28 (mem write)
    // -> s29 -> s0

    logic funct7b5 = funct7[5];  // r-type
    logic funct7b0 = funct7[0];  // r-type
    logic [4:0] funct5 = funct7[6:2];

    localparam    S0 = 0, S1 = 1, S2 = 2, S3 = 3, S4 = 4, S5 = 5,
                  S6 = 6, S7 = 7, S8 = 8, S9 = 9, S10 = 10, S11 = 11,
                  S12 = 12, S13 = 13, S14 = 14, S15 = 15, S16 = 16, S17 = 17,
                  S18 = 18, S19 = 19, S20 = 20, S21 = 21, S22 = 22, S23 = 23,
                  S24 = 24, S25 = 25, S26 = 26, S27 = 27, S28 = 28, S29 = 29,
                  S30 = 30, S31 = 31, S32 = 32, S33 = 33, S34 = 34, S35 = 35, S36 = 36,
                  S37 = 37, S38 = 38, S39 = 39, S40 = 40, S41 = 41, S42 = 42, S43 = 43,
                  S44 = 44, S45 = 45, S46 = 46, S47 = 47, S48 = 48, S49 = 49, S_LAST = 50; // fixme

    logic [$clog2(S_LAST)-1:0] state, next_state;

    localparam      load    = 7'b0000011,
                    store   = 7'b0100011,
                    rtype   = 7'b0110011,
                    itype   = 7'b0010011,
                    jal     = 7'b1101111,  // j-type
                    jalr    = 7'b1100111,  // implicit i-type
                    branch  = 7'b1100011,
                    lui     = 7'b0110111,  // u-type
                    aupic   = 7'b0010111,  // u-type
                    amo     = 7'b0101111;

    // Determine if the instruction is a CSR type using assign statement
    logic is_csr = (op == `CSR_OPCODE) && (funct3 == `CSR_FUNCT3_RW    ||
                                           funct3 == `CSR_FUNCT3_RS    ||
                                           funct3 == `CSR_FUNCT3_RC    ||
                                           funct3 == `CSR_FUNCT3_RWI   ||
                                           funct3 == `CSR_FUNCT3_RSI   ||
                                           funct3 == `CSR_FUNCT3_RCI);

    logic is_load = (op == load);
    logic is_store = (op == store);
    logic is_rtype = (op == rtype);
    logic is_itype = (op == itype);
    logic is_jal = (op == jal);
    logic is_jalr = (op == jalr);
    logic is_branch = (op == branch);
    logic is_lui = (op == lui);
    logic is_aupic = (op == aupic);
    logic is_amo = `RV32_IS_AMO_INSTRUCTION(op, funct3);
    logic is_amoadd_w = `RV32_IS_AMOADD_W(funct5);
    logic is_amoswap_w = `RV32_IS_AMOSWAP_W(funct5);
    logic is_amo_lr_w = `RV32_IS_LR_W(funct5);
    logic is_amo_sc_w = `RV32_IS_SC_W(funct5);
    logic is_amoxor_w = `RV32_IS_AMOXOR_W(funct5);
    logic is_amoand_w = `RV32_IS_AMOAND_W(funct5);
    logic is_amoor_w = `RV32_IS_AMOOR_W(funct5);
    logic is_amomin_w = `RV32_IS_AMOMIN_W(funct5);
    logic is_amomax_w = `RV32_IS_AMOMAX_W(funct5);
    logic is_amominu_w = `RV32_IS_AMOMINU_W(funct5);
    logic is_amomaxu_w = `RV32_IS_AMOMAXU_W(funct5);
    logic is_fence = `RV32_IS_FENCE(op);
    logic is_ebreak = `IS_EBREAK(op, funct3, funct7, Rs1, Rs2, Rd);
    logic is_ecall = `IS_ECALL(op, funct3, funct7, Rs1, Rs2, Rd);
    logic is_mret = `IS_MRET(op, funct3, funct7, Rs1, Rs2, Rd);
    logic is_wfi = `IS_WFI(op, funct3, funct7, Rs1, Rs2, Rd);

    // ===========================================================================

    // amo
    always_comb begin
        amo_data_load = is_amo & is_amo_lr_w;
        amo_operation_store = is_amo & is_amo_sc_w;
    end

    always_comb begin
        unique case (1'b1)
            is_amoadd_w  : AMOop = `AMO_OP_ADD_W;
            is_amoswap_w : AMOop = `AMO_OP_SWAP_W;
            is_amo_lr_w  : AMOop = `AMO_OP_LR_W;
            is_amo_sc_w  : AMOop = `AMO_OP_SC_W;
            is_amoxor_w  : AMOop = `AMO_OP_XOR_W;
            is_amoand_w  : AMOop = `AMO_OP_AND_W;
            is_amoor_w   : AMOop = `AMO_OP_OR_W;
            is_amomin_w  : AMOop = `AMO_OP_MIN_W;
            is_amomax_w  : AMOop = `AMO_OP_MAX_W;
            is_amominu_w : AMOop = `AMO_OP_MINU_W;
            is_amomaxu_w : AMOop = `AMO_OP_MAXU_W;
            default:       AMOop = 'hx;
        endcase
    end

    assign ALUOutWrite = !mem_valid;

    always_comb begin
        unique case (1'b1)
            is_rtype:                              ImmSrc = `IMMSRC_RTYPE;
            is_itype, is_jalr, is_load, is_csr:    ImmSrc = `IMMSRC_ITYPE;
            is_store:                              ImmSrc = `IMMSRC_STYPE;
            is_branch:                             ImmSrc = `IMMSRC_BTYPE;
            is_lui, is_aupic:                     ImmSrc = `IMMSRC_UTYPE;
            is_jal:                                ImmSrc = `IMMSRC_JTYPE;
            default:                               ImmSrc = 3'bxxx;
        endcase
    end

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn)
            state <= S0;
        else
            state <= next_state;
    end

    // WIDTHTRUNC/WIDTHEXPAND pseudo in comments
    logic mtip_raised = `GET_MSTATUS_MIE(mstatus) & `GET_MIP_MTIP(mip) & `GET_MIE_MTIP(mie);
    logic msip_raised = `GET_MSTATUS_MIE(mstatus) & `GET_MIP_MSIP(mip) & `GET_MIE_MSIP(mie);

    always_comb begin
        next_state = S0;
        case (state)
            S0:  next_state = mem_ready ? S1 : S0;  // fetch
            S1:  begin
                if (mtip_raised || msip_raised) next_state = S36; //interrupt
                else if (is_load || is_store) next_state = S2;
                else if (is_rtype && !funct7b0) next_state = S6;  // reg op reg in common alu
                else if (is_rtype && funct7b0) next_state = S14;  // reg op reg in mul/div
                else if (is_itype) next_state = S8;
                else if (is_jal) next_state = S9;
                else if (is_jalr) next_state = S11;
                else if (is_branch) next_state = S10;
                else if (is_lui) next_state = S12;
                else if (is_aupic) next_state = S13;
                else if (is_csr) next_state = S16;
                else if (is_amo) next_state = S18;
                else if (is_fence) next_state = S0;  // fixme
                else if (is_wfi) next_state = S0;//S38; // fixme
                else if (is_mret) next_state = S30;
                else if (is_ecall) next_state = S34;
                else if (is_ebreak) next_state = S39; // fixme;
                else next_state = S40; // illegal;
            end
            S2:  begin
                if (is_load) next_state  = access_fault ? S46 : (unaligned_access_load  ? S42 : S3);
                if (is_store) next_state = access_fault ? S48 : (unaligned_access_store ? S44 : S5);
            end
            S3:  next_state = mem_ready ? S4 : S3;
            S4:  next_state = S0;
            S5:  next_state = mem_ready ? S0 : S5;
            S6:  next_state = S7;
            S7:  next_state = S0;
            S8:  next_state = S7;
            S9:  next_state = S7;
            S10: next_state = S0;
            S11: next_state = S9;
            S12: next_state = S7;
            S13: next_state = S7;
            S14: next_state = mul_ext_ready ? S15 : S14;
            S15: next_state = S0;
            S16: next_state = csr_access_fault ? S32 : S17;
            S17: next_state = S0;

            S18: begin
                if (is_amo_lr_w)
                    next_state = access_fault ? S46 : (unaligned_access_load ? S42 : S19);
                if (is_amo_sc_w)
                    next_state = access_fault ? S48 : (unaligned_access_store ? S44 : (amo_reserved_state_load ? S21 : S23));
                if (is_amoadd_w || is_amoswap_w || is_amoxor_w || is_amoand_w ||
                    is_amoor_w || is_amomin_w || is_amomax_w || is_amominu_w || is_amomaxu_w)
                    next_state = access_fault ? S46 : (unaligned_access_load ? S42 : S24);
            end

            S19: next_state = mem_ready ? S20 : S19;
            S20: next_state = S0;
            S21: next_state = mem_ready ? S22 : S21;
            S22: next_state = S0;
            S23: next_state = S0;
            S24: next_state = mem_ready ? S25 : S24;
            S25: next_state = S26;
            S26: next_state = S27;
            S27: next_state = unaligned_access_store ? S42 : S28;
            S28: next_state = mem_ready ? S0 : S28;
            S29: next_state = S0;
            S30: next_state = S31;
            S31: next_state = S0;
            S32: next_state = S33;
            S33: next_state = S0;
            S34: next_state = S35;
            S35: next_state = S0;
            S36: next_state = S37;
            S37: next_state = S0;
            S38: next_state = S0;
            S39: next_state = S39;
            S40: next_state = S41;
            S41: next_state = S0;
            S42: next_state = S43;
            S43: next_state = S0;
            S44: next_state = S45;
            S45: next_state = S0;
            S46: next_state = S47;
            S47: next_state = S0;
            S48: next_state = S49;
            S49: next_state = S0;

            default: next_state = S0;
        endcase
    end

    always_comb begin
        incr_inst_retired          = 1'b0;
        AdrSrc                     = `ADDR_PC;
        fetched_instr              = 1'b0;
        ALUSrcA                    = `SRCA_PC;
        ALUSrcB                    = `SRCB_RD2_BUF;
        ALUOp                      = `ALU_OP_ADD;
        ResultSrc                  = `RESULT_ALUOUT;
        PCUpdate                   = 1'b0;
        Branch                     = 1'b0;
        RegWrite                   = 1'b0;
        MemWrite                   = 1'b0;
        CSRvalid                   = 1'b0;
        select_ALUResult           = 1'b0;

        amo_temp_write_operation   = 1'b0;
        amo_set_reserved_state_load= 1'b0;
        amo_buffered_data          = 1'b0;
        amo_buffered_address       = 1'b0;
        select_amo_temp            = 1'b0;
        muxed_Aluout_or_amo_rd_wr  = 1'b0;

        mem_valid                  = 1'b0;
        mul_ext_valid              = 1'b0;

        exception_event            = 1'b0;
        cause                      = 32'b0;
        badaddr                    = 32'b0;
        mret                       = 1'b0;
        wfi_event                  = 1'b0;

        case (state)
            S0: begin
                mem_valid     = 1'b1;
                AdrSrc        = `ADDR_PC;
                fetched_instr = mem_ready;
                ALUSrcA       = `SRCA_PC;
                ALUSrcB       = `SRCB_CONST_4;
                ALUOp         = `ALU_OP_ADD;
                ResultSrc     = `RESULT_ALURESULT;
                PCUpdate      = mem_ready;
            end
            S1: begin
                ALUSrcA = `SRCA_OLD_PC;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_ADD;
            end
            S2: begin
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_ADD;
            end
            S3: begin
                mem_valid = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                AdrSrc    = `ADDR_RESULT;
            end
            S4: begin
                mem_valid = 1'b1;
                ResultSrc = `RESULT_DATA;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S5: begin
                mem_valid = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                AdrSrc    = `ADDR_RESULT;
                MemWrite  = 1'b1;
                incr_inst_retired = mem_ready;
            end
            S6: begin
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_RD2_BUF;
                ALUOp   = `ALU_OP_ARITH_LOGIC;
            end
            S7: begin
                mem_valid = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S8: begin
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_ARITH_LOGIC;
            end
            S9: begin
                ALUSrcA   = `SRCA_OLD_PC;
                ALUSrcB   = `SRCB_CONST_4;
                ALUOp     = `ALU_OP_ADD;
                ResultSrc = `RESULT_ALUOUT;
                PCUpdate  = 1'b1;
            end
            S10: begin
                ALUSrcA   = `SRCA_RD1_BUF;
                ALUSrcB   = `SRCB_RD2_BUF;
                ALUOp     = `ALU_OP_BRANCH;
                ResultSrc = `RESULT_ALUOUT;
                Branch    = 1'b1;
                mem_valid = Zero;
                incr_inst_retired = 1'b1;
            end
            S11: begin
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_ADD;
            end
            S12: begin
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_LUI;
            end
            S13: begin
                ALUSrcA = `SRCA_OLD_PC;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_AUIPC;
            end
            S14: begin
                ALUSrcA       = `SRCA_RD1_BUF;
                ALUSrcB       = `SRCB_RD2_BUF;
                mul_ext_valid = 1'b1;
            end
            S15: begin
                mem_valid = 1'b1;
                ResultSrc = `RESULT_MULOUT;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S16: begin
                ALUSrcA  = `SRCA_RD1_BUF;
                ALUSrcB  = `SRCB_IMM_EXT;
                CSRvalid = 1'b1;
            end
            S17: begin
                mem_valid = 1'b1;
                ResultSrc = `RESULT_CSROUT;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S18: begin
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_CONST_0;
                ALUOp   = `ALU_OP_ADD;
                amo_buffered_address = 1'b1;
            end
            S19: begin
                amo_set_reserved_state_load = 1'b1;
                amo_buffered_data = 1'b1;
                mem_valid = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                AdrSrc = `ADDR_RESULT;
            end
            S20: begin
                mem_valid = 1'b1;
                ResultSrc = `RESULT_DATA;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S21: begin
                amo_set_reserved_state_load = 1'b1;
                amo_buffered_data = 1'b0;
                mem_valid = 1'b1;
                ResultSrc = `RESULT_AMO_TEMP_ADDR;
                AdrSrc    = `ADDR_RESULT;
                MemWrite  = 1'b1;
            end
            S22: begin
                amo_buffered_data = 1'b0;
                muxed_Aluout_or_amo_rd_wr = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                RegWrite = 1'b1;
                mem_valid = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S23: begin
                amo_buffered_data = 1'b1;
                muxed_Aluout_or_amo_rd_wr = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                RegWrite = 1'b1;
                mem_valid = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S24: begin
                mem_valid = 1'b1;
                AdrSrc = `ADDR_RESULT;
                ResultSrc = `RESULT_ALUOUT;
                amo_temp_write_operation = 1'b1;
            end
            S25: begin
                ALUOp = `ALU_OP_ADD;
                ALUSrcA = `SRCA_AMO_TEMP_DATA;
                ALUSrcB = `SRCB_CONST_0;
                ResultSrc = `RESULT_DATA;
                RegWrite = 1'b1;
            end
            S26: begin
                ALUOp = `ALU_OP_AMO;
                ALUSrcA = is_amoswap_w ? `SRCA_CONST_0 : `SRCA_AMO_TEMP_DATA;
                ALUSrcB = `SRCB_RD2_BUF;
                ResultSrc = `RESULT_ALURESULT;
                select_ALUResult = 1'b1;
                amo_temp_write_operation = 1'b1;
            end
            S27: begin
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_CONST_0;
                ALUOp   = `ALU_OP_ADD;
            end
            S28: begin
                MemWrite = 1'b1;
                select_amo_temp = 1'b1;
                ResultSrc = `RESULT_AMO_TEMP_ADDR;
                AdrSrc    = `ADDR_RESULT;
                mem_valid = 1'b1;
                incr_inst_retired = mem_ready;
            end
            S29: begin
                mem_valid = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S30: begin
                mret = 1'b1;
            end
            S31: begin
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S32: begin
                cause = `EXC_ILLEGAL_INSTRUCTION;
                badaddr = {25'b0, op};
                exception_event = 1'b1;
            end
            S33: begin
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S34: begin
                cause = `EXC_ECALL_FROM_UMODE;
                cause = {cause[31:2], privilege_mode};
                badaddr = 0;
                exception_event = 1'b1;
            end
            S35: begin
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S36: begin
                cause = mtip_raised ? `INTERRUPT_MACHINE_TIMER : `INTERRUPT_MACHINE_SOFTWARE;
                badaddr = 0;
                exception_event = 1'b1;
            end
            S37: begin
                PCUpdate = 1'b1;
            end
            S38: begin
                wfi_event = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S39: begin
                // ebreak
            end
            S40: begin
                cause = `EXC_ILLEGAL_INSTRUCTION;
                badaddr = ~0;
                exception_event = 1'b1;
            end
            S41: begin
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S42: begin
                cause = `EXC_LOAD_AMO_ADDR_MISALIGNED;
                badaddr = ~0;
                exception_event = 1'b1;
            end
            S43: begin
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S44: begin
                cause = `EXC_STORE_AMO_ADDR_MISALIGNED;
                badaddr = ~0;
                exception_event = 1'b1;
            end
            S45: begin
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S46: begin
                cause = `EXC_LOAD_AMO_ACCESS_FAULT;
                badaddr = ~0;
                exception_event = 1'b1;
            end
            S47: begin
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S48: begin
                cause = `EXC_STORE_AMO_ACCESS_FAULT;
                badaddr = ~0;
                exception_event = 1'b1;
            end
            S49: begin
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            default: begin
                AdrSrc     = 'b0;
                ALUSrcA    = 'b0;
                ALUSrcB    = 'b0;
                ALUOp      = 'b0;
                PCUpdate   = 'b0;
                Branch     = 'b0;
                ResultSrc  = `RESULT_ALUOUT;
                RegWrite   = 'b0;
                MemWrite   = 'b0;
            end
        endcase
    end
endmodule
