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
module biriscv_pipe_ctrl
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter SUPPORT_LOAD_BYPASS = 1
    ,parameter SUPPORT_MUL_BYPASS  = 1
    ,parameter VLEN = 128
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
     input           clk_i
    ,input           rst_i

    // Issue
    ,input           issue_valid_i
    ,input           issue_accept_i
    ,input           issue_stall_i
    ,input           issue_lsu_i
    ,input           issue_csr_i
    ,input           issue_div_i
    ,input           issue_mul_i
    ,input           issue_branch_i
    ,input           issue_v_alu_i // new
    ,input           issue_v_lsu_i // new
    ,input           issue_vd_valid_i // new // EMO - check where this signal comes from!
    ,input           issue_rd_valid_i
    // EMO - Check if vd_valid_i needed here 
    ,input  [4:0]    issue_rd_i
    ,input  [4:0]    issue_vd_i // new
    ,input  [5:0]    issue_exception_i
    ,input           take_interrupt_i
    ,input           issue_branch_taken_i
    ,input [31:0]    issue_branch_target_i
    ,input [31:0]    issue_pc_i
    ,input [31:0]    issue_opcode_i
    ,input [31:0]    issue_operand_ra_i
    ,input [31:0]    issue_operand_rb_i

    // Vector register inputs
    ,input [VLEN-1:0]    issue_operand_va_i // new
    ,input [VLEN-1:0]    issue_operand_vb_i // new
    ,input [VLEN-1:0]    issue_operand_vmask_i // new

    // Execution stage 1: ALU result
    ,input [31:0]    alu_result_e1_i

    // Execution stage 1: CSR read result / early exceptions
    ,input [ 31:0]   csr_result_value_e1_i
    ,input           csr_result_write_e1_i
    ,input [ 31:0]   csr_result_wdata_e1_i
    ,input [  5:0]   csr_result_exception_e1_i

    // Execution stage 1
    ,output          load_e1_o
    ,output          store_e1_o
    ,output          mul_e1_o
    ,output          branch_e1_o
    ,output          v_alu_e1_o // new
    ,output          v_lsu_e1_o // new
    ,output [4:0]    vd_e1_o // new
    ,output [4:0]    rd_e1_o
    ,output [31:0]   pc_e1_o
    ,output [31:0]   opcode_e1_o
    ,output [31:0]   operand_ra_e1_o
    ,output [31:0]   operand_rb_e1_o

    // Vector register outputs for stage 1
    ,output [VLEN-1:0] v_alu_operand_va_e1_o // new
    ,output [VLEN-1:0] v_alu_operand_vb_e1_o  // new
    ,output [VLEN-1:0] v_alu_operand_vmask_e1_o // new
    ,output [VLEN-1:0] v_lsu_operand_va_e1_o // new
    ,output [VLEN-1:0] v_lsu_operand_vb_e1_o  // new
    ,output [VLEN-1:0] v_lsu_operand_vmask_e1_o // new

    // Execution stage 2: Other results
    ,input           mem_complete_i
    ,input [31:0]    mem_result_e2_i
    ,input  [5:0]    mem_exception_e2_i
    ,input [31:0]    mul_result_e2_i

    // Execution stage 2
    ,output          load_e2_o
    ,output          mul_e2_o
    ,output [  4:0]  rd_e2_o
    ,output [  4:0]  vd_e2_o // new
    ,output [31:0]   result_e2_o

    // Vector register outputs for stage 2
    ,output          v_alu_e2_o
    ,output [VLEN-1:0] v_alu_result_e2_o // new

    // Out of pipe: Divide Result
    ,input           div_complete_i
    ,input  [31:0]   div_result_i

    // Vector ALU Result
    ,input            v_alu_complete_i // new
    ,input [VLEN-1:0] v_alu_result_i // new
    // Vector LSU completion (long latency)
    ,input            v_lsu_complete_i // new

    // Outputs to Vector ALU
    ,output [VLEN-1:0] operand_va_wb_o // new, for debug
    ,output [VLEN-1:0] operand_vb_wb_o // new, for debug
    ,output [VLEN-1:0] mask_vm_wb_o // new, for debug

    // Commit
    ,output          valid_wb_o
    ,output          csr_wb_o
    ,output [  4:0]  rd_wb_o
    ,output [  4:0]  vd_wb_o // new
    ,output [VLEN-1:0] v_alu_result_wb_o // new
    ,output [31:0]   result_wb_o
    ,output [31:0]   pc_wb_o
    ,output [31:0]   opcode_wb_o
    ,output [31:0]   operand_ra_wb_o
    ,output [31:0]   operand_rb_wb_o
    ,output [5:0]    exception_wb_o
    ,output          csr_write_wb_o
    ,output [11:0]   csr_waddr_wb_o
    ,output [31:0]   csr_wdata_wb_o

    ,output          stall_o
    ,output          squash_e1_e2_o
    ,input           squash_e1_e2_i
    ,input           squash_wb_i
);

