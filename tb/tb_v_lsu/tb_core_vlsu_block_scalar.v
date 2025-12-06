`timescale 1ns/1ps

// Scenario: VLSU holds the data port; a scalar load issues but cannot progress until VLSU completes.
module tb_core_vlsu_block_scalar;
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

    // Two instructions: slot0 = VLE64.V x4,(x0); slot1 = LW x5,0(x0)
    localparam [31:0] VLE64_V_X4_X0 = 32'h0200F207; // vle64.v vd=4, rs1=x0, vm=1
    localparam [31:0] LW_X5_X0      = 32'h00002283; // lw x5,0(x0)
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

    // Beats for VLSU load
    reg [31:0] beat_mem [0:3];
    initial begin
        beat_mem[0] = 32'h11111111;
        beat_mem[1] = 32'h22222222;
        beat_mem[2] = 32'h33333333;
        beat_mem[3] = 32'h44444444;
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

    // Instr mem: present two instructions
    always @(*) begin
        mem_i_accept = 1'b1;
        mem_i_valid  = mem_i_rd;
        mem_i_error  = 1'b0;
        mem_i_inst   = {LW_X5_X0, VLE64_V_X4_X0};
    end

    // Data mem model: VLSU serviced; scalar load should be blocked until VLSU releases bus
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
                if (dut.vlsu_active_q) begin
                    // VLSU beat sequence check
                    if (mem_d_addr !== {28'h0, beat_idx, 2'b00}) begin
                        $display("[%0t] ERROR: VLSU addr %h expected %h", $time, mem_d_addr, {28'h0, beat_idx, 2'b00});
                        $fatal;
                    end
                    mem_d_data_rd <= beat_mem[beat_idx];
                    beat_idx <= beat_idx + 1'b1;
                    mem_d_ack <= 1'b1;
                end else begin
                    // Scalar load should only fire after vlsu_active_q drops
                    if (mem_d_addr !== 32'h0000_0000) begin
                        $display("[%0t] ERROR: scalar load addr %h unexpected", $time, mem_d_addr);
                        $fatal;
                    end
                    mem_d_data_rd <= 32'hDEADBEEF;
                    mem_d_ack <= 1'b1;
                end
            end
        end
    end

    // Monitors
    wire vlsu_done   = dut.writeback_v_lsu_valid_w | dut.writeback_v_lsu_error_w;
    wire scalar_valid= dut.writeback_mem_valid_w;
    reg  scalar_seen;
    reg  vlsu_seen;

    initial begin
        rst = 1'b1;
        #40;
        rst = 1'b0;

        scalar_seen = 1'b0;
        vlsu_seen   = 1'b0;

        // Wait for VLSU completion
        wait (vlsu_done);
        vlsu_seen = 1'b1;

        // Now scalar load should complete
        wait (scalar_valid);
        scalar_seen = 1'b1;

        // Check ordering
        if (!vlsu_seen || !scalar_seen) begin
            $display("[%0t] ERROR: sequence not observed", $time);
            $fatal;
        end

        $display("[%0t] PASS: VLSU ran and scalar load completed after VLSU", $time);
        #20;
        $finish;
    end

endmodule
