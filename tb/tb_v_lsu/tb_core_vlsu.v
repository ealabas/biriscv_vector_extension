`timescale 1ns/1ps

module tb_core_vlsu;
    localparam VLEN = 128;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    // Core <-> instruction memory
    wire [31:0] mem_d_addr;
    wire [31:0] mem_d_data_wr;
    wire        mem_d_rd;
    wire [3:0]  mem_d_wr;
    wire        mem_d_cacheable;
    wire [10:0] mem_d_req_tag;
    wire        mem_d_invalidate;
    wire        mem_d_writeback;
    wire        mem_d_flush;
    wire        mem_i_rd;
    wire        mem_i_flush;
    wire        mem_i_invalidate;
    wire [31:0] mem_i_pc;

    // Simple instruction stream: only one 32-bit VLE64.V with base x0 -> addr 0
    // Encoded as: [31:26]=0, vm=1, lumop=0, rs1=x0, width=111 (64b), vd=x4, opcode=0000111
    localparam [31:0] VLE64_V_X4_X0 = 32'h0200F207;
    localparam [31:0] NOP           = 32'h00000013;

    reg         mem_i_accept;
    reg         mem_i_valid;
    reg         mem_i_error;
    reg [63:0]  mem_i_inst;

    // Data memory stub
    reg         mem_d_accept;
    reg         mem_d_ack;
    reg         mem_d_error;
    reg [10:0]  mem_d_resp_tag;
    reg [31:0]  mem_d_data_rd;

    // Pattern to return on vector load beats
    reg [31:0] beat_mem [0:3];
    initial begin
        beat_mem[0] = 32'h41414141; // "AAAA"
        beat_mem[1] = 32'h42424242; // "BBBB"
        beat_mem[2] = 32'h43434343; // "CCCC"
        beat_mem[3] = 32'h44444444; // "DDDD"
    end

    riscv_core #(
        .SUPPORT_MMU(0),
        .SUPPORT_SUPER(0),
        .SUPPORT_VECTOR_EXT(1),
        .VLEN(VLEN)
    ) dut (
        .clk_i(clk),
        .rst_i(rst),
        .mem_d_data_rd_i(mem_d_data_rd),
        .mem_d_accept_i(mem_d_accept),
        .mem_d_ack_i(mem_d_ack),
        .mem_d_error_i(mem_d_error),
        .mem_d_resp_tag_i(mem_d_resp_tag),
        .mem_i_accept_i(mem_i_accept),
        .mem_i_valid_i(mem_i_valid),
        .mem_i_error_i(mem_i_error),
        .mem_i_inst_i(mem_i_inst),
        .intr_i(1'b0),
        .reset_vector_i(32'b0),
        .cpu_id_i(32'b0),
        .mem_d_addr_o(mem_d_addr),
        .mem_d_data_wr_o(mem_d_data_wr),
        .mem_d_rd_o(mem_d_rd),
        .mem_d_wr_o(mem_d_wr),
        .mem_d_cacheable_o(mem_d_cacheable),
        .mem_d_req_tag_o(mem_d_req_tag),
        .mem_d_invalidate_o(mem_d_invalidate),
        .mem_d_writeback_o(mem_d_writeback),
        .mem_d_flush_o(mem_d_flush),
        .mem_i_rd_o(mem_i_rd),
        .mem_i_flush_o(mem_i_flush),
        .mem_i_invalidate_o(mem_i_invalidate),
        .mem_i_pc_o(mem_i_pc)
    );

    // Instr mem: always valid, present VLE64 in slot0 and NOP in slot1
    always @(*) begin
        mem_i_accept = 1'b1;
        mem_i_valid  = mem_i_rd;
        mem_i_error  = 1'b0;
        mem_i_inst   = {NOP, VLE64_V_X4_X0}; // upper word unused for this test
    end

    // Data mem model: accept always; ack one cycle after rd with programmed beats
    reg [1:0] beat_idx;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_d_accept   <= 1'b1;
            mem_d_ack      <= 1'b0;
            mem_d_error    <= 1'b0;
            mem_d_resp_tag <= 11'b0;
            mem_d_data_rd  <= 32'b0;
            beat_idx       <= 2'b0;
        end else begin
            mem_d_ack <= 1'b0;
            if (mem_d_rd) begin
                // check address sequencing
                if (mem_d_addr !== {28'h0, beat_idx, 2'b00}) begin
                    $display("[%0t] ERROR: addr %h expected %h", $time, mem_d_addr, {28'h0, beat_idx, 2'b00});
                    $fatal;
                end
                mem_d_data_rd <= beat_mem[beat_idx];
                mem_d_ack <= 1'b1;
                beat_idx <= beat_idx + 1'b1;
            end
        end
    end

    // Simple checker: wait for VLSU writeback inside core
    wire vlsu_done  = dut.writeback_v_lsu_valid_w | dut.writeback_v_lsu_error_w;
    wire [VLEN-1:0] vlsu_value = dut.writeback_v_lsu_value_w;

    initial begin
        // reset pulse
        rst = 1'b1;
        #40;
        rst = 1'b0;

        // wait for VLSU completion
        wait (vlsu_done);
        #2;
        if (dut.writeback_v_lsu_error_w) begin
            $display("[%0t] ERROR: VLSU signaled error", $time);
            $fatal;
        end
        if (vlsu_value !== {beat_mem[3], beat_mem[2], beat_mem[1], beat_mem[0]}) begin
            $display("[%0t] ERROR: VLSU value mismatch got %h", $time, vlsu_value);
            $fatal;
        end

        $display("[%0t] PASS: VLSU load captured %h", $time, vlsu_value);
        #20;
        $finish;
    end

endmodule
