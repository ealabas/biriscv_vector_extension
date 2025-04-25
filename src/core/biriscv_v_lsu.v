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

module biriscv_v_lsu
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter MEM_CACHE_ADDR_MIN = 0
    ,parameter MEM_CACHE_ADDR_MAX = 32'hffffffff
    ,parameter VLEN              = 128
    ,parameter VLEN_BYTES        = VLEN / 8
    ,parameter MAX_BURST_LEN     = 8 
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           opcode_valid_i
    ,input  [ 31:0]  opcode_opcode_i
    ,input  [ 31:0]  opcode_pc_i
    ,input           opcode_invalid_i
    ,input  [  4:0]  opcode_rd_idx_i
    ,input  [  4:0]  opcode_ra_idx_i
    ,input  [  4:0]  opcode_rb_idx_i
    ,input  [ 31:0]  opcode_ra_operand_i
    ,input  [ 31:0]  opcode_rb_operand_i
   
    // Vector Inputs
    ,input [VLEN-1:0] vector_data_i
    ,input            vector_op_i
    //,input            vector_mode_i // EMO - find a way that assign this from instruction
    //,input  [  2:0]   vector_width_i // EMO - it should not be input like mode, should be defined from opcode

    // Memory Interface
    ,input  [ 31:0]  mem_data_rd_i
    ,input           mem_accept_i
    ,input           mem_ack_i
    ,input           mem_error_i
    ,input  [ 10:0]  mem_resp_tag_i 

    // Outputs
    // Memory Interface
    ,output [ 31:0]  mem_addr_o
    ,output [ 31:0]  mem_data_wr_o
    ,output          mem_rd_o
    ,output [  3:0]  mem_wr_o
    ,output          mem_cacheable_o
    ,output [ 10:0]  mem_req_tag_o
    ,output          mem_invalidate_o
    ,output          mem_writeback_o
    ,output          mem_flush_o

    ,output          stall_o

    // Vector Outputs
    ,output [VLEN-1:0] vector_data_o
    ,output            vector_valid_o
    ,output            vector_error_o
);


//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "biriscv_defs.v"

//-----------------------------------------------------------------
// Local Parameters
//-----------------------------------------------------------------
// LSU States
localparam STATE_IDLE = 3'b000;
localparam STATE_LOAD_REQ = 3'b001;
localparam STATE_LOAD_RESP = 3'b010;
localparam STATE_STORE_REQ = 3'b001;
localparam STATE_COMPLETE = 3'b100;
localparam STATE_ERROR = 3'b101;

// Element Width
localparam WIDTH_8B = 2'b00;
localparam WIDTH_16B = 2'b01;
localparam WIDTH_32B = 2'b10;
localparam WIDTH_64B = 2'b11; 

