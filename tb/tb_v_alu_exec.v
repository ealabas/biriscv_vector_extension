`timescale 1ns/1ps
`include "biriscv_defs.v"

module tb_v_alu_exec;
    localparam VLEN = 128;
    localparam ELEN = 32;

    reg                 clk = 1'b0;
    reg                 rst = 1'b1;
    reg                 opcode_valid = 1'b0;
    reg  [31:0]         opcode = 32'h0;
    reg  [31:0]         pc = 32'h0;
    reg                 opcode_invalid = 1'b0;
    reg  [4:0]          vd_idx = 5'd0;
    reg  [4:0]          ra_idx = 5'd0;
    reg  [4:0]          rb_idx = 5'd0;
    reg  [4:0]          va_idx = 5'd0;
    reg  [4:0]          vb_idx = 5'd0;
    reg  [31:0]         ra_operand = 32'h0;
    reg  [31:0]         rb_operand = 32'h0;
    reg  [VLEN-1:0]     va_operand = {VLEN{1'b0}};
    reg  [VLEN-1:0]     vb_operand = {VLEN{1'b0}};
    reg  [VLEN-1:0]     vmask_operand = {VLEN{1'b1}}; // vm=1 => mask unused

    wire                writeback_valid;
    wire [VLEN-1:0]     writeback_value;

    biriscv_v_alu_exec #(
        .VLEN(VLEN),
        .ELEN(ELEN)
    ) dut (
        .clk_i(clk),
        .rst_i(rst),
        .opcode_valid_i(opcode_valid),
        .opcode_opcode_i(opcode),
        .opcode_pc_i(pc),
        .opcode_invalid_i(opcode_invalid),
        .opcode_vd_idx_i(vd_idx),
        .opcode_ra_idx_i(ra_idx),
        .opcode_rb_idx_i(rb_idx),
        .opcode_va_idx_i(va_idx),
        .opcode_vb_idx_i(vb_idx),
        .opcode_ra_operand_i(ra_operand),
        .opcode_rb_operand_i(rb_operand),
        .opcode_va_operand_i(va_operand),
        .opcode_vb_operand_i(vb_operand),
        .opcode_vmask_operand_i(vmask_operand),
        .writeback_valid_o(writeback_valid),
        .writeback_value_o(writeback_value)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // Helper: set 4-lane vector (ELEN=32)
    task set_vec(input [31:0] a0, input [31:0] a1, input [31:0] a2, input [31:0] a3, output [VLEN-1:0] vec);
    begin
        vec = {a3, a2, a1, a0};
    end
    endtask

    initial begin
        // Reset
        #1  rst = 1'b1;
        #20 rst = 1'b0;

        //------------------------------------------------------------------
        // Test 1: vadd.vv (vm=1)
        //------------------------------------------------------------------
        set_vec(32'h0000_0001, 32'h0000_0002, 32'h0000_0003, 32'h0000_0004, va_operand);
        set_vec(32'h0000_0010, 32'h0000_0020, 32'h0000_0030, 32'h0000_0040, vb_operand);
        vmask_operand = {VLEN{1'b1}};
        opcode        = `INST_VADD_VV; // assumes masks/encodings in biriscv_defs.v
        opcode_valid  = 1'b1;
        @(posedge clk);
        opcode_valid  = 1'b0;

        @(posedge clk); // registered outputs
        if (!writeback_valid) begin
            $fatal("vadd.vv: writeback_valid not asserted");
        end
        if (writeback_value !== {32'h0000_0044, 32'h0000_0033, 32'h0000_0022, 32'h0000_0011}) begin
            $fatal("vadd.vv: mismatch got %h", writeback_value);
        end
        else begin
            $display("vadd.vv OK");
        end

        //------------------------------------------------------------------
        // Test 2: vadd.vx (vm=1), add scalar 5
        //------------------------------------------------------------------
        set_vec(32'h0000_0001, 32'h0000_0002, 32'h0000_0003, 32'h0000_0004, va_operand);
        vb_operand    = {VLEN{1'b0}};
        ra_operand    = 32'h0000_0005; // scalar register value
        opcode        = `INST_VADD_VX;
        opcode_valid  = 1'b1;
        @(posedge clk);
        opcode_valid  = 1'b0;

        @(posedge clk);
        if (!writeback_valid) begin
            $fatal("vadd.vx: writeback_valid not asserted");
        end
        if (writeback_value !== {32'h0000_0009, 32'h0000_0008, 32'h0000_0007, 32'h0000_0006}) begin
            $fatal("vadd.vx: mismatch got %h", writeback_value);
        end
        else begin
            $display("vadd.vx OK");
        end

        $display("All VALU tests passed");
        #20 $finish;
    end
endmodule
