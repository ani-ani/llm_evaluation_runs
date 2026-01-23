module triangle_coverage_compare(input clk, input rst_n, input start, input [2:0] garry_tri_count, input [2:0] jerry_tri_count, input [5:0] garry_tri_0_x1, input [5:0] garry_tri_0_y1, input [5:0] garry_tri_0_x2, input [5:0] garry_tri_0_y2, input [5:0] garry_tri_0_x3, input [5:0] garry_tri_0_y3, input [5:0] garry_tri_1_x1, input [5:0] garry_tri_1_y1, input [5:0] garry_tri_1_x2, input [5:0] garry_tri_1_y2, input [5:0] garry_tri_1_x3, input [5:0] garry_tri_1_y3, input [5:0] garry_tri_2_x1, input [5:0] garry_tri_2_y1, input [5:0] garry_tri_2_x2, input [5:0] garry_tri_2_y2, input [5:0] garry_tri_2_x3, input [5:0] garry_tri_2_y3, input [5:0] garry_tri_3_x1, input [5:0] garry_tri_3_y1, input [5:0] garry_tri_3_x2, input [5:0] garry_tri_3_y2, input [5:0] garry_tri_3_x3, input [5:0] garry_tri_3_y3, input [5:0] jerry_tri_0_x1, input [5:0] jerry_tri_0_y1, input [5:0] jerry_tri_0_x2, input [5:0] jerry_tri_0_y2, input [5:0] jerry_tri_0_x3, input [5:0] jerry_tri_0_y3, input [5:0] jerry_tri_1_x1, input [5:0] jerry_tri_1_y1, input [5:0] jerry_tri_1_x2, input [5:0] jerry_tri_1_y2, input [5:0] jerry_tri_1_x3, input [5:0] jerry_tri_1_y3, input [5:0] jerry_tri_2_x1, input [5:0] jerry_tri_2_y1, input [5:0] jerry_tri_2_x2, input [5:0] jerry_tri_2_y2, input [5:0] jerry_tri_2_x3, input [5:0] jerry_tri_2_y3, input [5:0] jerry_tri_3_x1, input [5:0] jerry_tri_3_y1, input [5:0] jerry_tri_3_x2, input [5:0] jerry_tri_3_y2, input [5:0] jerry_tri_3_x3, input [5:0] jerry_tri_3_y3, output reg same, output reg done);

reg [63:0] garry_coverage, jerry_coverage;
reg [2:0] state;
reg [5:0] px_count;

localparam IDLE = 3'd0;
localparam GARRY_PROC = 3'd1;
localparam JERRY_PROC = 3'd2;
localparam COMPARE_STATE = 3'd3;
localparam DONE_STATE = 3'd4;

always @(*) begin
    state <= IDLE;
    px_count <= 0;
    garry_coverage <= 0;
    jerry_coverage <= 0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        px_count <= 0;
        garry_coverage <= 0;
        jerry_coverage <= 0;
        same <= 0;
        done <= 0;
    end
end

assign same = 0;
assign done = 0;
endmodule