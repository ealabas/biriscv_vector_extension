`timescale 1ns/1ps

// Scenario: vector store VSE64.V writes 4 beats; verify data/address and that VLSU owns the bus.
module tb_core_vlsu_store;
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

    // Instruction stream: slot0 = VSE64.V v3,(x0); slot1 = NOP
    // Encoding: imm[11:5]=0 with vm=1 at bit25 => 1, rs2(vs3)=3, rs1=x0, width=111, imm[4:0]=0, opcode=0100111
    localparam [31:0] VSE64_V_V3_X0 = 32'h02307027;
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

    // Expected store beats
    reg [31:0] exp_vec [0:3];
    initial begin
        exp_vec[0] = 32'h11111111;
        exp_vec[1] = 32'h22222222;
        exp_vec[2] = 32'h33333333;
        exp_vec[3] = 32'h44444444;
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

    // Seed vector register v3 with known data after reset deasserts
    initial begin
        @(negedge rst);
        // For flop-based regfile (SUPPORT_REGFILE_XILINX=0) the reg lives under generate block REGFILE
        dut.u_issue.u_v_regfile.REGFILE.reg_v3_q = {exp_vec[3], exp_vec[2], exp_vec[1], exp_vec[0]};
    end

    // Instr mem: present the two instructions
    always @(*) begin
        mem_i_accept = 1'b1;
        mem_i_valid  = mem_i_rd;
        mem_i_error  = 1'b0;
        mem_i_inst   = {NOP, VSE64_V_V3_X0};
    end

    // Data mem model: capture four store beats, then finish
    reg [2:0] beat_idx;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_d_accept   <= 1'b1;
            mem_d_ack      <= 1'b0;
            mem_d_error    <= 1'b0;
            mem_d_resp_tag <= 11'b0;
            mem_d_data_rd  <= 32'b0;
            beat_idx       <= 3'b0;
        end else begin
            mem_d_ack <= 1'b0;
            if (mem_d_wr != 4'b0000) begin
                // Expect VLSU to own the bus during store
                if (!dut.vlsu_active_q) begin
                    $display("[%0t] ERROR: store beat while vlsu_active_q=0", $time);
                    $fatal;
                end
                // Check address increments by 4 bytes
                if (mem_d_addr !== {28'h0, beat_idx[1:0], 2'b00}) begin
                    $display("[%0t] ERROR: store addr %h expected %h", $time, mem_d_addr, {28'h0, beat_idx[1:0], 2'b00});
                    $fatal;
                end
                // Check data matches expected vector content
                if (mem_d_data_wr !== exp_vec[beat_idx[1:0]]) begin
                    $display("[%0t] ERROR: store data %h expected %h", $time, mem_d_data_wr, exp_vec[beat_idx[1:0]]);
                    $fatal;
                end
                // Byte enables should be full word
                if (mem_d_wr !== 4'hF) begin
                    $display("[%0t] ERROR: store byte enable %h expected F", $time, mem_d_wr);
                    $fatal;
                end
                beat_idx <= beat_idx + 1'b1;
                mem_d_ack <= 1'b1;
            end
        end
    end

    // Completion monitor
    wire vlsu_done = dut.writeback_v_lsu_valid_w | dut.writeback_v_lsu_error_w;
    initial begin
        rst = 1'b1;
        #40;
        rst = 1'b0;

        // Wait for all 4 beats to be seen
        wait (beat_idx == 3'd4);
        // Now wait for VLSU completion pulse
        wait (vlsu_done);

        $display("[%0t] PASS: VLSU store produced 4 correct beats", $time);
        #20;
        $finish;
    end

endmodule
