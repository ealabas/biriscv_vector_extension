//-----------------------------------------------------------------
//                         biRISC-V CPU
//                            V0.8.1
//                     Ultra-Embedded.com
//                     Copyright 2019-2020
//
//                   admin@ultra-embedded.com
//
//                     License: Apache 2.0
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

module biriscv_issue
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter SUPPORT_MULDIV   = 1
    ,parameter SUPPORT_DUAL_ISSUE = 1
    ,parameter SUPPORT_LOAD_BYPASS = 1
    ,parameter SUPPORT_MUL_BYPASS = 1
    ,parameter SUPPORT_REGFILE_XILINX = 0
    ,parameter SUPPORT_VECTOR_EXT = 1 // new
    ,parameter VLEN = 128 // new
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           fetch0_valid_i
    ,input  [ 31:0]  fetch0_instr_i
    ,input  [ 31:0]  fetch0_pc_i
    ,input           fetch0_fault_fetch_i
    ,input           fetch0_fault_page_i
    ,input           fetch0_instr_exec_i
    ,input           fetch0_instr_lsu_i
    ,input           fetch0_instr_branch_i
    ,input           fetch0_instr_mul_i
    ,input           fetch0_instr_div_i
    ,input           fetch0_instr_csr_i
    ,input           fetch0_instr_rd_valid_i
    ,input           fetch0_instr_vd_valid_i // new
    ,input           fetch0_instr_v_alu_i // new
    ,input           fetch0_instr_v_lsu_i // new
    ,input           fetch0_instr_invalid_i
    ,input           fetch1_valid_i
    ,input  [ 31:0]  fetch1_instr_i
    ,input  [ 31:0]  fetch1_pc_i
    ,input           fetch1_fault_fetch_i
    ,input           fetch1_fault_page_i
    ,input           fetch1_instr_exec_i
    ,input           fetch1_instr_lsu_i
    ,input           fetch1_instr_branch_i
    ,input           fetch1_instr_mul_i
    ,input           fetch1_instr_div_i
    ,input           fetch1_instr_csr_i
    ,input           fetch1_instr_rd_valid_i
    ,input           fetch1_instr_vd_valid_i // new
    ,input           fetch1_instr_v_alu_i // new
    ,input           fetch1_instr_v_lsu_i // new
    ,input           fetch1_instr_invalid_i
    ,input           branch_exec0_request_i
    ,input           branch_exec0_is_taken_i
    ,input           branch_exec0_is_not_taken_i
    ,input  [ 31:0]  branch_exec0_source_i
    ,input           branch_exec0_is_call_i
    ,input           branch_exec0_is_ret_i
    ,input           branch_exec0_is_jmp_i
    ,input  [ 31:0]  branch_exec0_pc_i
    ,input           branch_d_exec0_request_i
    ,input  [ 31:0]  branch_d_exec0_pc_i
    ,input  [  1:0]  branch_d_exec0_priv_i
    ,input           branch_exec1_request_i
    ,input           branch_exec1_is_taken_i
    ,input           branch_exec1_is_not_taken_i
    ,input  [ 31:0]  branch_exec1_source_i
    ,input           branch_exec1_is_call_i
    ,input           branch_exec1_is_ret_i
    ,input           branch_exec1_is_jmp_i
    ,input  [ 31:0]  branch_exec1_pc_i
    ,input           branch_d_exec1_request_i
    ,input  [ 31:0]  branch_d_exec1_pc_i
    ,input  [  1:0]  branch_d_exec1_priv_i
    ,input           branch_csr_request_i
    ,input  [ 31:0]  branch_csr_pc_i
    ,input  [  1:0]  branch_csr_priv_i
    ,input  [ 31:0]  writeback_exec0_value_i
    ,input  [ 31:0]  writeback_exec1_value_i
    ,input           writeback_mem_valid_i
    ,input  [ 31:0]  writeback_mem_value_i
    ,input  [  5:0]  writeback_mem_exception_i
    ,input  [ 31:0]  writeback_mul_value_i
    ,input           writeback_div_valid_i
    ,input  [ 31:0]  writeback_div_value_i
    // EMO - maybe a input here for the valud and value for v_alu. check.
    ,input           writeback_v_alu_valid_i // new
    ,input [VLEN-1:0] writeback_v_alu_value_i // new
    // VLSU
    ,input           writeback_v_lsu_valid_i // new
    ,input [VLEN-1:0] writeback_v_lsu_value_i // new
    ,input  [ 4:0]   writeback_v_lsu_vd_idx_i // new
    
    ,input  [ 31:0]  csr_result_e1_value_i
    ,input           csr_result_e1_write_i
    ,input  [ 31:0]  csr_result_e1_wdata_i
    ,input  [  5:0]  csr_result_e1_exception_i
    ,input           lsu_stall_i
    ,input           take_interrupt_i

    // Outputs
    ,output          fetch0_accept_o
    ,output          fetch1_accept_o
    ,output          branch_request_o
    ,output [ 31:0]  branch_pc_o
    ,output [  1:0]  branch_priv_o
    ,output          branch_info_request_o
    ,output          branch_info_is_taken_o
    ,output          branch_info_is_not_taken_o
    ,output [ 31:0]  branch_info_source_o
    ,output          branch_info_is_call_o
    ,output          branch_info_is_ret_o
    ,output          branch_info_is_jmp_o
    ,output [ 31:0]  branch_info_pc_o
    ,output          exec0_opcode_valid_o
    ,output          exec1_opcode_valid_o
    ,output          lsu_opcode_valid_o
    ,output          csr_opcode_valid_o
    ,output          mul_opcode_valid_o
    ,output          div_opcode_valid_o
    ,output          v_alu_opcode_valid_o // new
    ,output [ 31:0]  opcode0_opcode_o
    ,output [ 31:0]  opcode0_pc_o
    ,output          opcode0_invalid_o
    ,output [  4:0]  opcode0_rd_idx_o
    ,output [  4:0]  opcode0_ra_idx_o
    ,output [  4:0]  opcode0_rb_idx_o
    ,output [  4:0]  opcode0_vd_idx_o // new
    ,output [  4:0]  opcode0_va_idx_o // new
    ,output [  4:0]  opcode0_vb_idx_o // new
    ,output [ 31:0]  opcode0_ra_operand_o
    ,output [ 31:0]  opcode0_rb_operand_o
    ,output [VLEN-1:0]  opcode0_va_operand_o // new
    ,output [VLEN-1:0]  opcode0_vb_operand_o // new
    ,output [VLEN-1:0]  opcode0_vmask_operand_o // new
    ,output [ 31:0]  opcode1_opcode_o
    ,output [ 31:0]  opcode1_pc_o
    ,output          opcode1_invalid_o
    ,output [  4:0]  opcode1_rd_idx_o
    ,output [  4:0]  opcode1_ra_idx_o
    ,output [  4:0]  opcode1_rb_idx_o
    ,output [  4:0]  opcode1_vd_idx_o // new
    ,output [  4:0]  opcode1_va_idx_o // new
    ,output [  4:0]  opcode1_vb_idx_o // new
    ,output [ 31:0]  opcode1_ra_operand_o
    ,output [ 31:0]  opcode1_rb_operand_o
    ,output [VLEN-1:0]  opcode1_va_operand_o // new
    ,output [VLEN-1:0]  opcode1_vb_operand_o // new
    ,output [VLEN-1:0]  opcode1_vmask_operand_o // new
    ,output [ 31:0]  lsu_opcode_opcode_o
    ,output [ 31:0]  lsu_opcode_pc_o
    ,output          lsu_opcode_invalid_o
    ,output [  4:0]  lsu_opcode_rd_idx_o
    ,output [  4:0]  lsu_opcode_ra_idx_o
    ,output [  4:0]  lsu_opcode_rb_idx_o
    ,output [ 31:0]  lsu_opcode_ra_operand_o
    ,output [ 31:0]  lsu_opcode_rb_operand_o
    ,output [ 31:0]  mul_opcode_opcode_o
    ,output [ 31:0]  mul_opcode_pc_o
    ,output          mul_opcode_invalid_o
    ,output [  4:0]  mul_opcode_rd_idx_o
    ,output [  4:0]  mul_opcode_ra_idx_o
    ,output [  4:0]  mul_opcode_rb_idx_o
    ,output [ 31:0]  mul_opcode_ra_operand_o
    ,output [ 31:0]  mul_opcode_rb_operand_o
    ,output [ 31:0]  v_alu_opcode_opcode_o // new
    ,output [ 31:0]  v_alu_opcode_pc_o // new
    ,output          v_alu_opcode_invalid_o // new
    ,output [  4:0]  v_alu_opcode_ra_idx_o // new // EMO - check that if ra,rb needed. maybe only ra is enough, or none is needed.
    ,output [  4:0]  v_alu_opcode_rb_idx_o // new 
    ,output [  4:0]  v_alu_opcode_va_idx_o // new
    ,output [  4:0]  v_alu_opcode_vb_idx_o // new
    ,output [  4:0]  v_alu_opcode_vd_idx_o // new
    ,output [VLEN-1:0] v_alu_opcode_va_operand_o // new
    ,output [VLEN-1:0] v_alu_opcode_vb_operand_o // new
    ,output [VLEN-1:0] v_alu_opcode_vmask_operand_o // new
    ,output [31:0]   v_alu_opcode_ra_operand_o // new
    ,output [31:0]   v_alu_opcode_rb_operand_o // new
    // Vector LSU opcode bundle (slot0 only)
    ,output          v_lsu_opcode_valid_o // new
    ,output [ 31:0]  v_lsu_opcode_opcode_o // new
    ,output [ 31:0]  v_lsu_opcode_pc_o // new
    ,output          v_lsu_opcode_invalid_o // new
    ,output [  4:0]  v_lsu_opcode_rd_idx_o // new
    ,output [  4:0]  v_lsu_opcode_ra_idx_o // new
    ,output [  4:0]  v_lsu_opcode_rb_idx_o // new
    ,output [  4:0]  v_lsu_opcode_vd_idx_o // new
    ,output [  4:0]  v_lsu_opcode_va_idx_o // new
    ,output [  4:0]  v_lsu_opcode_vb_idx_o // new
    ,output [ 31:0]  v_lsu_opcode_ra_operand_o // new
    ,output [ 31:0]  v_lsu_opcode_rb_operand_o // new
    ,output [VLEN-1:0] v_lsu_opcode_va_operand_o // new
    ,output [VLEN-1:0] v_lsu_opcode_vb_operand_o // new
    ,output [VLEN-1:0] v_lsu_opcode_vmask_operand_o // new

    ,output [ 31:0]  csr_opcode_opcode_o
    ,output [ 31:0]  csr_opcode_pc_o
    ,output          csr_opcode_invalid_o
    ,output [  4:0]  csr_opcode_rd_idx_o
    ,output [  4:0]  csr_opcode_ra_idx_o
    ,output [  4:0]  csr_opcode_rb_idx_o
    ,output [ 31:0]  csr_opcode_ra_operand_o
    ,output [ 31:0]  csr_opcode_rb_operand_o
    ,output          csr_writeback_write_o
    ,output [ 11:0]  csr_writeback_waddr_o
    ,output [ 31:0]  csr_writeback_wdata_o
    ,output [  5:0]  csr_writeback_exception_o
    ,output [ 31:0]  csr_writeback_exception_pc_o
    ,output [ 31:0]  csr_writeback_exception_addr_o
    ,output          exec0_hold_o
    ,output          exec1_hold_o
    ,output          mul_hold_o
    ,output          interrupt_inhibit_o
);