//-----------------------------------------------------------------
// Vector Operation Decode
//-----------------------------------------------------------------
// Loads
wire is_vl1re8_v = vector_op_i && ((opcode0_opcode_i & `INST_VL1RE8_V_MASK) == `INST_VL1RE8_V);
wire is_vl1re16_v = vector_op_i && ((opcode0_opcode_i & `INST_VL1RE16_V_MASK) == `INST_VL1RE16_V);
wire is_vl1re32_v = vector_op_i && ((opcode0_opcode_i & `INST_VL1RE32_V_MASK) == `INST_VL1RE32_V);
wire is_vl1re64_v = vector_op_i && ((opcode0_opcode_i & `INST_VL1RE64_V_MASK) == `INST_VL1RE64_V);

wire is_vector_load_w = is_vl1re8_v || is_vl1re16_v || is_vl1re32_v || is_vl1re64_v;

// Stores
wire is_vs1r_v = vector_op_i && ((opcode0_opcode_i & `INST_VS1R_V_MASK) == `INST_VS1R_V);
wire is_vs2r_v = vector_op_i && ((opcode0_opcode_i & `INST_VS2R_V_MASK) == `INST_VS2R_V);

wire is_vector_store_w = is_vs1r_v || is_vs2r_v;

wire [1:0] element_width_w = is_vl1re8_v ? WIDTH_8B :
                            is_vl1re16_v ? WIDTH_16B : 
                            is_vl1re32_v ? WIDTH_32B : 
                            is_vl1re64_v ? WIDTH_64B : WIDTH_8B;

wire [1:0] n_reg_w = is_vs1r_v ? 2'd1 :
                    is_vs2r_v ? 2'd2 : 2'd1;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg [2:0] state_q;
reg [31:0] addr_q;
reg [31:0] next_addr_q;
reg [VLEN-1:0] vector_buffer_q;
reg [VLEN_BYTES-1:0] vector_mask_q;
reg [$clog2(VLEN_BYTES)-1:0] transfer_count_q;
reg [$clog2(VLEN_BYTES)-1:0] bytes_transferred_q;
reg [1:0] element_width_q;
reg [1:0] n_reg_q;
reg is_load_q;

//-----------------------------------------------------------------
// Internal Wires
//-----------------------------------------------------------------
wire [31:0] element_size_bytes_w;
wire [$clog2(VLEN_BYTES)-1:0] current_offset_w;
wire unaligned_access_w;
wire transfer_complete_w;
wire operation_complete_w;

assign element_size_bytes_w = (element_width_q == WIDTH_8B) ? 1 :
                                (element_width_q == WIDTH_16B) ? 2 :
                                (element_width_q == WIDTH_32B) ? 4 :
                                (element_width_q == WIDTH_64B) ? 8 : 1;

assign current_offset_w = bytes_transferred_q;

assign unaligned_access_w = (element_width_q == WIDTH_16B && addr_q[0] != 1'b0) ||
                                (element_width_q == WIDTH_32B && addr_q[1:0] != 2'b00) ||
                                (element_width_q == WIDTH_64B && addr_q[2:0] != 3'b000);

wire [$clog2(VLEN_BYTES*4)-1:0] total_bytes_to_transfer_w = is_load_q ? VLEN_BYTES : (VLEN_BYTES * n_reg_q);

assign transfer_complete_w = (bytes_transferred_q >= total_bytes_to_transfer_w) || (transfer_count_q == 0);
assign operation_complete_w = (state_q == STATE_COMPLETE);

//-----------------------------------------------------------------
// Next State Logic
//-----------------------------------------------------------------
reg [2:0] next_state_r;

always @* begin
    next_state_r = state_q;

    case(state_q)
        STATE_IDLE: begin
            if (opcode_valid_i && is_vector_load_w && !unaligned_access_w)
                next_state_r = STATE_LOAD_REQ;
            else if (opcode_valid_i && is_vector_store_w && !unaligned_access_w)
                next_state_r = STATE_STORE_REQ;
        end

        STATE_LOAD_REQ: begin
            if (mem_accept_i)
                next_state_r = STATE_LOAD_RESP;
            else if (unaligned_access_w)
                next_state_r = STATE_ERROR;
        end

        STATE_LOAD_RESP: begin
            if (mem_ack_i) begin
                if (mem_error_i)
                    next_state_r = STATE_ERROR;
                else if (transfer_complete_w)
                    next_state_r = STATE_COMPLETE;
                else
                    next_state_r = STATE_LOAD_REQ; 
            end
        end

        STATE_STORE_REQ: begin
            if (mem_accept_i) begin
                if (transfer_complete_w)
                    next_state_r = STATE_COMPLETE;
                else
                    next_state_r = STATE_STORE_REQ;
            end
            else if (unaligned_access_w)
                next_state = STATE_ERROR;
        end

        STATE_COMPLETE: begin
            next_state_r = STATE_IDLE;
        end
        
        STATE_ERROR: begin
            next_state_r = STATE_IDLE;
        end

        default:
            next_state_r = STATE_IDLE;
    endcase
end

//-----------------------------------------------------------------
// Sequential Logic
//-----------------------------------------------------------------
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        state_q <= STATE_IDLE;
        addr_q <= 32'b0;
        next_addr_q <= 32'b0;
        vector_buffer_q <= {VLEN{1'b0}};
        vector_mask_q <= {VLEN{1'b0}};
        transfer_count_q <= {$clog2(VLEN_BYTES){1'b0}};
        bytes_transferred_q <= {$clog2(VLEN_BYTES){1'b0}};
        element_width_q <= WIDTH_8B;
        n_reg_q <= 2'd1;
        is_load_q <= 1'b0;
    end
    else begin
        state_q <= next_state_r;

        case (state_q)
            STATE_IDLE: begin
                if (opcode_valid_i && (is_vector_load_w || is_vector_store_w)) begin
                    addr_q <= opcode_ra_operand_i;
                    element_width_q <= element_width_w;
                    n_reg_q <= n_reg_w;
                    is_load_q <= is_vector_load_w;
                    
                    if (is_vector_store_w)
                        transfer_count_q <= ((VLEN_BYTES*n_reg_w) + 3) / 4;
                    else
                        transfer_count_q <= (VLEN_BYTES + 3) / 4;
                    
                    bytes_transferred_q <= 0;
                    
                    if (is_vector_store_w)
                        vector_buffer_q <= vector_data_i;
                    else
                        vector_buffer_q <= {VLEN{1'b0}};

                end
            end 

            STATE_LOAD_REQ: begin
                if(mem_accept_i) begin
                    addr_q <= addr_q + 4;
                end
            end

            STATE_LOAD_RESP: begin
                if (mem_ack_i && !mem_error_i) begin
                    case(bytes_transferred_q[$clog2(VLEN_BYTES)-1:2])
                        0: vector_buffer_q[31:0] <= mem_data_rd_i;
                        1: vector_buffer_q[63:32] <= mem_data_rd_i;
                        2: vector_buffer_q[95:64] <= mem_data_rd_i;
                        3: vector_buffer_q[127:96] <= mem_data_rd_i;
                    endcase

                    bytes_transferred_q <= bytes_transferred_q + 4;
                    transfer_count_q <= transfer_count_q - 1;
                end
            end

            STATE_STORE_REQ: begin
                if(mem_accept_i) begin
                    addr_q <= addr_q + 4;
                    bytes_transferred_q <= bytes_transferred_q + 4;
                    transfer_count_q <= transfer_count_q - 1;
                end
            end

            STATE_COMPLETE: begin
                bytes_transferred_q <= 0;
                transfer_count_q <= 0;
            end

            STATE_ERROR: begin
                bytes_transferred_q <= 0;
                transfer_count_q <= 0;
            end
        endcase
    end
end
//-----------------------------------------------------------------
// Memory Interface
//-----------------------------------------------------------------
reg [31:0] mem_addr_r;
reg [31:0] mem_data_wr_r;
reg mem_rd_r;
reg [ 3:0] mem_wr_r;

always @* begin
    mem_addr_r = addr_q;
    mem_data_wr_r = 32'b0;
    mem_rd_r = 1'b0;
    mem_wr_r = 4'b0;

    case(state_q)
        STATE_LOAD_REQ: begin
            mem_rd_r = 1'b1;
            mem_wr_r = 4'b0;
        end
        
        STATE_STORE_REQ: begin
            mem_rd_r = 1'b0;
            mem_wr_r = 4'b1111;

            case(bytes_transferred_q[$clog2(VLEN_BYTES*4)-1:2])
                0: mem_data_wr_r = vector_buffer_q[31:0];
                1: mem_data_wr_r = vector_buffer_q[63:32];
                2: mem_data_wr_r = vector_buffer_q[95:64];
                3: mem_data_wr_r = vector_buffer_q[127:96];
            endcase
            // EMO - need for a logic to handle storing multiple registers
        end
    endcase
end

//-----------------------------------------------------------------
// Outputs
//-----------------------------------------------------------------
assign mem_addr_o = {mem_addr_r[31:2], 2'b00};
assign mem_data_wr_o = mem_data_wr_r;
assign mem_rd_o = mem_rd_r;
assign mem_wr_o = mem_wr_r;

// EMO - check these signals
assign mem_cacheable_o = (mem_addr_r >= MEM_CACHE_ADDR_MIN && mem_addr_r <= MEM_CACHE_ADDR_MAX);
assign mem_req_tag_o = 11'b0;
assign mem_invalidate_o = 1'b0;
assign mem_writeback_o = 1'b0;
assign mem_flush_o = 1'b0;

assign vector_data_o = vector_buffer_q;
assign vector_valid_o = (state_q == STATE_COMPLETE);
assign vector_error_o = (state_q == STATE_ERROR);

assign stall_o = (state_q != STATE_IDLE && state_q != STATE_COMPLETE && state_q != STATE_ERROR);

endmodule