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
`include "riscv_defines.svh"

module main_fsm (
    input  logic                        clk,
    input  logic                        resetn,
    input  logic [6:0]                  op,
    input  logic [6:0]                  funct7,
    input  logic [2:0]                  funct3,
    input  logic [4:0]                  Rs1,
    input  logic [4:0]                  Rs2,
    input  logic [4:0]                  Rd,
    input  logic                        Zero,
    output logic                        AdrSrc,
    output logic                        store_instr,
    output logic                        incr_inst_retired,
    output logic  [`SRCA_WIDTH     -1:0] ALUSrcA,
    output logic  [`SRCB_WIDTH     -1:0] ALUSrcB,
    output logic  [`ALU_OP_WIDTH   -1:0] ALUOp,
    output logic  [`AMO_OP_WIDTH   -1:0] AMOop,
    output logic  [`RESULT_WIDTH   -1:0] ResultSrc,
    output logic  [2:0]                ImmSrc,
    output logic                        CSRvalid,
    output logic                        PCUpdate,
    output logic                        Branch,
    output logic                        RegWrite,
    output logic                        MemWrite,
    input  logic [31:0]                 fault_address,
    input  logic [31:0]                 cpu_mem_addr,
    input  logic                        is_instruction_unaligned,
    input  logic                        is_load_unaligned,
    input  logic                        is_store_unaligned,
    input  logic                        access_fault,
    input  logic                        page_fault,
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
    output logic                        sret,
    output logic                        wfi_event,
    output logic                        selectPC,
    output logic                        tlb_flush,
    input  logic [1:0]                  privilege_mode,
    input  logic                        csr_access_fault,

    input  logic                        IRQ_TO_CPU_CTRL1,  // SSIP
    input  logic                        IRQ_TO_CPU_CTRL3,  // MSIP
    input  logic                        IRQ_TO_CPU_CTRL5,  // STIP
    input  logic                        IRQ_TO_CPU_CTRL7,  // MTIP
    input  logic                        IRQ_TO_CPU_CTRL9,  // SEIP
    input  logic                        IRQ_TO_CPU_CTRL11, // MEIP

    output logic                        mul_ext_valid,
    input  logic                        mul_ext_ready,
    output logic                        is_instruction,
    input  logic                        stall,

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

  localparam S0 = 0, S1 = 1, S2 = 2, S3 = 3, S4 = 4, S5 = 5, S6 = 6, S7 = 7, S8 = 8, S9 = 9,
             S10 = 10, S11 = 11, S12 = 12, S13 = 13, S14 = 14, S15 = 15, S16 = 16, S17 = 17, S18 = 18, S19 = 19,
             S20 = 20, S21 = 21, S22 = 22, S23 = 23, S24 = 24, S25 = 25, S26 = 26, S27 = 27, S28 = 28, S29 = 29,
             S30 = 30, S31 = 31, S32 = 32, S33 = 33, S34 = 34, S35 = 35, S36 = 36, S37 = 37, S38 = 38, S39 = 39,
             S40 = 40, S41 = 41, S42 = 42, S43 = 43, S44 = 44, S45 = 45, S46 = 46, S47 = 47, S48 = 48, S49 = 49,
             S50 = 50, S51 = 51, S52 = 52, S53 = 53, S54 = 54, S55 = 55, S56 = 56, S57 = 57, S58 = 58, S59 = 59,
             S60 = 60, S61 = 61, S62 = 62, S_LAST = 63;

  logic [$clog2(S_LAST)-1:0] state, state_nxt;

  localparam load    = 7'b000_0011,
             store   = 7'b010_0011,
             rtype   = 7'b011_0011,
             itype   = 7'b001_0011,
             jal     = 7'b110_1111,  // j-type
             jalr    = 7'b110_0111,  // implicit i-type
             branch  = 7'b110_0011,
             lui     = 7'b011_0111,  // u-type
             aupic   = 7'b001_0111,  // u-type
             amo     = 7'b010_1111;

  logic is_csr = (op == `CSR_OPCODE) && (funct3 == `CSR_FUNCT3_RW    ||
                                          funct3 == `CSR_FUNCT3_RS || funct3 == `CSR_FUNCT3_RC   ||
                                          funct3 == `CSR_FUNCT3_RWI || funct3 == `CSR_FUNCT3_RSI ||
                                          funct3 == `CSR_FUNCT3_RCI /* && funct7 == 0 */);

  logic is_load   = (op == load);
  logic is_store  = (op == store);
  logic is_rtype  = (op == rtype);
  logic is_itype  = (op == itype);
  logic is_jal    = (op == jal);
  logic is_jalr   = (op == jalr);
  logic is_branch = (op == branch);
  logic is_lui    = (op == lui);
  logic is_aupic  = (op == aupic);
  logic is_amo    = `RV32_IS_AMO_INSTRUCTION(op, funct3);
  logic is_amoadd_w  = `RV32_IS_AMOADD_W(funct5);
  logic is_amoswap_w = `RV32_IS_AMOSWAP_W(funct5);
  logic is_amo_lr_w  = `RV32_IS_LR_W(funct5);
  logic is_amo_sc_w  = `RV32_IS_SC_W(funct5);
  logic is_amoxor_w  = `RV32_IS_AMOXOR_W(funct5);
  logic is_amoand_w  = `RV32_IS_AMOAND_W(funct5);
  logic is_amoor_w   = `RV32_IS_AMOOR_W(funct5);
  logic is_amomin_w  = `RV32_IS_AMOMIN_W(funct5);
  logic is_amomax_w  = `RV32_IS_AMOMAX_W(funct5);
  logic is_amominu_w = `RV32_IS_AMOMINU_W(funct5);
  logic is_amomaxu_w = `RV32_IS_AMOMAXU_W(funct5);
  logic is_fence     = `RV32_IS_FENCE(op, funct3);
  logic is_sfence_vma= `RV32_IS_SFENCE_VMA(op, funct3, funct7);
  logic is_fence_i   = `RV32_IS_FENCE_I(op, funct3);
  logic is_ebreak    = `IS_EBREAK(op, funct3, funct7, Rs1, Rs2, Rd);
  logic is_ecall     = `IS_ECALL(op, funct3, funct7, Rs1, Rs2, Rd);
  logic is_mret      = `IS_MRET(op, funct3, funct7, Rs1, Rs2, Rd);
  logic is_sret      = `IS_SRET(op, funct3, funct7, Rs1, Rs2, Rd);
  logic is_wfi       = `IS_WFI(op, funct3, funct7, Rs1, Rs2, Rd);

  // ===========================================================================

  // amo
  always_comb begin
    amo_data_load = is_amo & is_amo_lr_w;
    amo_operation_store = is_amo & is_amo_sc_w;
  end

  always_comb begin
    case (1'b1)
      is_amoadd_w  : begin
        /* verilator lint_off WIDTH */
        AMOop = `AMO_OP_ADD_W;
        /* verilator lint_on WIDTH */
      end
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
      default: begin
        /* verilator lint_off WIDTH */
        AMOop = 'hx;
        /* verilator lint_on WIDTH */
      end
    endcase
  end

  assign ALUOutWrite = !mem_valid;

  always_comb begin
    case (1'b1)
      is_rtype:                              ImmSrc = `IMMSRC_RTYPE;
      is_itype | is_jalr | is_load | is_csr: ImmSrc = `IMMSRC_ITYPE;
      is_store:                              ImmSrc = `IMMSRC_STYPE;
      is_branch:                             ImmSrc = `IMMSRC_BTYPE;
      is_lui | is_aupic:                     ImmSrc = `IMMSRC_UTYPE;
      is_jal:                                ImmSrc = `IMMSRC_JTYPE;
      default:                               ImmSrc = 3'bxxx;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!resetn) begin
      state <= S0;
    end else begin
      state <= (!stall ? state_nxt : state);
    end
  end

  logic [31:0] trap_addr, trap_addr_nxt;
  always_ff @(posedge clk) begin
    if (!resetn) begin
      trap_addr <= 0;
    end else begin
      trap_addr <= trap_addr_nxt;
    end
  end

  always_comb begin
    state_nxt = S0;
    is_instruction = 1'b0;
    trap_addr_nxt = trap_addr;

    case (state)
      S0: begin
        // fetch instruction
        trap_addr_nxt  = cpu_mem_addr;
        is_instruction = 1'b1;
        case (1'b1)
          is_instruction_unaligned: state_nxt = S58;
          page_fault: state_nxt = S52;
          mem_ready: state_nxt = access_fault ? S60 : S1;
          default: state_nxt = S0;
        endcase
      end
      S1: begin
        // decode
        case (1'b1)
          (IRQ_TO_CPU_CTRL1 || IRQ_TO_CPU_CTRL3 || IRQ_TO_CPU_CTRL5 || IRQ_TO_CPU_CTRL7 || IRQ_TO_CPU_CTRL9 || IRQ_TO_CPU_CTRL11):
            state_nxt = S36;
          (is_load || is_store): state_nxt = S2;
          (is_rtype && !funct7b0): state_nxt = S6;
          (is_rtype && funct7b0): state_nxt = S14;
          is_itype: state_nxt = S8;
          is_jal: state_nxt = S9;
          is_jalr: state_nxt = S11;
          is_branch: state_nxt = S10;
          is_lui: state_nxt = S12;
          is_aupic: state_nxt = S13;
          is_csr: state_nxt = S16;
          is_amo: state_nxt = S18;
          is_sfence_vma: state_nxt = S0;
          is_fence: state_nxt = S0;
          is_fence_i: state_nxt = S0;
          is_wfi: state_nxt = S0;
          is_mret: state_nxt = S30;
          is_sret: state_nxt = S50;
          is_ecall: state_nxt = S34;
          is_ebreak: state_nxt = S39;
          default: state_nxt = S40;  // Illegal or no condition met
        endcase
      end
      S2: begin
        // memaddr
        case (1'b1)
          is_load:  state_nxt = S3;
          is_store: state_nxt = S5;
          default:  state_nxt = S2;
        endcase
      end
      S3: begin
        // mem read
        trap_addr_nxt = cpu_mem_addr;
        case (1'b1)
          is_load_unaligned: state_nxt = S42;
          page_fault: state_nxt = S54;
          mem_ready: state_nxt = access_fault ? S46 : S4;
          default: state_nxt = S3;
        endcase
      end
      S4: begin
        is_instruction = 1'b1;
        state_nxt = S0;
      end
      S5: begin
        // mem store
        trap_addr_nxt = cpu_mem_addr;
        case (1'b1)
          is_store_unaligned: state_nxt = S44;
          page_fault: state_nxt = S56;
          mem_ready: state_nxt = access_fault ? S48 : S0;
          default: state_nxt = S5;
        endcase
      end
      S6:  state_nxt = S7;
      S7: begin
        is_instruction = 1'b1;
        state_nxt = S0;
      end
      S8:  state_nxt = S7;
      S9:  state_nxt = S7;
      S10: begin
        //is_instruction = Zero;
        is_instruction = 1'b1;  //Zero;
        state_nxt = S0;
      end
      S11: state_nxt = S9;
      S12: state_nxt = S7;
      S13: state_nxt = S7;
      S14: state_nxt = mul_ext_ready ? S15 : S14;
      S15: begin
        is_instruction = 1'b1;
        state_nxt = S0;
      end
      S16: state_nxt = csr_access_fault ? S32 : S17;
      S17: begin
        is_instruction = 1'b1;
        state_nxt = S0;
      end
      S18: begin
        case (1'b1)
          is_amo_lr_w: state_nxt = S19;
          is_amo_sc_w: state_nxt = (amo_reserved_state_load ? S21 : S23);
          (is_amoadd_w | is_amoswap_w | is_amoxor_w | is_amoand_w
                     |  is_amoor_w | is_amomin_w | is_amomax_w | is_amominu_w | is_amomaxu_w):
            state_nxt = S24;
          default: state_nxt = S18;
        endcase
      end
      S19: begin
        // lr.w
        trap_addr_nxt = cpu_mem_addr;
        case (1'b1)
          is_load_unaligned: state_nxt = S42;
          page_fault: state_nxt = S54;
          mem_ready: state_nxt = access_fault ? S46 : S20;
          default: state_nxt = S19;
        endcase
      end
      S20: begin
        is_instruction = 1'b1;
        state_nxt = S0;
      end
      S21: begin
        // sc.w mem wr
        trap_addr_nxt = cpu_mem_addr;
        case (1'b1)
          is_store_unaligned: state_nxt = S44;
          page_fault: state_nxt = S56;
          mem_ready: state_nxt = access_fault ? S48 : S22;
          default: state_nxt = S21;
        endcase
      end
      S22: begin
        is_instruction = 1'b1;
        state_nxt = S0;
      end
      S23: begin
        is_instruction = 1'b1;
        state_nxt = S0;
      end
      S24: begin
        trap_addr_nxt = cpu_mem_addr;
        case (1'b1)
          is_load_unaligned: state_nxt = S42;
          page_fault: state_nxt = S54;
          mem_ready: state_nxt = access_fault ? S46 : S25;
          default: state_nxt = S24;
        endcase
      end
      S25: state_nxt = S26;
      S26: state_nxt = S27;
      S27: state_nxt = S28;
      S28: begin
        trap_addr_nxt = cpu_mem_addr;
        case (1'b1)
          is_store_unaligned: state_nxt = S44;
          page_fault: state_nxt = S56;
          mem_ready: state_nxt = access_fault ? S48 : S0;
          default: state_nxt = S28;
        endcase
      end
      S29: begin
        is_instruction = 1'b1;
        state_nxt = S0;
      end
      S30: state_nxt = S31;
      S31: state_nxt = S0;
      S32: state_nxt = S33;
      S33: state_nxt = S0;
      S34: state_nxt = S35;
      S35: state_nxt = S0;
      S36: state_nxt = S37;
      S37: state_nxt = S0;
      S38: state_nxt = S0;
      S39: state_nxt = S62;
      S40: state_nxt = S41;
      S41: state_nxt = S0;
      S42: state_nxt = S43;
      S43: state_nxt = S0;
      S44: state_nxt = S45;
      S45: state_nxt = S0;
      S46: state_nxt = S47;
      S47: state_nxt = S0;
      S48: state_nxt = S49;
      S49: state_nxt = S0;
      S50: state_nxt = S51;
      S51: state_nxt = S0;
      S52: state_nxt = S53;
      S53: state_nxt = S0;
      S54: state_nxt = S55;
      S55: state_nxt = S0;
      S56: state_nxt = S57;
      S57: state_nxt = S0;
      S58: state_nxt = S59;
      S59: state_nxt = S0;
      S60: state_nxt = S61;
      S61: state_nxt = S0;
      S62: state_nxt = S0;
      default: state_nxt = S0;
    endcase
  end

  logic [31:0] tmp_cause;
  always_comb begin
    incr_inst_retired           = 1'b0;
    AdrSrc                      = `ADDR_PC;
    store_instr                 = 1'b0;
    ALUSrcA                     = `SRCA_PC;
    ALUSrcB                     = `SRCB_RD2_BUF;
    ALUOp                       = `ALU_OP_ADD;
    ResultSrc                   = `RESULT_ALUOUT;
    PCUpdate                    = 1'b0;
    Branch                      = 1'b0;
    RegWrite                    = 1'b0;
    MemWrite                    = 1'b0;
    CSRvalid                    = 1'b0;
    select_ALUResult            = 1'b0;

    amo_temp_write_operation    = 1'b0;
    amo_set_reserved_state_load = 1'b0;
    amo_buffered_data           = 1'b0;
    amo_buffered_address        = 1'b0;
    select_amo_temp             = 1'b0;
    muxed_Aluout_or_amo_rd_wr   = 1'b0;

    mem_valid                   = 1'b0;
    mul_ext_valid               = 1'b0;

    exception_event             = 1'b0;
    cause                       = 32'b0;
    tmp_cause                   = 32'b0;
    badaddr                     = 32'b0;
    mret                        = 1'b0;
    sret                        = 1'b0;

    wfi_event                   = 1'b0;
    selectPC                    = 1'b0;
    tlb_flush                   = 1'b0;

    case (state)
      S0: begin
        // fetch
        mem_valid   = 1'b1;
        AdrSrc      = `ADDR_PC;
        store_instr = mem_ready;
        ALUSrcA     = `SRCA_PC;
        ALUSrcB     = `SRCB_CONST_4;
        ALUOp       = `ALU_OP_ADD;
        ResultSrc   = `RESULT_ALURESULT;
        PCUpdate    = mem_ready;
      end
      S1: begin
        // decode
        ALUSrcA = `SRCA_OLD_PC;
        ALUSrcB = `SRCB_IMM_EXT;
        ALUOp   = `ALU_OP_ADD;
        tlb_flush = is_sfence_vma;
      end
      S2: begin
        // mem addr
        ALUSrcA = `SRCA_RD1_BUF;
        ALUSrcB = `SRCB_IMM_EXT;
        ALUOp   = `ALU_OP_ADD;
      end
      S3: begin
        // mem read
        mem_valid = !is_load_unaligned;
        ResultSrc = `RESULT_ALUOUT;
        AdrSrc    = `ADDR_RESULT;
      end
      S4: begin
        mem_valid = 1'b1;
        ResultSrc = `RESULT_DATA;
        RegWrite = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S5: begin
        mem_valid = !is_store_unaligned;
        ResultSrc = `RESULT_ALUOUT;
        AdrSrc    = `ADDR_RESULT;
        MemWrite  = 1'b1;
        incr_inst_retired = mem_ready || is_store_unaligned;
      end
      S6: begin
        ALUSrcA = `SRCA_RD1_BUF;
        ALUSrcB = `SRCB_RD2_BUF;
        ALUOp   = `ALU_OP_ARITH_LOGIC;
      end
      S7: begin
        mem_valid = 1'b1;
        ResultSrc = `RESULT_ALUOUT;
        RegWrite = 1'b1;
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
        ALUSrcA           = `SRCA_RD1_BUF;
        ALUSrcB           = `SRCB_RD2_BUF;
        ALUOp             = `ALU_OP_BRANCH;
        ResultSrc         = `RESULT_ALUOUT;
        Branch            = 1'b1;
        mem_valid         = Zero;
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
        RegWrite = 1'b1;
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
        RegWrite = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S18: begin
        ALUSrcA = `SRCA_RD1_BUF;
        ALUSrcB = `SRCB_CONST_0;
        ALUOp   = `ALU_OP_ADD;
        amo_buffered_address = 1'b1;
      end
      S19: begin
        amo_set_reserved_state_load = !is_load_unaligned;
        amo_buffered_data = 1'b1;
        mem_valid = !is_load_unaligned;
        ResultSrc = `RESULT_ALUOUT;
        AdrSrc = `ADDR_RESULT;
      end
      S20: begin
        mem_valid = 1'b1;
        ResultSrc = `RESULT_DATA;
        RegWrite = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S21: begin
        amo_set_reserved_state_load = 1'b1;
        amo_buffered_data = 1'b0;
        mem_valid = !is_store_unaligned;
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
        mem_valid = !is_load_unaligned;
        AdrSrc = `ADDR_RESULT;
        ResultSrc = `RESULT_ALUOUT;
        amo_temp_write_operation = !is_load_unaligned;
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
        mem_valid = !is_store_unaligned;
        incr_inst_retired = mem_ready || is_store_unaligned;
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
        tmp_cause = `EXC_ECALL_FROM_UMODE;
        cause = {tmp_cause[31:2], privilege_mode};
        badaddr = 32'b0;
        exception_event = 1'b1;
      end
      S35: begin
        PCUpdate = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S36: begin
        case (1'b1)
          IRQ_TO_CPU_CTRL1: cause = `INTERRUPT_SUPERVISOR_SOFTWARE;
          IRQ_TO_CPU_CTRL3: cause = `INTERRUPT_MACHINE_SOFTWARE;
          IRQ_TO_CPU_CTRL5: cause = `INTERRUPT_SUPERVISOR_TIMER;
          IRQ_TO_CPU_CTRL7: cause = `INTERRUPT_MACHINE_TIMER;
          IRQ_TO_CPU_CTRL9: cause = `INTERRUPT_SUPERVISOR_EXTERNAL;
          IRQ_TO_CPU_CTRL11: cause = `INTERRUPT_MACHINE_EXTERNAL;
          default: cause = 32'b0;
        endcase
        badaddr = 32'b0;
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
        cause = `EXC_BREAKPOINT;
        badaddr = 32'b0;
        exception_event = 1'b1;
      end
      S40: begin
        cause = `EXC_ILLEGAL_INSTRUCTION;
        badaddr = {25'b0, op};
        exception_event = 1'b1;
      end
      S41: begin
        PCUpdate = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S42: begin
        cause           = `EXC_LOAD_AMO_ADDR_MISALIGNED;
        badaddr         = trap_addr;
        exception_event = 1'b1;
      end
      S43: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S44: begin
        cause           = `EXC_STORE_AMO_ADDR_MISALIGNED;
        badaddr         = trap_addr;
        exception_event = 1'b1;
      end
      S45: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S46: begin
        cause           = `EXC_LOAD_AMO_ACCESS_FAULT;
        badaddr         = trap_addr;
        exception_event = 1'b1;
      end
      S47: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S48: begin
        cause           = `EXC_STORE_AMO_ACCESS_FAULT;
        badaddr         = trap_addr;
        exception_event = 1'b1;
      end
      S49: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S50: begin
        sret = 1'b1;
      end
      S51: begin
        PCUpdate = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S52: begin
        cause           = `EXC_INSTR_PAGE_FAULT;
        badaddr         = fault_address;
        exception_event = 1'b1;
        selectPC        = 1'b1;
      end
      S53: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
        selectPC          = 1'b1;
      end
      S54: begin
        cause           = `EXC_LOAD_PAGE_FAULT;
        badaddr         = fault_address;
        exception_event = 1'b1;
      end
      S55: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S56: begin
        cause           = `EXC_STORE_AMO_PAGE_FAULT;
        badaddr         = fault_address;
        exception_event = 1'b1;
      end
      S57: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S58: begin
        cause           = `EXC_INSTR_ADDR_MISALIGNED;
        badaddr         = trap_addr;
        exception_event = 1'b1;
      end
      S59: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S60: begin
        cause           = `EXC_INSTR_ACCESS_FAULT;
        badaddr         = trap_addr;
        exception_event = 1'b1;
      end
      S61: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      S62: begin
        PCUpdate          = 1'b1;
        incr_inst_retired = 1'b1;
      end
      default: begin
        /* verilator lint_off WIDTH */
        AdrSrc    = 'b0;
        ALUSrcA   = 'b0;
        ALUSrcB   = 'b0;
        ALUOp     = 'b0;
        PCUpdate  = 'b0;
        Branch    = 'b0;
        ResultSrc = `RESULT_ALUOUT;
        RegWrite  = 'b0;
        MemWrite  = 'b0;
        /* verilator lint_on WIDTH */
      end
    endcase
  end
endmodule
