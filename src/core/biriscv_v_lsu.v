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
localparam STATE_IDLE     = 3'd0;
localparam STATE_REQ      = 3'd1;
localparam STATE_WAIT     = 3'd2;
localparam STATE_COMPLETE = 3'd3;
localparam STATE_ERROR    = 3'd4;

localparam WIDTH_8B  = 2'd0;
localparam WIDTH_16B = 2'd1;
localparam WIDTH_32B = 2'd2;
localparam WIDTH_64B = 2'd3;

localparam BEAT_COUNT = (VLEN_BYTES / 4); // 128-bit vector over 32-bit bus = 4 beats

//-----------------------------------------------------------------
// Vector Operation Decode
//-----------------------------------------------------------------
// Loads
wire is_vle8_v  = vector_op_i && ((opcode_opcode_i & `INST_VLE8_V_MASK)  == `INST_VLE8_V);
wire is_vle16_v = vector_op_i && ((opcode_opcode_i & `INST_VLE16_V_MASK) == `INST_VLE16_V);
wire is_vle32_v = vector_op_i && ((opcode_opcode_i & `INST_VLE32_V_MASK) == `INST_VLE32_V);
wire is_vle64_v = vector_op_i && ((opcode_opcode_i & `INST_VLE64_V_MASK) == `INST_VLE64_V);

wire is_vector_load_w = is_vle8_v | is_vle16_v | is_vle32_v | is_vle64_v;

// Stores
wire is_vse8_v  = vector_op_i && ((opcode_opcode_i & `INST_VSE8_V_MASK)  == `INST_VSE8_V);
wire is_vse16_v = vector_op_i && ((opcode_opcode_i & `INST_VSE16_V_MASK) == `INST_VSE16_V);
wire is_vse32_v = vector_op_i && ((opcode_opcode_i & `INST_VSE32_V_MASK) == `INST_VSE32_V);
wire is_vse64_v = vector_op_i && ((opcode_opcode_i & `INST_VSE64_V_MASK) == `INST_VSE64_V);

wire is_vector_store_w = is_vse8_v | is_vse16_v | is_vse32_v | is_vse64_v;

wire [1:0] element_width_w = is_vle8_v  | is_vse8_v  ? WIDTH_8B  :
                             is_vle16_v | is_vse16_v ? WIDTH_16B :
                             is_vle32_v | is_vse32_v ? WIDTH_32B :
                             is_vle64_v | is_vse64_v ? WIDTH_64B : WIDTH_8B;

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg [2:0] state_q;
reg [31:0] addr_q;
reg [VLEN-1:0] vector_buffer_q;
reg [1:0] element_width_q;
reg is_load_q;
reg [$clog2(BEAT_COUNT):0] beat_q;

//-----------------------------------------------------------------
// Internal Wires
//-----------------------------------------------------------------
wire unaligned_access_w;
wire last_beat_w;

assign unaligned_access_w = (element_width_w == WIDTH_64B && opcode_ra_operand_i[2:0] != 3'b000) ||
                            (element_width_w == WIDTH_32B && opcode_ra_operand_i[1:0] != 2'b00) ||
                            (element_width_w == WIDTH_16B && opcode_ra_operand_i[0]    != 1'b0);

assign last_beat_w = (beat_q == (BEAT_COUNT-1));

//-----------------------------------------------------------------
// Next State Logic
//-----------------------------------------------------------------
reg [2:0] next_state_r;

always @* begin
    next_state_r = state_q;

    case(state_q)
        STATE_IDLE: begin
            if (opcode_valid_i && (is_vector_load_w || is_vector_store_w)) begin
                if (unaligned_access_w)
                    next_state_r = STATE_ERROR;
                else
                    next_state_r = STATE_REQ;
            end
        end

        STATE_REQ: begin
            if (mem_accept_i)
                next_state_r = STATE_WAIT;
        end

        STATE_WAIT: begin
            if (mem_ack_i) begin
                if (mem_error_i)
                    next_state_r = STATE_ERROR;
                else if (last_beat_w)
                    next_state_r = STATE_COMPLETE;
                else
                    next_state_r = STATE_REQ;
            end
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
        vector_buffer_q <= {VLEN{1'b0}};
        element_width_q <= WIDTH_8B;
        is_load_q <= 1'b0;
        beat_q <= {$clog2(BEAT_COUNT)+1{1'b0}};
    end
    else begin
        state_q <= next_state_r;

        case (state_q)
            STATE_IDLE: begin
                if (opcode_valid_i && (is_vector_load_w || is_vector_store_w)) begin
                    addr_q <= opcode_ra_operand_i;
                    element_width_q <= element_width_w;
                    is_load_q <= is_vector_load_w;
                    beat_q <= {$clog2(BEAT_COUNT)+1{1'b0}};
                    vector_buffer_q <= is_vector_store_w ? vector_data_i : {VLEN{1'b0}};
                end
            end 

            STATE_WAIT: begin
                if (mem_ack_i && !mem_error_i) begin
                    if (is_load_q) begin
                        case(beat_q[$clog2(BEAT_COUNT):0])
                            0: vector_buffer_q[31:0]    <= mem_data_rd_i;
                            1: vector_buffer_q[63:32]   <= mem_data_rd_i;
                            2: vector_buffer_q[95:64]   <= mem_data_rd_i;
                            3: vector_buffer_q[127:96]  <= mem_data_rd_i;
                            default: ;
                        endcase
                    end
                    beat_q <= beat_q + 1'b1;
                    addr_q <= addr_q + 32'd4;
                end
            end

            STATE_COMPLETE: begin
                beat_q <= {$clog2(BEAT_COUNT)+1{1'b0}};
            end

            STATE_ERROR: begin
                beat_q <= {$clog2(BEAT_COUNT)+1{1'b0}};
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

    if (state_q == STATE_REQ) begin
        mem_rd_r = is_load_q;
        mem_wr_r = is_load_q ? 4'b0000 : 4'b1111;

        case(beat_q[$clog2(BEAT_COUNT):0])
            0: mem_data_wr_r = vector_buffer_q[31:0];
            1: mem_data_wr_r = vector_buffer_q[63:32];
            2: mem_data_wr_r = vector_buffer_q[95:64];
            3: mem_data_wr_r = vector_buffer_q[127:96];
            default: mem_data_wr_r = 32'b0;
        endcase
    end
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

assign vector_data_o  = vector_buffer_q;
// Assert on completion so the core can release VLSU for stores too.
assign vector_valid_o = (state_q == STATE_COMPLETE);
assign vector_error_o = (state_q == STATE_ERROR);

assign stall_o = (state_q == STATE_REQ) || (state_q == STATE_WAIT);

endmodule