`include "biriscv_defs.v"

wire enable_dual_issue_w = SUPPORT_DUAL_ISSUE;
wire enable_muldiv_w     = SUPPORT_MULDIV;
wire enable_mul_bypass_w = SUPPORT_MUL_BYPASS;
wire enable_vector_operations = SUPPORT_VECTOR_EXT; // new

wire stall_w;
wire squash_w;

//-------------------------------------------------------------
// PC
//-------------------------------------------------------------
wire        single_issue_w;
wire        dual_issue_w;
reg  [31:0] pc_x_q;
reg   [1:0] priv_x_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    pc_x_q <= 32'b0;
else if (branch_csr_request_i)
    pc_x_q <= branch_csr_pc_i;
else if (branch_d_exec1_request_i)
    pc_x_q <= branch_d_exec1_pc_i;
else if (branch_d_exec0_request_i)
    pc_x_q <= branch_d_exec0_pc_i;
else if (dual_issue_w)
    pc_x_q <= pc_x_q + 32'd8;
else if (single_issue_w)
    pc_x_q <= pc_x_q + 32'd4;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    priv_x_q <= `PRIV_MACHINE;
else if (branch_csr_request_i)
    priv_x_q <= branch_csr_priv_i;

//-------------------------------------------------------------
// Issue Select
//-------------------------------------------------------------
reg mispredicted_r;
reg slot0_valid_r;
reg slot1_valid_r;

always @ *
begin
    mispredicted_r = 1'b0;
    slot0_valid_r  = 1'b0;
    slot1_valid_r  = 1'b0;

    // Flush due to CSR branch
    if (branch_csr_request_i || squash_w)
    begin
        slot0_valid_r  = 1'b0;
        slot1_valid_r  = 1'b0;
    end
    // Word 0 valid and expected PC (word 1 may also be valid)
    else if (fetch0_valid_i && {fetch0_pc_i[31:2], 2'b0} == {pc_x_q[31:2], 2'b0})
        slot0_valid_r  = 1'b1;
    // Word 1 valid and expected PC
    else if (fetch1_valid_i && {fetch1_pc_i[31:2], 2'b0} == {pc_x_q[31:2], 2'b0})
        slot1_valid_r  = 1'b1;
    // Neither word is the expected PC - must be a branch misprediction
    else if (fetch0_valid_i || fetch1_valid_i)
        mispredicted_r = 1'b1;
end

// Branch request (CSR branch - ecall, xret, or branch misprediction)
// Note: Correctly predicted branches are silent
assign branch_request_o          = branch_csr_request_i | mispredicted_r;
assign branch_pc_o               = branch_csr_request_i ? branch_csr_pc_i : pc_x_q;
assign branch_priv_o             = branch_csr_request_i ? branch_csr_priv_i : priv_x_q;

//-------------------------------------------------------------
// Instruction Decoder
//-------------------------------------------------------------
reg        opcode_a_valid_r;
reg        opcode_b_valid_r;
reg [1:0]  opcode_a_fault_r;
reg [1:0]  opcode_b_fault_r;
reg [31:0] opcode_a_r;
reg [31:0] opcode_b_r;
reg [31:0] opcode_a_pc_r;
reg [31:0] opcode_b_pc_r;

always @ *
begin
    opcode_a_r       = 32'b0;
    opcode_b_r       = 32'b0;
    opcode_a_valid_r = 1'b0;
    opcode_b_valid_r = 1'b0;
    opcode_a_fault_r = 2'b0;
    opcode_b_fault_r = 2'b0;
    opcode_a_pc_r    = 32'b0;
    opcode_b_pc_r    = 32'b0;

    // Word 0 (and possibly slot 1) are valid instructions
    if (slot0_valid_r)
    begin
        opcode_a_valid_r = 1'b1;
        opcode_b_valid_r = fetch1_valid_i;
        opcode_a_r       = fetch0_instr_i;
        opcode_a_pc_r    = fetch0_pc_i;
        opcode_a_fault_r = {fetch0_fault_page_i, fetch0_fault_fetch_i};
        opcode_b_r       = fetch1_instr_i;
        opcode_b_pc_r    = fetch1_pc_i;
        opcode_b_fault_r = {fetch1_fault_page_i, fetch1_fault_fetch_i};
    end
    // Word 1 valid - mux to first issue slot
    // Note: Some instruction types can only issue in slot0, hence this muxing
    else if (slot1_valid_r)
    begin
        opcode_a_valid_r = 1'b1;
        opcode_b_valid_r = 1'b0;
        opcode_a_r       = fetch1_instr_i;
        opcode_a_pc_r    = fetch1_pc_i;
        opcode_a_fault_r = {fetch1_fault_page_i, fetch1_fault_fetch_i};
        opcode_b_r       = 32'b0;
        opcode_b_pc_r    = 32'b0;
        opcode_b_fault_r = 2'b0;
    end
end

wire [4:0] issue_a_ra_idx_w   = opcode_a_r[19:15];
wire [4:0] issue_a_rb_idx_w   = opcode_a_r[24:20];
wire [4:0] issue_a_rd_idx_w   = opcode_a_r[11:7];
wire [4:0] issue_a_va_idx_w   = opcode_a_r[19:15]; // new
wire [4:0] issue_a_vb_idx_w   = opcode_a_r[24:20]; // new
wire [4:0] issue_a_vd_idx_w   = opcode_a_r[11:7]; // new
// For vector stores, the data source is vs3 (vd field). Re-use the VB read port for that case.
wire [4:0] issue_a_vsrc_idx_w = issue_a_v_lsu_w ? issue_a_vd_idx_w : issue_a_vb_idx_w;
wire       issue_a_vmask_idx_w = 5'b0; // new
wire       issue_a_vmask_w    = opcode_a_r[25]; // new
// EMO - after checking ra,rb add here if needed for issue a
wire       issue_a_sb_alloc_w = (slot0_valid_r ? fetch0_instr_rd_valid_i : fetch1_instr_rd_valid_i);
wire       issue_a_v_sb_alloc_w = (slot0_valid_r ? fetch0_instr_vd_valid_i : fetch1_instr_vd_valid_i); // new
wire       issue_a_exec_w     = (slot0_valid_r ? fetch0_instr_exec_i     : fetch1_instr_exec_i);
wire       issue_a_lsu_w      = (slot0_valid_r ? fetch0_instr_lsu_i      : fetch1_instr_lsu_i);
wire       issue_a_branch_w   = (slot0_valid_r ? fetch0_instr_branch_i   : fetch1_instr_branch_i);
wire       issue_a_mul_w      = (slot0_valid_r ? fetch0_instr_mul_i      : fetch1_instr_mul_i);
wire       issue_a_div_w      = (slot0_valid_r ? fetch0_instr_div_i      : fetch1_instr_div_i);
wire       issue_a_csr_w      = (slot0_valid_r ? fetch0_instr_csr_i      : fetch1_instr_csr_i);
// Mask vector flags with opcode validity to avoid X/Z propagation
wire       issue_a_v_alu_raw_w= opcode_a_valid_r ? (slot0_valid_r ? fetch0_instr_v_alu_i    : fetch1_instr_v_alu_i) : 1'b0; // new
wire       issue_a_v_lsu_w    = opcode_a_valid_r ? (slot0_valid_r ? fetch0_instr_v_lsu_i    : fetch1_instr_v_lsu_i) : 1'b0; // new
// Mask VALU flag if this is actually a VLSU op
wire       issue_a_v_alu_w    = issue_a_v_alu_raw_w & ~issue_a_v_lsu_w; // new
wire       issue_a_invalid_w  = (slot0_valid_r ? fetch0_instr_invalid_i  : fetch1_instr_invalid_i);