//-------------------------------------------------------------
// Includes
//-------------------------------------------------------------
`include "biriscv_defs.v"

wire squash_e1_e2_w;
wire branch_misaligned_w = (issue_branch_taken_i && issue_branch_target_i[1:0] != 2'b0);

//-------------------------------------------------------------
// E1 / Address
//------------------------------------------------------------- 
`define PCINFO_W     13 // was 10 before, updated to 13 to add v_alu and v_lsu and vd_valid
`define PCINFO_VD_VALID  12 // new
`define PCINFO_V_LSU     11
`define PCINFO_V_ALU     10
`define PCINFO_ALU       0
`define PCINFO_LOAD      1
`define PCINFO_STORE     2
`define PCINFO_CSR       3
`define PCINFO_DIV       4
`define PCINFO_MUL       5
`define PCINFO_BRANCH    6
`define PCINFO_RD_VALID  7
`define PCINFO_INTR      8
`define PCINFO_COMPLETE  9

`define len 128

`define RD_IDX_R    11:7
`define VD_IDX_R    11:7 // new

reg                     valid_e1_q;
reg [`PCINFO_W-1:0]     ctrl_e1_q;
reg [31:0]              pc_e1_q;
reg [31:0]              npc_e1_q;
reg [31:0]              opcode_e1_q;
reg [31:0]              operand_ra_e1_q;
reg [31:0]              operand_rb_e1_q;
reg [`EXCEPTION_W-1:0]  exception_e1_q;
reg [VLEN-1:0]          operand_va_e1_q; //new
reg [VLEN-1:0]          operand_vb_e1_q; //new
reg [VLEN-1:0]           mask_vm_e1_q; //new

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    valid_e1_q      <= 1'b0;
    ctrl_e1_q       <= `PCINFO_W'b0;
    pc_e1_q         <= 32'b0;
    npc_e1_q        <= 32'b0;
    opcode_e1_q     <= 32'b0;
    operand_ra_e1_q <= 32'b0;
    operand_rb_e1_q <= 32'b0;
    exception_e1_q  <= `EXCEPTION_W'b0;
    operand_va_e1_q <= `len'b0; // new
    operand_vb_e1_q <= `len'b0; // new
    mask_vm_e1_q    <= `len'b0; // new
end
// Stall - no change in E1 state
else if (issue_stall_i)
    ;
else if ((issue_valid_i && issue_accept_i) && ~(squash_e1_e2_o || squash_e1_e2_i))
begin
    valid_e1_q                  <= 1'b1;
    ctrl_e1_q[`PCINFO_V_LSU]    <= issue_v_lsu_i & ~take_interrupt_i; // new
    ctrl_e1_q[`PCINFO_V_ALU]    <= issue_v_alu_i & ~take_interrupt_i; // new
    ctrl_e1_q[`PCINFO_ALU]      <= ~(issue_lsu_i | issue_csr_i | issue_div_i | issue_mul_i);
    ctrl_e1_q[`PCINFO_LOAD]     <= issue_lsu_i &  issue_rd_valid_i & ~take_interrupt_i; // TODO: Check
    ctrl_e1_q[`PCINFO_STORE]    <= issue_lsu_i & ~issue_rd_valid_i & ~take_interrupt_i;
    ctrl_e1_q[`PCINFO_CSR]      <= issue_csr_i & ~take_interrupt_i;
    ctrl_e1_q[`PCINFO_DIV]      <= issue_div_i & ~take_interrupt_i;
    ctrl_e1_q[`PCINFO_MUL]      <= issue_mul_i & ~take_interrupt_i;
    ctrl_e1_q[`PCINFO_BRANCH]   <= issue_branch_i & ~take_interrupt_i;
    ctrl_e1_q[`PCINFO_RD_VALID] <= issue_rd_valid_i & ~take_interrupt_i;
    ctrl_e1_q[`PCINFO_VD_VALID] <= issue_vd_valid_i & ~take_interrupt_i; // new
    ctrl_e1_q[`PCINFO_INTR]     <= take_interrupt_i;
    ctrl_e1_q[`PCINFO_COMPLETE] <= 1'b1;

    pc_e1_q         <= issue_pc_i;
    npc_e1_q        <= issue_branch_taken_i ? issue_branch_target_i : issue_pc_i + 32'd4;
    opcode_e1_q     <= issue_opcode_i;
    operand_ra_e1_q <= issue_operand_ra_i;
    operand_rb_e1_q <= issue_operand_rb_i;
    exception_e1_q  <= (|issue_exception_i) ? issue_exception_i : 
                       branch_misaligned_w  ? `EXCEPTION_MISALIGNED_FETCH : `EXCEPTION_W'b0;
    operand_va_e1_q <= issue_operand_va_i; // new
    operand_vb_e1_q <= issue_operand_vb_i; // new
    mask_vm_e1_q    <= issue_operand_vmask_i; // new
