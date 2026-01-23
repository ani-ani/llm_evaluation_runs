module peg_planner (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] t,
    input [3:0] dry_step_idx,
    input [3:0] dry_op,
    input [3:0] dep_count_in,
    input [3:0] dep_val,
    input dep_ready,
    output reg [3:0] wet_op,
    output reg wet_op_valid,
    output reg [6:0] wet_step_cnt,
    output reg done,
    output reg error
);

    // Default assignments to prevent latches
    assign wet_op = 4'd0;
    assign wet_op_valid = 1'b0;
    assign wet_step_cnt = 8'd0;
    assign done = 1'b0;
    assign error = 1'b0;

endmodule