wire [4:0] issue_b_ra_idx_w   = opcode_b_r[19:15];
wire [4:0] issue_b_rb_idx_w   = opcode_b_r[24:20];
wire [4:0] issue_b_rd_idx_w   = opcode_b_r[11:7];
wire [4:0] issue_b_va_idx_w   = opcode_b_r[19:15]; // new
wire [4:0] issue_b_vb_idx_w   = opcode_b_r[24:20]; // new
wire [4:0] issue_b_vd_idx_w   = opcode_b_r[11:7]; // new
wire       issue_b_vmask_idx_w = 5'b0; // new
wire       issue_b_vmask_w    = opcode_b_r[25]; // new
// EMO - after checking ra,rb add here if needed for issue b
wire       issue_b_sb_alloc_w = fetch1_instr_rd_valid_i;
wire       issue_b_v_sb_alloc_w = fetch1_instr_vd_valid_i; // new
wire       issue_b_exec_w     = fetch1_instr_exec_i;
wire       issue_b_lsu_w      = fetch1_instr_lsu_i;
wire       issue_b_branch_w   = fetch1_instr_branch_i;
wire       issue_b_mul_w      = fetch1_instr_mul_i;
wire       issue_b_div_w      = fetch1_instr_div_i;
wire       issue_b_csr_w      = fetch1_instr_csr_i;
wire       issue_b_v_alu_raw_w= opcode_b_valid_r ? fetch1_instr_v_alu_i : 1'b0; // new
wire       issue_b_v_lsu_w    = opcode_b_valid_r ? fetch1_instr_v_lsu_i : 1'b0; // new
// Mask VALU flag if this is actually a VLSU op
wire       issue_b_v_alu_w    = issue_b_v_alu_raw_w & ~issue_b_v_lsu_w; // new
wire       issue_b_invalid_w  = fetch1_instr_invalid_i;

//-------------------------------------------------------------
// Pipe0 - Status tracking
//------------------------------------------------------------- 
wire        pipe0_squash_e1_e2_w;
wire        pipe1_squash_e1_e2_w;

reg         opcode_a_issue_r;
reg         opcode_a_accept_r;
wire        pipe0_stall_raw_w;

wire        pipe0_load_e1_w;
wire        pipe0_store_e1_w;
wire        pipe0_mul_e1_w;
wire        pipe0_branch_e1_w;
wire [4:0]  pipe0_rd_e1_w;
wire        pipe0_v_alu_e1_w; // new
wire [4:0]  pipe0_vd_e1_w; // new

wire [31:0] pipe0_pc_e1_w;
wire [31:0] pipe0_opcode_e1_w;
wire [31:0] pipe0_operand_ra_e1_w;
wire [31:0] pipe0_operand_rb_e1_w;

wire [VLEN-1:0] pipe0_v_alu_operand_va_e1_w; // new
wire [VLEN-1:0] pipe0_v_alu_operand_vb_e1_w; // new
wire [VLEN-1:0] pipe0_v_alu_operand_vmask_e1_w; // new

wire        pipe0_load_e2_w;
wire        pipe0_mul_e2_w;
wire [4:0]  pipe0_rd_e2_w;
wire [4:0]  pipe0_vd_e2_w; // new
wire [31:0] pipe0_result_e2_w;

wire            pipe0_v_alu_e2_w;
wire [VLEN-1:0] pipe0_v_alu_result_e2_w; // new

wire [VLEN-1:0] pipe0_operand_va_wb_w; // new
wire [VLEN-1:0] pipe0_operand_vb_wb_w; // new
wire [VLEN-1:0] pipe0_mask_vm_wb_w; // new

wire        pipe0_valid_wb_w;
wire        pipe0_csr_wb_w;
wire [4:0]  pipe0_rd_wb_w;
wire [4:0]  pipe0_vd_wb_w; // new
wire [31:0] pipe0_result_wb_w;
wire [VLEN-1:0] pipe0_v_alu_result_wb_w; // new
wire        pipe0_v_alu_wb_w; // new
wire [31:0] pipe0_pc_wb_w;
wire [31:0] pipe0_opc_wb_w;
wire [31:0] pipe0_ra_val_wb_w;
wire [31:0] pipe0_rb_val_wb_w;
wire [`EXCEPTION_W-1:0] pipe0_exception_wb_w;

wire [`EXCEPTION_W-1:0] issue_a_fault_w = opcode_a_fault_r[0] ? `EXCEPTION_FAULT_FETCH:
                                          opcode_a_fault_r[1] ? `EXCEPTION_PAGE_FAULT_INST: `EXCEPTION_W'b0;

biriscv_pipe_ctrl
#( 
     .SUPPORT_LOAD_BYPASS(SUPPORT_LOAD_BYPASS)
    ,.SUPPORT_MUL_BYPASS(SUPPORT_MUL_BYPASS)
    ,.VLEN(VLEN) // new
)
u_pipe0_ctrl
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)    

    // Issue
    ,.issue_valid_i(opcode_a_issue_r)
    ,.issue_accept_i(opcode_a_accept_r)
    ,.issue_stall_i(stall_w)
    ,.issue_lsu_i(issue_a_lsu_w)
    ,.issue_csr_i(issue_a_csr_w)
    ,.issue_div_i(issue_a_div_w)
    ,.issue_mul_i(issue_a_mul_w)
    ,.issue_branch_i(issue_a_branch_w)
    ,.issue_v_alu_i(issue_a_v_alu_w) // new
    ,.issue_v_lsu_i(issue_a_v_lsu_w) // new
    ,.issue_rd_valid_i(issue_a_sb_alloc_w)
    ,.issue_vd_valid_i(issue_a_v_sb_alloc_w) // new
    ,.issue_rd_i(issue_a_rd_idx_w)
    ,.issue_vd_i(issue_a_vd_idx_w) // new
    ,.issue_exception_i(issue_a_fault_w)
    ,.issue_pc_i(opcode0_pc_o)
    ,.issue_opcode_i(opcode0_opcode_o)
    ,.issue_operand_ra_i(opcode0_ra_operand_o)
    ,.issue_operand_rb_i(opcode0_rb_operand_o)
    ,.issue_branch_taken_i(branch_d_exec0_request_i)
    ,.issue_branch_target_i(branch_d_exec0_pc_i)
    ,.take_interrupt_i(take_interrupt_i)

    // Vector register inputs // EMO - Check here, compare with opcode0_ra_operand_o
    ,.issue_operand_va_i(opcode0_va_operand_o)
    ,.issue_operand_vb_i(opcode0_vb_operand_o)
    ,.issue_operand_vmask_i(opcode0_vmask_operand_o)

    // Execution stage 1: ALU result
    ,.alu_result_e1_i(writeback_exec0_value_i)
    ,.csr_result_value_e1_i(csr_result_e1_value_i)
    ,.csr_result_write_e1_i(csr_result_e1_write_i)
    ,.csr_result_wdata_e1_i(csr_result_e1_wdata_i)
    ,.csr_result_exception_e1_i(csr_result_e1_exception_i)

    // Execution stage 1
    ,.load_e1_o(pipe0_load_e1_w)
    ,.store_e1_o(pipe0_store_e1_w)
    ,.mul_e1_o(pipe0_mul_e1_w)
    ,.branch_e1_o(pipe0_branch_e1_w)
    ,.v_alu_e1_o(pipe0_v_alu_e1_w) // new
    ,.vd_e1_o(pipe0_vd_e1_w) // new
    ,.rd_e1_o(pipe0_rd_e1_w)
    ,.pc_e1_o(pipe0_pc_e1_w)
    ,.opcode_e1_o(pipe0_opcode_e1_w)
    ,.operand_ra_e1_o(pipe0_operand_ra_e1_w)
    ,.operand_rb_e1_o(pipe0_operand_rb_e1_w)

    // Vector register outputs for stage 1
    ,.v_alu_operand_va_e1_o(pipe0_v_alu_operand_va_e1_w) // new
    ,.v_alu_operand_vb_e1_o(pipe0_v_alu_operand_vb_e1_w) // new
    ,.v_alu_operand_vmask_e1_o(pipe0_v_alu_operand_vmask_e1_w) // new

    // Execution stage 2: Other results
    ,.mem_complete_i(writeback_mem_valid_i)
    ,.mem_result_e2_i(writeback_mem_value_i)
    ,.mem_exception_e2_i(writeback_mem_exception_i)
    ,.mul_result_e2_i(writeback_mul_value_i)

    // Execution stage 2
    ,.load_e2_o(pipe0_load_e2_w)
    ,.mul_e2_o(pipe0_mul_e2_w)
    ,.rd_e2_o(pipe0_rd_e2_w)
    ,.vd_e2_o(pipe0_vd_e2_w) // new
    ,.result_e2_o(pipe0_result_e2_w)

    ,.v_alu_e2_o(pipe0_v_alu_e2_w)
    ,.v_alu_result_e2_o(pipe0_v_alu_result_e2_w)

    ,.stall_o(pipe0_stall_raw_w)
    ,.squash_e1_e2_o(pipe0_squash_e1_e2_w)
    ,.squash_e1_e2_i(pipe1_squash_e1_e2_w)
    ,.squash_wb_i(1'b0)

    // Out of pipe: Divide Result
    ,.div_complete_i(writeback_div_valid_i)
    ,.div_result_i(writeback_div_value_i)

    // V ALU results
    ,.v_alu_complete_i(writeback_v_alu_valid_i) // new
    ,.v_alu_result_i(writeback_v_alu_value_i) // new
    // V LSU completion
    ,.v_lsu_complete_i(writeback_v_lsu_valid_i) // new

    // Commit
    ,.valid_wb_o(pipe0_valid_wb_w)
    ,.csr_wb_o(pipe0_csr_wb_w)
    ,.rd_wb_o(pipe0_rd_wb_w)
    ,.vd_wb_o(pipe0_vd_wb_w) // new
    ,.v_alu_result_wb_o(pipe0_v_alu_result_wb_w) // new
    ,.v_alu_wb_o(pipe0_v_alu_wb_w) // new
    ,.result_wb_o(pipe0_result_wb_w)
    ,.pc_wb_o(pipe0_pc_wb_w)
    ,.opcode_wb_o(pipe0_opc_wb_w)
    ,.operand_ra_wb_o(pipe0_ra_val_wb_w)
    ,.operand_rb_wb_o(pipe0_rb_val_wb_w)
    ,.exception_wb_o(pipe0_exception_wb_w)
    ,.csr_write_wb_o(csr_writeback_write_o)
    ,.csr_waddr_wb_o(csr_writeback_waddr_o)
    ,.csr_wdata_wb_o(csr_writeback_wdata_o)

    // Outputs to V ALU
    ,.operand_va_wb_o(pipe0_operand_va_wb_w) // new
    ,.operand_vb_wb_o(pipe0_operand_vb_wb_w) // new
    ,.mask_vm_wb_o(pipe0_mask_vm_wb_w) // new   
);

assign exec0_hold_o = stall_w;
assign mul_hold_o   = stall_w;

//-------------------------------------------------------------
// Pipe1 - Status tracking
//-------------------------------------------------------------
reg         opcode_b_issue_r;
reg         opcode_b_accept_r;
wire        pipe1_stall_raw_w;

wire        pipe1_load_e1_w;
wire        pipe1_store_e1_w;
wire        pipe1_mul_e1_w;
wire        pipe1_branch_e1_w;
wire [4:0]  pipe1_rd_e1_w;
wire        pipe1_v_alu_e1_w; // new
wire [4:0]  pipe1_vd_e1_w; // new

wire [31:0] pipe1_pc_e1_w;
wire [31:0] pipe1_opcode_e1_w;
wire [31:0] pipe1_operand_ra_e1_w;
wire [31:0] pipe1_operand_rb_e1_w;

wire [VLEN-1:0] pipe1_v_alu_operand_va_e1_w; // new
wire [VLEN-1:0] pipe1_v_alu_operand_vb_e1_w; // new
wire [VLEN-1:0] pipe1_v_alu_operand_vmask_e1_w; // new

wire        pipe1_load_e2_w;
wire        pipe1_mul_e2_w;
wire [4:0]  pipe1_rd_e2_w;
wire [4:0]  pipe1_vd_e2_w; // new
wire [31:0] pipe1_result_e2_w;

wire            pipe1_v_alu_e2_w;
wire [VLEN-1:0] pipe1_v_alu_result_e2_w; // new

wire [VLEN-1:0] pipe1_operand_va_wb_w; // new
wire [VLEN-1:0] pipe1_operand_vb_wb_w; // new
wire [VLEN-1:0] pipe1_mask_vm_wb_w; // new

wire        pipe1_valid_wb_w;
wire [4:0]  pipe1_rd_wb_w;
wire [4:0]  pipe1_vd_wb_w; // new
wire [31:0] pipe1_result_wb_w;
wire [VLEN-1:0] pipe1_v_alu_result_wb_w; // new
wire        pipe1_v_alu_wb_w; // new
wire [31:0] pipe1_pc_wb_w;
wire [31:0] pipe1_opc_wb_w;
wire [31:0] pipe1_ra_val_wb_w;
wire [31:0] pipe1_rb_val_wb_w;
wire [`EXCEPTION_W-1:0] pipe1_exception_wb_w;