end
// No valid instruction (or pipeline flush event)
else
begin
    valid_e1_q      <= 1'b0;
    ctrl_e1_q       <= `PCINFO_W'b0;
    pc_e1_q         <= 32'b0;
    npc_e1_q        <= 32'b0;
    opcode_e1_q     <= 32'b0;
    operand_ra_e1_q <= 32'b0;
    operand_rb_e1_q <= 32'b0;
    exception_e1_q  <= `EXCEPTION_W'b0;
    operand_va_e1_q <= `len'b0; // new
    operand_va_e1_q <= `len'b0; // new
    mask_vm_e1_q    <= `len'b0; // new
end

wire   alu_e1_w        = ctrl_e1_q[`PCINFO_ALU];
assign load_e1_o       = ctrl_e1_q[`PCINFO_LOAD];
assign store_e1_o      = ctrl_e1_q[`PCINFO_STORE];
wire   csr_e1_w        = ctrl_e1_q[`PCINFO_CSR];
wire   div_e1_w        = ctrl_e1_q[`PCINFO_DIV];
assign mul_e1_o        = ctrl_e1_q[`PCINFO_MUL];
assign branch_e1_o     = ctrl_e1_q[`PCINFO_BRANCH];
assign v_alu_e1_o      = ctrl_e1_q[`PCINFO_V_ALU]; // new
assign vd_e1_o         = {5{ctrl_e1_q[`PCINFO_VD_VALID]}} & opcode_e1_q[`VD_IDX_R]; // new
assign rd_e1_o         = {5{ctrl_e1_q[`PCINFO_RD_VALID]}} & opcode_e1_q[`RD_IDX_R];
assign pc_e1_o         = pc_e1_q;
assign opcode_e1_o     = opcode_e1_q;
assign operand_ra_e1_o = operand_ra_e1_q;
assign operand_rb_e1_o = operand_rb_e1_q;
assign v_alu_operand_va_e1_o = operand_va_e1_q; // new
assign v_alu_operand_vb_e1_o = operand_vb_e1_q; // new
assign v_alu_operand_vmask_e1_o = mask_vm_e1_q; // new
assign v_lsu_e1_o      = ctrl_e1_q[`PCINFO_V_LSU]; // new
assign v_lsu_operand_va_e1_o = operand_va_e1_q; // new
assign v_lsu_operand_vb_e1_o = operand_vb_e1_q; // new
assign v_lsu_operand_vmask_e1_o = mask_vm_e1_q; // new
assign v_alu_e1_o      = ctrl_e1_q[`PCINFO_V_ALU]; // new

//-------------------------------------------------------------
// E2 / Mem result
//------------------------------------------------------------- 
reg                     valid_e2_q;
reg [`PCINFO_W-1:0]     ctrl_e2_q;
reg                     csr_wr_e2_q;
reg [31:0]              csr_wdata_e2_q;
reg [31:0]              result_e2_q;
reg [31:0]              pc_e2_q;
reg [31:0]              npc_e2_q;
reg [31:0]              opcode_e2_q;
reg [31:0]              operand_ra_e2_q;
reg [31:0]              operand_rb_e2_q;
reg [`EXCEPTION_W-1:0]  exception_e2_q;
reg [VLEN-1:0]          operand_va_e2_q; // new
reg [VLEN-1:0]          operand_vb_e2_q; // new
reg [VLEN-1:0]          mask_vm_e2_q; // new
reg [VLEN-1:0]          v_alu_result_e2_q; // new

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    valid_e2_q      <= 1'b0;
    ctrl_e2_q       <= `PCINFO_W'b0;
    csr_wr_e2_q     <= 1'b0;
    csr_wdata_e2_q  <= 32'b0;
    pc_e2_q         <= 32'b0;
    npc_e2_q        <= 32'b0;
    opcode_e2_q     <= 32'b0;
    operand_ra_e2_q <= 32'b0;
    operand_rb_e2_q <= 32'b0;
    result_e2_q     <= 32'b0;
    exception_e2_q  <= `EXCEPTION_W'b0;
    operand_va_e2_q <= `len'b0; // new
    operand_vb_e2_q <= `len'b0; // new
    mask_vm_e2_q    <= `len'b0; // new
    v_alu_result_e2_q <= `len'b0; // new
end
// Stall - no change in E2 state
else if (issue_stall_i)
    ;
// Pipeline flush
else if (squash_e1_e2_o || squash_e1_e2_i)
begin
    valid_e2_q      <= 1'b0;
    ctrl_e2_q       <= `PCINFO_W'b0;
    csr_wr_e2_q     <= 1'b0;
    csr_wdata_e2_q  <= 32'b0;
    pc_e2_q         <= 32'b0;
    npc_e2_q        <= 32'b0;
    opcode_e2_q     <= 32'b0;
    operand_ra_e2_q <= 32'b0;
    operand_rb_e2_q <= 32'b0;
    result_e2_q     <= 32'b0;
    exception_e2_q  <= `EXCEPTION_W'b0;
    operand_va_e2_q <= `len'b0; // new
    operand_vb_e2_q <= `len'b0; // new
    mask_vm_e2_q    <= `len'b0; // new
    v_alu_result_e2_q <= `len'b0; // new    
end
// Normal pipeline advance
else
begin
    valid_e2_q      <= valid_e1_q;
    ctrl_e2_q       <= ctrl_e1_q;
    csr_wr_e2_q     <= csr_result_write_e1_i;
    csr_wdata_e2_q  <= csr_result_wdata_e1_i;
    pc_e2_q         <= pc_e1_q;
    npc_e2_q        <= npc_e1_q;
    opcode_e2_q     <= opcode_e1_q;
    operand_ra_e2_q <= operand_ra_e1_q;
    operand_rb_e2_q <= operand_rb_e1_q;
    operand_va_e2_q <= operand_va_e1_q; // new
    operand_vb_e2_q <= operand_vb_e1_q; // new
    mask_vm_e2_q    <= mask_vm_e1_q; // new

    // Launch interrupt
    if (ctrl_e1_q[`PCINFO_INTR])
        exception_e2_q  <= `EXCEPTION_INTERRUPT;
    // If frontend reports bad instruction, ignore later CSR errors...
    else if (|exception_e1_q)
    begin
        valid_e2_q      <= 1'b0;
        exception_e2_q  <= exception_e1_q;
    end
    else
        exception_e2_q  <= csr_result_exception_e1_i;

    if (ctrl_e1_q[`PCINFO_DIV])
        result_e2_q <= div_result_i; 
    else if (ctrl_e1_q[`PCINFO_CSR])
        result_e2_q <= csr_result_value_e1_i;
    else if (ctrl_e1_q[`PCINFO_V_ALU])
        v_alu_result_e2_q <= v_alu_result_i; // new, adding v_alu //EMO - CHECK!
    else
        result_e2_q <= alu_result_e1_i;
