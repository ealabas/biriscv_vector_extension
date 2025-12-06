`timescale 1ns/1ps

module tb_biriscv_v_lsu;
    localparam VLEN = 128;

    // Clock & reset
    reg clk;
    reg rst;
    always #5 clk = ~clk;

    // Opcode / vector inputs
    reg           opcode_valid;
    reg  [31:0]   opcode_opcode;
    reg  [31:0]   opcode_pc;
    reg           opcode_invalid;
    reg  [4:0]    opcode_rd_idx;
    reg  [4:0]    opcode_ra_idx;
    reg  [4:0]    opcode_rb_idx;
    reg  [31:0]   opcode_ra_operand;
    reg  [31:0]   opcode_rb_operand;

    reg  [VLEN-1:0] vector_data_i;
    reg             vector_op_i;

    // Memory response side
    reg  [31:0] mem_data_rd_i;
    reg         mem_accept_i;
    reg         mem_ack_i;
    reg         mem_error_i;
    reg  [10:0] mem_resp_tag_i;

    // DUT outputs
    wire [31:0]  mem_addr_o;
    wire [31:0]  mem_data_wr_o;
    wire         mem_rd_o;
    wire [3:0]   mem_wr_o;
    wire         mem_cacheable_o;
    wire [10:0]  mem_req_tag_o;
    wire         mem_invalidate_o;
    wire         mem_writeback_o;
    wire         mem_flush_o;
    wire         stall_o;
    wire [VLEN-1:0] vector_data_o;
    wire         vector_valid_o;
    wire         vector_error_o;

    biriscv_v_lsu #(
        .VLEN(VLEN)
    ) dut (
        .clk_i(clk),
        .rst_i(rst),
        .opcode_valid_i(opcode_valid),
        .opcode_opcode_i(opcode_opcode),
        .opcode_pc_i(opcode_pc),
        .opcode_invalid_i(opcode_invalid),
        .opcode_rd_idx_i(opcode_rd_idx),
        .opcode_ra_idx_i(opcode_ra_idx),
        .opcode_rb_idx_i(opcode_rb_idx),
        .opcode_ra_operand_i(opcode_ra_operand),
        .opcode_rb_operand_i(opcode_rb_operand),
        .vector_data_i(vector_data_i),
        .vector_op_i(vector_op_i),
        .mem_data_rd_i(mem_data_rd_i),
        .mem_accept_i(mem_accept_i),
        .mem_ack_i(mem_ack_i),
        .mem_error_i(mem_error_i),
        .mem_resp_tag_i(mem_resp_tag_i),
        .mem_addr_o(mem_addr_o),
        .mem_data_wr_o(mem_data_wr_o),
        .mem_rd_o(mem_rd_o),
        .mem_wr_o(mem_wr_o),
        .mem_cacheable_o(mem_cacheable_o),
        .mem_req_tag_o(mem_req_tag_o),
        .mem_invalidate_o(mem_invalidate_o),
        .mem_writeback_o(mem_writeback_o),
        .mem_flush_o(mem_flush_o),
        .stall_o(stall_o),
        .vector_data_o(vector_data_o),
        .vector_valid_o(vector_valid_o),
        .vector_error_o(vector_error_o)
    );

    localparam [31:0] BASE_ADDR = 32'h0000_1000;
    localparam [VLEN-1:0] EXPECT_VECTOR = {32'h44444444, 32'h43434343, 32'h42424242, 32'h41414141};

    // Simple memory model: always accept, ack one cycle after request with programmed data beats
    reg ack_pending;
    reg [31:0] ack_data_reg;
    reg [1:0]  rsp_beat;
    reg [31:0] expected_addr;

    always @(posedge clk) begin
        if (rst) begin
            mem_ack_i     <= 1'b0;
            mem_data_rd_i <= 32'b0;
            ack_pending   <= 1'b0;
            rsp_beat      <= 2'b0;
            expected_addr <= BASE_ADDR;
        end else begin
            mem_ack_i     <= 1'b0;
            if (ack_pending) begin
                mem_ack_i     <= 1'b1;
                mem_data_rd_i <= ack_data_reg;
                ack_pending   <= 1'b0;
            end

            if (mem_rd_o && mem_accept_i) begin
                // Address check on each beat
                if (mem_addr_o !== expected_addr) begin
                    $display("[TB][%0t] ERROR: addr mismatch. Saw %h expected %h", $time, mem_addr_o, expected_addr);
                    $fatal;
                end
                expected_addr <= expected_addr + 32'd4;

                ack_pending <= 1'b1;
                case (rsp_beat)
                    2'd0: ack_data_reg <= 32'h41414141; // "AAAA"
                    2'd1: ack_data_reg <= 32'h42424242; // "BBBB"
                    2'd2: ack_data_reg <= 32'h43434343; // "CCCC"
                    default: ack_data_reg <= 32'h44444444; // "DDDD"
                endcase
                rsp_beat <= rsp_beat + 1'b1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        opcode_valid = 1'b0;
        opcode_opcode = 32'b0;
        opcode_pc = 32'b0;
        opcode_invalid = 1'b0;
        opcode_rd_idx = 5'd0;
        opcode_ra_idx = 5'd0;
        opcode_rb_idx = 5'd0;
        opcode_ra_operand = 32'b0;
        opcode_rb_operand = 32'b0;
        vector_data_i = {VLEN{1'b0}};
        vector_op_i = 1'b0;
        mem_accept_i = 1'b1;
        mem_error_i = 1'b0;
        mem_resp_tag_i = 11'b0;

        #20;
        rst = 1'b0;

        // Issue vector load
        @(negedge clk);
        vector_op_i = 1'b1;
        opcode_valid = 1'b1;
        opcode_opcode = `INST_VLE64_V;
        opcode_ra_operand = BASE_ADDR;

        @(negedge clk);
        opcode_valid = 1'b0; // single issue

        wait (vector_valid_o || vector_error_o);
        #1;
        if (vector_error_o) begin
            $display("[TB][%0t] ERROR flag asserted", $time);
            $fatal;
        end
        if (vector_data_o !== EXPECT_VECTOR) begin
            $display("[TB][%0t] ERROR: vector_data_o mismatch. Got %h expected %h", $time, vector_data_o, EXPECT_VECTOR);
            $fatal;
        end else begin
            $display("[TB][%0t] PASS: vector_data_o = %h", $time, vector_data_o);
        end

        #20;
        $finish;
    end
endmodule
