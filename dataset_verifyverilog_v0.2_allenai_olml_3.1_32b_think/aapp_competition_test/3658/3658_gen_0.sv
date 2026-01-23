module species_intersection_area (input clk, input rst_n, input start, input [3:0] pine_count, input [3:0] aspen_count, input [7:0] pine_x0, pine_x1, pine_x2, pine_x3, input [7:0] pine_y0, pine_y1, pine_y2, pine_y3, input [7:0] aspen_x0, aspen_x1, aspen_x2, aspen_x3, input [7:0] aspen_y0, aspen_y1, aspen_y2, aspen_y3, output reg [31:0] intersection_area, output reg done, output reg error);
reg [2:0] state;
always_ff @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 3'd0;
intersection_area <= 32'd0;
done <= 1'b0;
error <= 1'b0;
end else begin
if (state == 3'd0) begin
if (start) begin
if (pine_count < 3 || aspen_count < 3) begin
intersection_area <= 32'd0;
done <= 1'b1;
error <= 1'b0;
state <= 3'd1;
end else begin
state <= 3'd1;
end
end
end
end
end
endmodule