end

reg [31:0] result_e2_r;
reg [VLEN-1:0] v_alu_result_e2_r; // new

wire valid_e2_w      = valid_e2_q & ~issue_stall_i;

always @ *
begin
    // Default: ALU result
    result_e2_r = result_e2_q;
    v_alu_result_e2_r = v_alu_result_e2_q; // new
    if (SUPPORT_LOAD_BYPASS && valid_e2_w && (ctrl_e2_q[`PCINFO_LOAD] || ctrl_e2_q[`PCINFO_STORE]))
        result_e2_r = mem_result_e2_i;
    else if (SUPPORT_MUL_BYPASS && valid_e2_w && ctrl_e2_q[`PCINFO_MUL])
        result_e2_r = mul_result_e2_i;
end

wire   load_store_e2_w = ctrl_e2_q[`PCINFO_LOAD] | ctrl_e2_q[`PCINFO_STORE];
assign load_e2_o       = ctrl_e2_q[`PCINFO_LOAD];
assign mul_e2_o        = ctrl_e2_q[`PCINFO_MUL];
assign rd_e2_o         = {5{(valid_e2_w && ctrl_e2_q[`PCINFO_RD_VALID] && ~stall_o)}} & opcode_e2_q[`RD_IDX_R];
assign result_e2_o     = result_e2_r;
assign v_alu_e2_o      = ctrl_e2_q[`PCINFO_ALU]; // new //EMO - Where to add v_alu_e2_o
assign v_alu_result_e2_o = v_alu_result_e2_r; // new 
assign vd_e2_o         = {5{(valid_e2_w && ctrl_e2_q[`PCINFO_VD_VALID] && ~stall_o)}} & opcode_e2_q[`VD_IDX_R]; // new

// Load store result not ready when reaching E2
assign stall_o         = (ctrl_e1_q[`PCINFO_DIV] && ~div_complete_i) || ((ctrl_e2_q[`PCINFO_LOAD] | ctrl_e2_q[`PCINFO_STORE]) & ~mem_complete_i)
                         || (ctrl_e1_q[`PCINFO_V_ALU] && ~v_alu_complete_i)
                         || (ctrl_e1_q[`PCINFO_V_LSU] && ~v_lsu_complete_i); // stall while VLSU owns mem interface

reg [`EXCEPTION_W-1:0] exception_e2_r;
always @ *
begin
    if (valid_e2_q && (ctrl_e2_q[`PCINFO_LOAD] || ctrl_e2_q[`PCINFO_STORE]) && mem_complete_i)
        exception_e2_r = mem_exception_e2_i;
    else
        exception_e2_r = exception_e2_q;
end

assign squash_e1_e2_w = |exception_e2_r;

reg squash_e1_e2_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    squash_e1_e2_q <= 1'b0;
else if (~issue_stall_i)
    squash_e1_e2_q <= squash_e1_e2_w;

assign squash_e1_e2_o = squash_e1_e2_w | squash_e1_e2_q;

//-------------------------------------------------------------
// Writeback / Commit
//------------------------------------------------------------- 
reg                     valid_wb_q;
reg [`PCINFO_W-1:0]     ctrl_wb_q;
reg                     csr_wr_wb_q;
reg [31:0]              csr_wdata_wb_q;
reg [31:0]              result_wb_q;
reg [31:0]              pc_wb_q;
reg [31:0]              npc_wb_q;
reg [31:0]              opcode_wb_q;
reg [31:0]              operand_ra_wb_q;
reg [31:0]              operand_rb_wb_q;
reg [`EXCEPTION_W-1:0]  exception_wb_q;
reg [VLEN-1:0]          v_alu_result_wb_q; // new
reg [VLEN-1:0]          operand_va_wb_q; // new
reg [VLEN-1:0]          operand_vb_wb_q; // new
reg [VLEN-1:0]          mask_vm_wb_q; // new

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    valid_wb_q      <= 1'b0;
    ctrl_wb_q       <= `PCINFO_W'b0;
    csr_wr_wb_q     <= 1'b0;
    csr_wdata_wb_q  <= 32'b0;
    pc_wb_q         <= 32'b0;
    npc_wb_q        <= 32'b0;
    opcode_wb_q     <= 32'b0;
    operand_ra_wb_q <= 32'b0;
    operand_rb_wb_q <= 32'b0;
    result_wb_q     <= 32'b0;
    exception_wb_q  <= `EXCEPTION_W'b0;
    v_alu_result_wb_q <= `len'b0; // new
    operand_va_wb_q <= `len'b0; // new
    operand_vb_wb_q <= `len'b0; // new
    mask_vm_wb_q    <= `len'b0; // new
end
// Stall - no change in WB state
else if (issue_stall_i)
    ;
else if (squash_wb_i)
begin
    valid_wb_q      <= 1'b0;
    ctrl_wb_q       <= `PCINFO_W'b0;
    csr_wr_wb_q     <= 1'b0;
    csr_wdata_wb_q  <= 32'b0;
    pc_wb_q         <= 32'b0;
    npc_wb_q        <= 32'b0;
    opcode_wb_q     <= 32'b0;
    operand_ra_wb_q <= 32'b0;
    operand_rb_wb_q <= 32'b0;
    result_wb_q     <= 32'b0;
    exception_wb_q  <= `EXCEPTION_W'b0;
    v_alu_result_wb_q <= `len'b0; // new
    operand_va_wb_q <= `len'b0; // new
    operand_vb_wb_q <= `len'b0; // new
    mask_vm_wb_q    <= `len'b0; // new
end
else
begin
    // Squash instruction valid on memory faults
    case (exception_e2_r)
    `EXCEPTION_MISALIGNED_LOAD,
    `EXCEPTION_FAULT_LOAD,
    `EXCEPTION_MISALIGNED_STORE,
    `EXCEPTION_FAULT_STORE,
    `EXCEPTION_PAGE_FAULT_LOAD,
    `EXCEPTION_PAGE_FAULT_STORE:
        valid_wb_q      <= 1'b0;
    default:
        valid_wb_q      <= valid_e2_q;
    endcase

    csr_wr_wb_q     <= csr_wr_e2_q;  // TODO: Fault disable???
    csr_wdata_wb_q  <= csr_wdata_e2_q;

    // Exception - squash writeback
    if (|exception_e2_r)
        ctrl_wb_q       <= ctrl_e2_q & ~(1 << `PCINFO_RD_VALID);
    else
        ctrl_wb_q       <= ctrl_e2_q;

    pc_wb_q         <= pc_e2_q;
    npc_wb_q        <= npc_e2_q;
    opcode_wb_q     <= opcode_e2_q;
    operand_ra_wb_q <= operand_ra_e2_q;
    operand_rb_wb_q <= operand_rb_e2_q;
    exception_wb_q  <= exception_e2_r;
    operand_va_wb_q <= operand_va_e2_q; // new
    operand_vb_wb_q <= operand_vb_e2_q; // new
    mask_vm_wb_q    <= mask_vm_e2_q; // new

    if (valid_e2_w && (ctrl_e2_q[`PCINFO_LOAD] || ctrl_e2_q[`PCINFO_STORE]))
        result_wb_q <= mem_result_e2_i;
    else if (valid_e2_w && ctrl_e2_q[`PCINFO_MUL])
        result_wb_q <= mul_result_e2_i;
    else if (valid_e2_w && ctrl_e2_q[`PCINFO_V_ALU])
        v_alu_result_wb_q <= v_alu_result_i; // new //EMO - CHECK HERE
    else
        result_wb_q <= result_e2_q;
end

// Instruction completion (for debug)
wire complete_wb_w     = ctrl_wb_q[`PCINFO_COMPLETE] & ~issue_stall_i;

assign valid_wb_o      = valid_wb_q & ~issue_stall_i;
assign csr_wb_o        = ctrl_wb_q[`PCINFO_CSR] & ~issue_stall_i; // TODO: Fault disable???
assign rd_wb_o         = {5{(valid_wb_o && ctrl_wb_q[`PCINFO_RD_VALID] && ~stall_o)}} & opcode_wb_q[`RD_IDX_R];
assign vd_wb_o         = opcode_e2_q[`VD_IDX_R]; // new // EMO - Check here for validation, for testing it is forced now.
assign v_alu_result_wb_o = v_alu_result_wb_q; // new
assign result_wb_o     = result_wb_q;
assign pc_wb_o         = pc_wb_q;
assign opcode_wb_o     = opcode_wb_q;
assign operand_ra_wb_o = operand_ra_wb_q;
assign operand_rb_wb_o = operand_rb_wb_q;
assign operand_va_wb_o = operand_va_wb_q; // new, for debug
assign operand_vb_wb_o = operand_vb_wb_q; // new, for debug
assign mask_vm_wb_o    = mask_vm_wb_q; // new, for debug

assign exception_wb_o  = exception_wb_q;

assign csr_write_wb_o  = csr_wr_wb_q;
assign csr_waddr_wb_o  = opcode_wb_q[31:20];
assign csr_wdata_wb_o  = csr_wdata_wb_q;

`ifdef verilator
biriscv_trace_sim
u_trace_d
(
     .valid_i(issue_valid_i)
    ,.pc_i(issue_pc_i)
    ,.opcode_i(issue_opcode_i)
);

biriscv_trace_sim
u_trace_wb
(
     .valid_i(valid_wb_o)
    ,.pc_i(pc_wb_o)
    ,.opcode_i(opcode_wb_o)
);
`endif

endmodule