wire [`EXCEPTION_W-1:0] issue_b_fault_w = opcode_b_fault_r[0] ? `EXCEPTION_FAULT_FETCH:
                                          opcode_b_fault_r[1] ? `EXCEPTION_PAGE_FAULT_INST: `EXCEPTION_W'b0;

biriscv_pipe_ctrl
#( 
     .SUPPORT_LOAD_BYPASS(SUPPORT_LOAD_BYPASS)
    ,.SUPPORT_MUL_BYPASS(SUPPORT_MUL_BYPASS)
    ,.VLEN(VLEN) // new
)
u_pipe1_ctrl
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)

    // Issue
    ,.issue_valid_i(opcode_b_issue_r)
    ,.issue_accept_i(opcode_b_accept_r)
    ,.issue_stall_i(stall_w)
    ,.issue_lsu_i(issue_b_lsu_w)
    ,.issue_csr_i(1'b0)
    ,.issue_div_i(1'b0)
    ,.issue_mul_i(issue_b_mul_w)
    ,.issue_branch_i(issue_b_branch_w)
    ,.issue_v_alu_i(issue_b_v_alu_w) // new
    ,.issue_v_lsu_i(1'b0) // new, keep slot1 vector LSU disabled
    ,.issue_rd_valid_i(issue_b_sb_alloc_w)
    ,.issue_vd_valid_i(issue_b_v_sb_alloc_w) // new
    ,.issue_rd_i(issue_b_rd_idx_w)
    ,.issue_vd_i(issue_b_vd_idx_w) // new
    ,.issue_exception_i(issue_b_fault_w)
    ,.issue_pc_i(opcode1_pc_o)
    ,.issue_opcode_i(opcode1_opcode_o)
    ,.issue_operand_ra_i(opcode1_ra_operand_o)
    ,.issue_operand_rb_i(opcode1_rb_operand_o)
    ,.issue_branch_taken_i(branch_d_exec1_request_i)
    ,.issue_branch_target_i(branch_d_exec1_pc_i)
    ,.take_interrupt_i(take_interrupt_i)

    // Vector register inputs // EMO - Check here too, compare with opcode0_ra_operand_o
    ,.issue_operand_va_i(opcode1_va_operand_o)
    ,.issue_operand_vb_i(opcode1_vb_operand_o)
    ,.issue_operand_vmask_i(opcode1_vmask_operand_o)

    // Execution stage 1: ALU, CSR result
    ,.alu_result_e1_i(writeback_exec1_value_i)
    ,.csr_result_value_e1_i(csr_result_e1_value_i)
    ,.csr_result_write_e1_i(csr_result_e1_write_i)
    ,.csr_result_wdata_e1_i(csr_result_e1_wdata_i)
    ,.csr_result_exception_e1_i(csr_result_e1_exception_i)

    // Execution stage 1
    ,.load_e1_o(pipe1_load_e1_w)
    ,.store_e1_o(pipe1_store_e1_w)
    ,.mul_e1_o(pipe1_mul_e1_w)
    ,.branch_e1_o(pipe1_branch_e1_w)
    ,.v_alu_e1_o(pipe1_v_alu_e1_w) // new
    ,.vd_e1_o(pipe1_vd_e1_w) // new
    ,.rd_e1_o(pipe1_rd_e1_w)
    ,.pc_e1_o(pipe1_pc_e1_w)
    ,.opcode_e1_o(pipe1_opcode_e1_w)
    ,.operand_ra_e1_o(pipe1_operand_ra_e1_w)
    ,.operand_rb_e1_o(pipe1_operand_rb_e1_w)

    // Vector register outputs for stage 1
    ,.v_alu_operand_va_e1_o(pipe1_v_alu_operand_va_e1_w) // new
    ,.v_alu_operand_vb_e1_o(pipe1_v_alu_operand_vb_e1_w) // new
    ,.v_alu_operand_vmask_e1_o(pipe1_v_alu_operand_vmask_e1_w) // new

    // Execution stage 2: Other results
    ,.mem_complete_i(writeback_mem_valid_i)
    ,.mem_result_e2_i(writeback_mem_value_i)
    ,.mem_exception_e2_i(writeback_mem_exception_i)
    ,.mul_result_e2_i(writeback_mul_value_i)

    // Execution stage 2
    ,.load_e2_o(pipe1_load_e2_w)
    ,.mul_e2_o(pipe1_mul_e2_w)
    ,.rd_e2_o(pipe1_rd_e2_w)
    ,.vd_e2_o(pipe1_vd_e2_w) // new
    ,.result_e2_o(pipe1_result_e2_w)

    ,.v_alu_e2_o(pipe1_v_alu_e2_w)
    ,.v_alu_result_e2_o(pipe1_v_alu_result_e2_w)

    ,.stall_o(pipe1_stall_raw_w)
    ,.squash_e1_e2_o(pipe1_squash_e1_e2_w)
    ,.squash_e1_e2_i(pipe0_squash_e1_e2_w)
    ,.squash_wb_i(pipe0_squash_e1_e2_w)

    // Out of pipe: Divide Result
    ,.div_complete_i(writeback_div_valid_i)
    ,.div_result_i(writeback_div_value_i)

    // V ALU results
    ,.v_alu_complete_i(writeback_v_alu_valid_i) // new
    ,.v_alu_result_i(writeback_v_alu_value_i) // new

    // Commit
    ,.valid_wb_o(pipe1_valid_wb_w)
    ,.csr_wb_o()
    ,.rd_wb_o(pipe1_rd_wb_w)
    ,.vd_wb_o(pipe1_vd_wb_w) // new
    ,.v_alu_result_wb_o(pipe1_v_alu_result_wb_w) // new
    ,.v_alu_wb_o(pipe1_v_alu_wb_w) // new
    ,.result_wb_o(pipe1_result_wb_w)
    ,.pc_wb_o(pipe1_pc_wb_w)
    ,.opcode_wb_o(pipe1_opc_wb_w)
    ,.operand_ra_wb_o(pipe1_ra_val_wb_w)
    ,.operand_rb_wb_o(pipe1_rb_val_wb_w)
    ,.exception_wb_o(pipe1_exception_wb_w)
    ,.csr_write_wb_o()
    ,.csr_waddr_wb_o()
    ,.csr_wdata_wb_o()

    // Outputs to V ALU
    ,.operand_va_wb_o(pipe1_operand_va_wb_w) // new
    ,.operand_vb_wb_o(pipe1_operand_vb_wb_w) // new
    ,.mask_vm_wb_o(pipe1_mask_vm_wb_w) // new  
);

assign exec1_hold_o = stall_w;

assign csr_writeback_exception_o      = pipe0_exception_wb_w | pipe1_exception_wb_w;
assign csr_writeback_exception_pc_o   = (|pipe0_exception_wb_w) ? pipe0_pc_wb_w     : pipe1_pc_wb_w;
assign csr_writeback_exception_addr_o = (|pipe0_exception_wb_w) ? pipe0_result_wb_w : pipe1_result_wb_w;

//-------------------------------------------------------------
// Branch predictor info
//-------------------------------------------------------------
// This info is used to learn future prediction, and to correct 
// BTB, BHT, GShare, RAS indexes on mispredictions.
assign branch_info_request_o      = mispredicted_r;
assign branch_info_is_taken_o     = (pipe1_branch_e1_w & branch_exec1_is_taken_i)     | (pipe0_branch_e1_w & branch_exec0_is_taken_i);
assign branch_info_is_not_taken_o = (pipe1_branch_e1_w & branch_exec1_is_not_taken_i) | (pipe0_branch_e1_w & branch_exec0_is_not_taken_i);
assign branch_info_is_call_o      = (pipe1_branch_e1_w & branch_exec1_is_call_i)      | (pipe0_branch_e1_w & branch_exec0_is_call_i);
assign branch_info_is_ret_o       = (pipe1_branch_e1_w & branch_exec1_is_ret_i)       | (pipe0_branch_e1_w & branch_exec0_is_ret_i);
assign branch_info_is_jmp_o       = (pipe1_branch_e1_w & branch_exec1_is_jmp_i)       | (pipe0_branch_e1_w & branch_exec0_is_jmp_i);
assign branch_info_source_o       = (pipe1_branch_e1_w & branch_exec1_request_i)      ? branch_exec1_source_i : branch_exec0_source_i;
assign branch_info_pc_o           = (pipe1_branch_e1_w & branch_exec1_request_i)      ? branch_exec1_pc_i     : branch_exec0_pc_i;

//-------------------------------------------------------------
// Blocking events (division, CSR unit access)
//-------------------------------------------------------------
reg div_pending_q;
reg csr_pending_q;
reg v_alu_pending_q; // new
reg v_lsu_pending_q; // new
reg [4:0] v_lsu_dest_q; // new
reg v_lsu_complete_d; // new
reg v_lsu_is_load_q; // new

// Division operations take 2 - 34 cycles and stall
// the pipeline (complete out-of-pipe) until completed.
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    div_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    div_pending_q <= 1'b0;
else if (div_opcode_valid_o && issue_a_div_w)
    div_pending_q <= 1'b1;
else if (writeback_div_valid_i)
    div_pending_q <= 1'b0;

// CSR operations are infrequent - avoid any complications of pipelining them.
// These only take a 2-3 cycles anyway and may result in a pipe flush (e.g. ecall, ebreak..).
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    csr_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    csr_pending_q <= 1'b0;
else if (csr_opcode_valid_o && issue_a_csr_w)
    csr_pending_q <= 1'b1;
else if (pipe0_csr_wb_w)
    csr_pending_q <= 1'b0;

assign squash_w = pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w;

// Vector operations may also take multiple cycles and should stall the pipeline until completed.
// new
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    v_alu_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    v_alu_pending_q <= 1'b0;
else if (v_alu_opcode_valid_o && issue_a_v_alu_w)
    v_alu_pending_q <= 1'b1;
else if (writeback_v_alu_valid_i)
    v_alu_pending_q <= 1'b0;

// Vector LSU operations are multi-cycle; block dependent ops until completion.
wire v_lsu_is_load_w = (((v_lsu_opcode_opcode_o & `INST_VLE8_V_MASK)  == `INST_VLE8_V)  ||
                        ((v_lsu_opcode_opcode_o & `INST_VLE16_V_MASK) == `INST_VLE16_V) ||
                        ((v_lsu_opcode_opcode_o & `INST_VLE32_V_MASK) == `INST_VLE32_V) ||
                        ((v_lsu_opcode_opcode_o & `INST_VLE64_V_MASK) == `INST_VLE64_V));

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    v_lsu_pending_q <= 1'b0;
    v_lsu_dest_q    <= 5'b0;
    v_lsu_complete_d <= 1'b0;
    v_lsu_is_load_q <= 1'b0;
end
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
begin
    v_lsu_pending_q <= 1'b0;
    v_lsu_is_load_q <= 1'b0;
end
else if (v_lsu_opcode_valid_o)
begin
    v_lsu_pending_q <= 1'b1;
    v_lsu_dest_q    <= v_lsu_opcode_vd_idx_o;
    v_lsu_is_load_q <= v_lsu_is_load_w;
end
else if (v_lsu_complete_d)
begin
    v_lsu_pending_q <= 1'b0;
    v_lsu_is_load_q <= 1'b0;
end

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    v_lsu_complete_d <= 1'b0;
else
    v_lsu_complete_d <= writeback_v_lsu_valid_i;

//-------------------------------------------------------------
// Issue / scheduling logic
//-------------------------------------------------------------
reg [31:0] scoreboard_r;
reg [31:0] v_scoreboard_r; // new scoreboard for tracking vector registers v0-v31 
reg        pipe1_mux_lsu_r;
reg        pipe1_mux_mul_r;
reg        pipe1_mux_v_alu_r; // new mux for schedule vector instructions 

// Check instructions can be issued in the second execution unit
wire pipe1_ok_w      = issue_b_exec_w | issue_b_branch_w | issue_b_lsu_w | issue_b_mul_w | issue_b_v_alu_w; // new, v_alu added

// Is this combination of instructions possible to execute concurrently.
// This excludes result dependencies which may also block secondary execution.
wire dual_issue_ok_w =   enable_dual_issue_w &&  // Second pipe switched on
                         pipe1_ok_w &&           // Instruction 2 is possible on second exec unit
                        (((issue_a_exec_w | issue_a_lsu_w | issue_a_mul_w) && issue_b_exec_w)   ||
                         ((issue_a_exec_w | issue_a_lsu_w | issue_a_mul_w) && issue_b_v_alu_w)  || // new, v_alu added
                         ((issue_a_exec_w | issue_a_lsu_w | issue_a_mul_w) && issue_b_branch_w) ||
                         ((issue_a_exec_w | issue_a_mul_w) && issue_b_lsu_w)                    ||
                         ((issue_a_exec_w | issue_a_lsu_w) && issue_b_mul_w)
                         ) && ~take_interrupt_i
                         // Do not dual issue when a vector LSU is present (slot0-only resource)
                         && ~issue_a_v_lsu_w && ~issue_b_v_lsu_w;

always @ *
begin
    opcode_a_issue_r     = 1'b0;
    opcode_b_issue_r     = 1'b0;
    opcode_a_accept_r    = 1'b0;
    opcode_b_accept_r    = 1'b0;
    scoreboard_r         = 32'b0;
    v_scoreboard_r       = 32'b0; // new
    pipe1_mux_lsu_r      = 1'b0;
    pipe1_mux_mul_r      = 1'b0;
    pipe1_mux_v_alu_r    = 1'b0; // new

    // Execution units with >= 2 cycle latency
    if (SUPPORT_LOAD_BYPASS == 0)
    begin
        if (pipe0_load_e2_w)
            scoreboard_r[pipe0_rd_e2_w] = 1'b1;
        if (pipe1_load_e2_w)
            scoreboard_r[pipe1_rd_e2_w] = 1'b1;
    end
    if (SUPPORT_MUL_BYPASS == 0)
    begin
        if (pipe0_mul_e2_w)
            scoreboard_r[pipe0_rd_e2_w] = 1'b1;
        if (pipe1_mul_e2_w)
            scoreboard_r[pipe1_rd_e2_w] = 1'b1;
    end

    // Execution units with >= 1 cycle latency (loads / multiply)
    if (pipe0_load_e1_w || pipe0_mul_e1_w)
        scoreboard_r[pipe0_rd_e1_w] = 1'b1;
    if (pipe1_load_e1_w || pipe1_mul_e1_w)
        scoreboard_r[pipe1_rd_e1_w] = 1'b1;
    
    // new
    // Execution unit VALU with >=1 cycle
    if (pipe0_v_alu_e1_w)
        v_scoreboard_r[pipe0_vd_e1_w] = 1'b1;
    if (pipe1_v_alu_e1_w)
        v_scoreboard_r[pipe1_vd_e1_w] = 1'b1;

    // Track pending VLSU destination to stall dependent vector ops
    if (v_lsu_pending_q)
        v_scoreboard_r[v_lsu_dest_q] = 1'b1;


    // Do not start multiply, division or CSR operation in the cycle after a load (leaving only ALU operations and branches)
    if ((pipe0_load_e1_w || pipe0_store_e1_w || pipe1_load_e1_w || pipe1_store_e1_w ) && (issue_a_mul_w || issue_a_div_w || issue_a_csr_w))
        scoreboard_r = 32'hFFFFFFFF;

    // Stall - no issues...
    if (lsu_stall_i || stall_w || div_pending_q || csr_pending_q)
        ;
    // Primary slot (lsu, branch, alu, mul, div, csr)
    // new condition check added for v_scoreboard // EMO - check and condition for issue a
    else if (opcode_a_valid_r &&
        !(scoreboard_r[issue_a_ra_idx_w] || 
          scoreboard_r[issue_a_rb_idx_w] ||
          scoreboard_r[issue_a_rd_idx_w]) &&
        !(v_scoreboard_r[issue_a_va_idx_w] ||
          v_scoreboard_r[issue_a_vb_idx_w] ||
          v_scoreboard_r[issue_a_vd_idx_w]))
    begin
        opcode_a_issue_r  = 1'b1;
        opcode_a_accept_r = 1'b1;

        if (opcode_a_accept_r && issue_a_sb_alloc_w && (|issue_a_rd_idx_w))
            scoreboard_r[issue_a_rd_idx_w] = 1'b1;
        
        //new
        if (opcode_a_accept_r && issue_a_v_sb_alloc_w && (|issue_a_vd_idx_w))
            v_scoreboard_r[issue_a_vd_idx_w] = 1'b1;
    end

    // Stall - no issues...
    if (lsu_stall_i || stall_w || div_pending_q || csr_pending_q)
        ;
    
    // Secondary Slot (lsu, branch, alu, mul)
    // new condition check added for v_scoreboard // EMO - check and condition for issue b
    else if (dual_issue_ok_w && opcode_b_valid_r && opcode_a_accept_r &&
        !(scoreboard_r[issue_b_ra_idx_w] || 
          scoreboard_r[issue_b_rb_idx_w] ||
          scoreboard_r[issue_b_rd_idx_w]) &&
        !(v_scoreboard_r[issue_b_va_idx_w] ||
          v_scoreboard_r[issue_b_vb_idx_w] ||
          v_scoreboard_r[issue_b_vd_idx_w]))
    begin
        opcode_b_issue_r  = 1'b1;
        opcode_b_accept_r = 1'b1;
        pipe1_mux_lsu_r   = issue_b_lsu_w;
        pipe1_mux_mul_r   = issue_b_mul_w; 
        pipe1_mux_v_alu_r = issue_b_v_alu_w; // new

        if (opcode_b_accept_r && issue_b_sb_alloc_w && (|issue_b_rd_idx_w))
            scoreboard_r[issue_b_rd_idx_w] = 1'b1;

        //new
        if (opcode_b_accept_r && issue_b_v_sb_alloc_w && (|issue_b_vd_idx_w))
            v_scoreboard_r[issue_b_vd_idx_w] = 1'b1;
    end    
end

assign lsu_opcode_valid_o   = (pipe1_mux_lsu_r ? opcode_b_issue_r : opcode_a_issue_r) & ~take_interrupt_i;
assign exec0_opcode_valid_o = opcode_a_issue_r;
assign mul_opcode_valid_o   = enable_muldiv_w & (pipe1_mux_mul_r ? opcode_b_issue_r : opcode_a_issue_r);
assign div_opcode_valid_o   = enable_muldiv_w & (opcode_a_issue_r);
assign interrupt_inhibit_o  = csr_pending_q || issue_a_csr_w;
// Only assert VALU valid when the issued slot is actually a VALU op
assign v_alu_opcode_valid_o = enable_vector_operations &
                              (pipe1_mux_v_alu_r ? (opcode_b_issue_r & issue_b_v_alu_w)
                                                 : (opcode_a_issue_r & issue_a_v_alu_w)); // new

assign exec1_opcode_valid_o = opcode_b_issue_r;

assign dual_issue_w         = opcode_b_issue_r & opcode_b_accept_r & ~take_interrupt_i;
assign single_issue_w       = (opcode_a_issue_r & opcode_a_accept_r) & ~dual_issue_w & ~take_interrupt_i;

assign fetch0_accept_o      = ((slot0_valid_r & opcode_a_accept_r) | slot1_valid_r) & ~take_interrupt_i;
assign fetch1_accept_o      = ((slot1_valid_r & opcode_a_accept_r) | (opcode_b_accept_r)) & ~take_interrupt_i;

assign stall_w              = pipe0_stall_raw_w | pipe1_stall_raw_w;

//-------------------------------------------------------------
// Register File
//------------------------------------------------------------- 
wire [31:0] issue_a_ra_value_w;
wire [31:0] issue_a_rb_value_w;
wire [31:0] issue_b_ra_value_w;
wire [31:0] issue_b_rb_value_w;

// Register file: 2W4R
biriscv_regfile
#(
     .SUPPORT_REGFILE_XILINX(SUPPORT_REGFILE_XILINX)
    ,.SUPPORT_DUAL_ISSUE(SUPPORT_DUAL_ISSUE)
)
u_regfile
(
    .clk_i(clk_i),
    .rst_i(rst_i),

    // Write ports
    .rd0_i(pipe0_rd_wb_w),
    .rd0_value_i(pipe0_result_wb_w),
    .rd1_i(pipe1_rd_wb_w),
    .rd1_value_i(pipe1_result_wb_w),

    // Read ports
    .ra0_i(issue_a_ra_idx_w),
    .rb0_i(issue_a_rb_idx_w),
    .ra0_value_o(issue_a_ra_value_w),
    .rb0_value_o(issue_a_rb_value_w),

    .ra1_i(issue_b_ra_idx_w),
    .rb1_i(issue_b_rb_idx_w),
    .ra1_value_o(issue_b_ra_value_w),
    .rb1_value_o(issue_b_rb_value_w)    
);

//new
//-------------------------------------------------------------
// Vector Register File
//------------------------------------------------------------- 
wire [VLEN-1:0] issue_a_va_value_w;
wire [VLEN-1:0] issue_a_vb_value_w;
wire [VLEN-1:0] issue_b_va_value_w;
wire [VLEN-1:0] issue_b_vb_value_w;

// Gate writeback into the vector regfile so we don't clobber registers when no valid vector writeback is present
wire        vreg_wr0_vec_alu_w = pipe0_v_alu_wb_w;
wire        vreg_wr0_vlsu_w    = writeback_v_lsu_valid_i & v_lsu_is_load_q;
wire [4:0]  vreg_wr0_idx_w     = vreg_wr0_vlsu_w ? writeback_v_lsu_vd_idx_i :
                                 vreg_wr0_vec_alu_w ? pipe0_vd_wb_w : 5'd0;
wire [VLEN-1:0] vreg_wr0_val_w = vreg_wr0_vlsu_w ? writeback_v_lsu_value_i :
                                 vreg_wr0_vec_alu_w ? pipe0_v_alu_result_wb_w : {VLEN{1'b0}};

// Vector Register file
biriscv_v_regfile
#(
     .SUPPORT_REGFILE_XILINX(SUPPORT_REGFILE_XILINX)
    ,.SUPPORT_DUAL_ISSUE(SUPPORT_DUAL_ISSUE)
    ,.VLEN(VLEN)
)
u_v_regfile
(
    .clk_i(clk_i),
    .rst_i(rst_i),

    // Write ports
    .rd0_i(vreg_wr0_idx_w),
    .rd0_value_i(vreg_wr0_val_w),
    .rd1_i(pipe1_vd_wb_w),
    .rd1_value_i(pipe1_v_alu_result_wb_w),

    // Read ports
    .ra0_i(issue_a_va_idx_w),
    .rb0_i(issue_a_vsrc_idx_w),
    .ra0_value_o(issue_a_va_value_w),
    .rb0_value_o(issue_a_vb_value_w),

    .ra1_i(issue_b_va_idx_w),
    .rb1_i(issue_b_vb_idx_w),
    .ra1_value_o(issue_b_va_value_w),
    .rb1_value_o(issue_b_vb_value_w)    
);


//-------------------------------------------------------------
// Issue Slot 0
//------------------------------------------------------------- 
assign opcode0_opcode_o = opcode_a_r;
assign opcode0_pc_o     = opcode_a_pc_r;
assign opcode0_rd_idx_o = issue_a_rd_idx_w;
assign opcode0_ra_idx_o = issue_a_ra_idx_w;
assign opcode0_rb_idx_o = issue_a_rb_idx_w;
assign opcode0_invalid_o= 1'b0;

assign opcode0_vd_idx_o = issue_a_vd_idx_w; // new
assign opcode0_va_idx_o = issue_a_va_idx_w; // new
assign opcode0_vb_idx_o = issue_a_vb_idx_w; // new

reg [31:0] issue_a_ra_value_r;
reg [31:0] issue_a_rb_value_r;
reg [VLEN-1:0] issue_a_va_value_r; // new
reg [VLEN-1:0] issue_a_vb_value_r; // new

always @ *
begin
    // NOTE: Newest version of operand takes priority
    issue_a_ra_value_r = issue_a_ra_value_w;
    issue_a_rb_value_r = issue_a_rb_value_w;

    issue_a_va_value_r = issue_a_va_value_w; // new
    issue_a_vb_value_r = issue_a_vb_value_w; // new

    // Bypass - WB
    if (pipe0_rd_wb_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = pipe0_result_wb_w;
    if (pipe0_rd_wb_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = pipe0_result_wb_w;

    if (pipe1_rd_wb_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = pipe1_result_wb_w;
    if (pipe1_rd_wb_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = pipe1_result_wb_w;

    // new
    // Bypass for Vector - WB 
    if (!issue_a_v_lsu_w) begin
        if (pipe0_v_alu_wb_w && (pipe0_vd_wb_w == issue_a_va_idx_w))
            issue_a_va_value_r = pipe0_v_alu_result_wb_w;
        if (pipe0_v_alu_wb_w && (pipe0_vd_wb_w == issue_a_vb_idx_w))
            issue_a_vb_value_r = pipe0_v_alu_result_wb_w;

        if (pipe1_v_alu_wb_w && (pipe1_vd_wb_w == issue_a_va_idx_w))
            issue_a_va_value_r = pipe1_v_alu_result_wb_w;
        if (pipe1_v_alu_wb_w && (pipe1_vd_wb_w == issue_a_vb_idx_w))
            issue_a_vb_value_r = pipe1_v_alu_result_wb_w;
    end

    // Bypass from VLSU writeback
    if (writeback_v_lsu_valid_i && v_lsu_is_load_q && (writeback_v_lsu_vd_idx_i == issue_a_va_idx_w))
        issue_a_va_value_r = writeback_v_lsu_value_i;
    if (writeback_v_lsu_valid_i && v_lsu_is_load_q && (writeback_v_lsu_vd_idx_i == issue_a_vsrc_idx_w))
        issue_a_vb_value_r = writeback_v_lsu_value_i;

    // Bypass - E2
    if (pipe0_rd_e2_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = pipe0_result_e2_w;
    if (pipe0_rd_e2_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = pipe0_result_e2_w;

    if (pipe1_rd_e2_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = pipe1_result_e2_w;
    if (pipe1_rd_e2_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = pipe1_result_e2_w;

    // new
    // Bypass for Vector - E2
    if (!issue_a_v_lsu_w) begin
        if (pipe0_v_alu_e2_w && (pipe0_vd_e2_w == issue_a_va_idx_w))
            issue_a_va_value_r = pipe0_v_alu_result_e2_w;
        if (pipe0_v_alu_e2_w && (pipe0_vd_e2_w == issue_a_vsrc_idx_w))
            issue_a_vb_value_r = pipe0_v_alu_result_e2_w;

        if (pipe1_v_alu_e2_w && (pipe1_vd_e2_w == issue_a_va_idx_w))
            issue_a_va_value_r = pipe1_v_alu_result_e2_w;
        if (pipe1_v_alu_e2_w && (pipe1_vd_e2_w == issue_a_vsrc_idx_w))
            issue_a_vb_value_r = pipe1_v_alu_result_e2_w;
    end

    // Bypass - E1
    if (pipe0_rd_e1_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = writeback_exec0_value_i;
    if (pipe0_rd_e1_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = writeback_exec0_value_i;

    if (pipe1_rd_e1_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = writeback_exec1_value_i;
    if (pipe1_rd_e1_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = writeback_exec1_value_i;

    // new
    // EMO - Check here compare with regular registers
    // Should 1 writeback value is enough or not
    // Bypass for Vector - E1
    if (!issue_a_v_lsu_w) begin
        if (pipe0_v_alu_e1_w && (pipe0_vd_e1_w == issue_a_va_idx_w))
            issue_a_va_value_r = writeback_v_alu_value_i;
        if (pipe0_v_alu_e1_w && (pipe0_vd_e1_w == issue_a_vsrc_idx_w))
            issue_a_vb_value_r = writeback_v_alu_value_i;

        if (pipe1_v_alu_e1_w && (pipe1_vd_e1_w == issue_a_va_idx_w))
            issue_a_va_value_r = writeback_v_alu_value_i;
        if (pipe1_v_alu_e1_w && (pipe1_vd_e1_w == issue_a_vsrc_idx_w))
            issue_a_vb_value_r = writeback_v_alu_value_i;
    end

    // Reg 0 source
    if (issue_a_ra_idx_w == 5'b0)
        issue_a_ra_value_r = 32'b0;
    if (issue_a_rb_idx_w == 5'b0)
        issue_a_rb_value_r = 32'b0;

    // new
    // Reg v0 source
    if (issue_a_va_idx_w == 5'b0)
        issue_a_va_value_r = 32'b0;
    if (issue_a_vsrc_idx_w == 5'b0)
        issue_a_vb_value_r = 32'b0;
end

assign opcode0_ra_operand_o = issue_a_ra_value_r;
assign opcode0_rb_operand_o = issue_a_rb_value_r;
assign opcode0_va_operand_o = issue_a_va_value_r; // new
assign opcode0_vb_operand_o = issue_a_vb_value_r; // new
assign opcode0_vmask_operand_o = {VLEN{1'b0}};

//-------------------------------------------------------------
// Issue Slot 1
//------------------------------------------------------------- 
assign opcode1_opcode_o = opcode_b_r;
assign opcode1_pc_o     = opcode_b_pc_r;
assign opcode1_rd_idx_o = issue_b_rd_idx_w;
assign opcode1_ra_idx_o = issue_b_ra_idx_w;
assign opcode1_rb_idx_o = issue_b_rb_idx_w;
assign opcode1_invalid_o= 1'b0;

assign opcode1_vd_idx_o = issue_b_vd_idx_w; // new
assign opcode1_va_idx_o = issue_b_va_idx_w; // new
assign opcode1_vb_idx_o = issue_b_vb_idx_w; // new

reg [31:0] issue_b_ra_value_r;
reg [31:0] issue_b_rb_value_r;
reg [VLEN-1:0] issue_b_va_value_r; // new
reg [VLEN-1:0] issue_b_vb_value_r; // new

always @ *
begin
    // NOTE: Newest version of operand takes priority
    issue_b_ra_value_r = issue_b_ra_value_w;
    issue_b_rb_value_r = issue_b_rb_value_w;

    issue_b_va_value_r = issue_b_va_value_w; // new
    issue_b_vb_value_r = issue_b_vb_value_w; // new

    // Bypass - WB
    if (pipe0_rd_wb_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = pipe0_result_wb_w;
    if (pipe0_rd_wb_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = pipe0_result_wb_w;

    if (pipe1_rd_wb_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = pipe1_result_wb_w;
    if (pipe1_rd_wb_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = pipe1_result_wb_w;

    // new
    // Bypass for Vector - WB 
    if (pipe0_v_alu_wb_w && (pipe0_vd_wb_w == issue_b_va_idx_w))
        issue_b_va_value_r = pipe0_v_alu_result_wb_w;
    if (pipe0_v_alu_wb_w && (pipe0_vd_wb_w == issue_b_vb_idx_w))
        issue_b_vb_value_r = pipe0_v_alu_result_wb_w;

    if (pipe1_v_alu_wb_w && (pipe1_vd_wb_w == issue_b_va_idx_w))
        issue_b_va_value_r = pipe1_v_alu_result_wb_w;
    if (pipe1_v_alu_wb_w && (pipe1_vd_wb_w == issue_b_vb_idx_w))
        issue_b_vb_value_r = pipe1_v_alu_result_wb_w;

    // Bypass from VLSU writeback
    if (writeback_v_lsu_valid_i && v_lsu_is_load_q && (writeback_v_lsu_vd_idx_i == issue_b_va_idx_w))
        issue_b_va_value_r = writeback_v_lsu_value_i;
    if (writeback_v_lsu_valid_i && v_lsu_is_load_q && (writeback_v_lsu_vd_idx_i == issue_b_vb_idx_w))
        issue_b_vb_value_r = writeback_v_lsu_value_i;

    // Bypass - E2
    if (pipe0_rd_e2_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = pipe0_result_e2_w;
    if (pipe0_rd_e2_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = pipe0_result_e2_w;

    if (pipe1_rd_e2_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = pipe1_result_e2_w;
    if (pipe1_rd_e2_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = pipe1_result_e2_w;

    // new
    // Bypass for Vector - E2
    if (pipe0_v_alu_e2_w && (pipe0_vd_e2_w == issue_b_va_idx_w))
        issue_b_va_value_r = pipe0_v_alu_result_e2_w;
    if (pipe0_v_alu_e2_w && (pipe0_vd_e2_w == issue_b_vb_idx_w))
        issue_b_vb_value_r = pipe0_v_alu_result_e2_w;

    if (pipe1_v_alu_e2_w && (pipe1_vd_e2_w == issue_b_va_idx_w))
        issue_b_va_value_r = pipe1_v_alu_result_e2_w;
    if (pipe1_v_alu_e2_w && (pipe1_vd_e2_w == issue_b_vb_idx_w))
        issue_b_vb_value_r = pipe1_v_alu_result_e2_w;

    // Bypass - E1
    if (pipe0_rd_e1_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = writeback_exec0_value_i;
    if (pipe0_rd_e1_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = writeback_exec0_value_i;

    if (pipe1_rd_e1_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = writeback_exec1_value_i;
    if (pipe1_rd_e1_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = writeback_exec1_value_i;

    // new
    // EMO - Check here compare with regular registers
    // Should 1 writeback value is enough or not
    // Bypass for Vector - E1
    if (pipe0_v_alu_e1_w && (pipe0_vd_e1_w == issue_b_va_idx_w))
        issue_b_va_value_r = writeback_v_alu_value_i;
    if (pipe0_v_alu_e1_w && (pipe0_vd_e1_w == issue_b_vb_idx_w))
        issue_b_vb_value_r = writeback_v_alu_value_i;

    if (pipe1_v_alu_e1_w && (pipe1_vd_e1_w == issue_b_va_idx_w))
        issue_b_va_value_r = writeback_v_alu_value_i;
    if (pipe1_v_alu_e1_w && (pipe1_vd_e1_w == issue_b_vb_idx_w))
        issue_b_vb_value_r = writeback_v_alu_value_i;

    // Reg 0 source
    if (issue_b_ra_idx_w == 5'b0)
        issue_b_ra_value_r = 32'b0;
    if (issue_b_rb_idx_w == 5'b0)
        issue_b_rb_value_r = 32'b0;

    // new
    // Reg v0 source
    if (issue_b_va_idx_w == 5'b0)
        issue_b_va_value_r = 32'b0;
    if (issue_b_vb_idx_w == 5'b0)
        issue_b_vb_value_r = 32'b0;
end

assign opcode1_ra_operand_o = issue_b_ra_value_r;
assign opcode1_rb_operand_o = issue_b_rb_value_r;
assign opcode1_va_operand_o = issue_b_va_value_r; // new
assign opcode1_vb_operand_o = issue_b_vb_value_r; // new

//-------------------------------------------------------------
// Load store unit
//-------------------------------------------------------------
assign lsu_opcode_opcode_o      = pipe1_mux_lsu_r ? opcode1_opcode_o     : opcode0_opcode_o;
assign lsu_opcode_pc_o          = pipe1_mux_lsu_r ? opcode1_pc_o         : opcode0_pc_o;
assign lsu_opcode_rd_idx_o      = pipe1_mux_lsu_r ? opcode1_rd_idx_o     : opcode0_rd_idx_o;
assign lsu_opcode_ra_idx_o      = pipe1_mux_lsu_r ? opcode1_ra_idx_o     : opcode0_ra_idx_o;
assign lsu_opcode_rb_idx_o      = pipe1_mux_lsu_r ? opcode1_rb_idx_o     : opcode0_rb_idx_o;
assign lsu_opcode_ra_operand_o  = pipe1_mux_lsu_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign lsu_opcode_rb_operand_o  = pipe1_mux_lsu_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign lsu_opcode_invalid_o     = 1'b0;

//-------------------------------------------------------------
// Multiply
//-------------------------------------------------------------
assign mul_opcode_opcode_o      = pipe1_mux_mul_r ? opcode1_opcode_o     : opcode0_opcode_o;
assign mul_opcode_pc_o          = pipe1_mux_mul_r ? opcode1_pc_o         : opcode0_pc_o;
assign mul_opcode_rd_idx_o      = pipe1_mux_mul_r ? opcode1_rd_idx_o     : opcode0_rd_idx_o;
assign mul_opcode_ra_idx_o      = pipe1_mux_mul_r ? opcode1_ra_idx_o     : opcode0_ra_idx_o;
assign mul_opcode_rb_idx_o      = pipe1_mux_mul_r ? opcode1_rb_idx_o     : opcode0_rb_idx_o;
assign mul_opcode_ra_operand_o  = pipe1_mux_mul_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mul_opcode_rb_operand_o  = pipe1_mux_mul_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mul_opcode_invalid_o     = 1'b0;

//-------------------------------------------------------------
// CSR unit
//-------------------------------------------------------------
assign csr_opcode_valid_o       = opcode_a_issue_r & ~take_interrupt_i;
assign csr_opcode_opcode_o      = opcode0_opcode_o;
assign csr_opcode_pc_o          = opcode0_pc_o;
assign csr_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign csr_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign csr_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign csr_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign csr_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign csr_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

// new
//-------------------------------------------------------------
// Vector ALU (VALU) unit
//-------------------------------------------------------------
assign v_alu_opcode_opcode_o    = pipe1_mux_v_alu_r ? opcode1_opcode_o : opcode0_opcode_o;
assign v_alu_opcode_pc_o        = pipe1_mux_v_alu_r ? opcode1_pc_o     : opcode0_pc_o;
assign v_alu_opcode_vd_idx_o    = pipe1_mux_v_alu_r ? opcode1_vd_idx_o : opcode0_vd_idx_o;
assign v_alu_opcode_va_idx_o    = pipe1_mux_v_alu_r ? opcode1_va_idx_o : opcode0_va_idx_o;
assign v_alu_opcode_vb_idx_o    = pipe1_mux_v_alu_r ? opcode1_vb_idx_o : opcode0_vb_idx_o;
assign v_alu_opcode_ra_idx_o    = pipe1_mux_v_alu_r ? opcode1_ra_idx_o : opcode0_ra_idx_o;
assign v_alu_opcode_rb_idx_o    = pipe1_mux_v_alu_r ? opcode1_rb_idx_o : opcode0_rb_idx_o;
assign v_alu_opcode_ra_operand_o= pipe1_mux_v_alu_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign v_alu_opcode_rb_operand_o= pipe1_mux_v_alu_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign v_alu_opcode_va_operand_o= pipe1_mux_v_alu_r ? opcode1_va_operand_o : opcode0_va_operand_o;
assign v_alu_opcode_vb_operand_o= pipe1_mux_v_alu_r ? opcode1_vb_operand_o : opcode0_vb_operand_o;
assign v_alu_opcode_vmask_operand_o= pipe1_mux_v_alu_r ? opcode1_vmask_operand_o : opcode0_vmask_operand_o;
assign v_alu_opcode_invalid_o    = 1'b0;

//-------------------------------------------------------------
// Vector LSU (slot0 only)
//-------------------------------------------------------------
assign v_lsu_opcode_valid_o         = enable_vector_operations & opcode_a_issue_r & issue_a_v_lsu_w;
assign v_lsu_opcode_opcode_o        = opcode0_opcode_o;
assign v_lsu_opcode_pc_o            = opcode0_pc_o;
assign v_lsu_opcode_invalid_o       = opcode0_invalid_o;
assign v_lsu_opcode_rd_idx_o        = opcode0_rd_idx_o;
assign v_lsu_opcode_ra_idx_o        = opcode0_ra_idx_o;
assign v_lsu_opcode_rb_idx_o        = opcode0_rb_idx_o;
assign v_lsu_opcode_vd_idx_o        = opcode0_vd_idx_o;
assign v_lsu_opcode_va_idx_o        = opcode0_va_idx_o;
// Vector stores source data from vd (vs3), not the vs2/vb field. Use the VB operand channel to carry vd.
assign v_lsu_opcode_vb_idx_o        = opcode0_vd_idx_o;
assign v_lsu_opcode_ra_operand_o    = opcode0_ra_operand_o;
assign v_lsu_opcode_rb_operand_o    = opcode0_rb_operand_o;
assign v_lsu_opcode_va_operand_o    = opcode0_va_operand_o;
assign v_lsu_opcode_vb_operand_o    = opcode0_vb_operand_o;
assign v_lsu_opcode_vmask_operand_o = opcode0_vmask_operand_o;

//-------------------------------------------------------------
// Checker Interface
//-------------------------------------------------------------
`ifdef verilator
biriscv_trace_sim
u_pipe0_dec0_verif
(
     .valid_i(pipe0_valid_wb_w)
    ,.pc_i(pipe0_pc_wb_w)
    ,.opcode_i(pipe0_opc_wb_w)
);

wire [4:0] v_pipe0_rs1_w = pipe0_opc_wb_w[19:15];
wire [4:0] v_pipe0_rs2_w = pipe0_opc_wb_w[24:20];

function [0:0] complete_valid0; /*verilator public*/
begin
    complete_valid0 = pipe0_valid_wb_w;
end
endfunction
function [31:0] complete_pc0; /*verilator public*/
begin
    complete_pc0 = pipe0_pc_wb_w;
end
endfunction
function [31:0] complete_opcode0; /*verilator public*/
begin
    complete_opcode0 = pipe0_opc_wb_w;
end
endfunction
function [4:0] complete_ra0; /*verilator public*/
begin
    complete_ra0 = v_pipe0_rs1_w;
end
endfunction
function [4:0] complete_rb0; /*verilator public*/
begin
    complete_rb0 = v_pipe0_rs2_w;
end
endfunction
function [4:0] complete_rd0; /*verilator public*/
begin
    complete_rd0 = pipe0_rd_wb_w;
end
endfunction
function [31:0] complete_ra_val0; /*verilator public*/
begin
    complete_ra_val0 = pipe0_ra_val_wb_w;
end
endfunction
function [31:0] complete_rb_val0; /*verilator public*/
begin
    complete_rb_val0 = pipe0_rb_val_wb_w;
end
endfunction
function [31:0] complete_rd_val0; /*verilator public*/
begin
    if (|pipe0_rd_wb_w)
        complete_rd_val0 = pipe0_result_wb_w;
    else
        complete_rd_val0 = 32'b0;
end
endfunction

biriscv_trace_sim
u_pipe0_dec1_verif
(
     .valid_i(pipe1_valid_wb_w)
    ,.pc_i(pipe1_pc_wb_w)
    ,.opcode_i(pipe1_opc_wb_w)
);

wire [4:0] v_pipe1_rs1_w = pipe1_opc_wb_w[19:15];
wire [4:0] v_pipe1_rs2_w = pipe1_opc_wb_w[24:20];

function [0:0] complete_valid1; /*verilator public*/
begin
    complete_valid1 = pipe1_valid_wb_w;
end
endfunction
function [31:0] complete_pc1; /*verilator public*/
begin
    complete_pc1 = pipe1_pc_wb_w;
end
endfunction
function [31:0] complete_opcode1; /*verilator public*/
begin
    complete_opcode1 = pipe1_opc_wb_w;
end
endfunction
function [4:0] complete_ra1; /*verilator public*/
begin
    complete_ra1 = v_pipe1_rs1_w;
end
endfunction
function [4:0] complete_rb1; /*verilator public*/
begin
    complete_rb1 = v_pipe1_rs2_w;
end
endfunction
function [4:0] complete_rd1; /*verilator public*/
begin
    complete_rd1 = pipe1_rd_wb_w;
end
endfunction
function [31:0] complete_ra_val1; /*verilator public*/
begin
    complete_ra_val1 = pipe1_ra_val_wb_w;
end
endfunction
function [31:0] complete_rb_val1; /*verilator public*/
begin
    complete_rb_val1 = pipe1_rb_val_wb_w;
end
endfunction
function [31:0] complete_rd_val1; /*verilator public*/
begin
    if (|pipe1_rd_wb_w)
        complete_rd_val1 = pipe1_result_wb_w;
    else
        complete_rd_val1 = 32'b0;
end
endfunction
function [5:0] complete_exception; /*verilator public*/
begin
    complete_exception = pipe0_exception_wb_w | pipe1_exception_wb_w;
end
endfunction
`endif


endmodule
