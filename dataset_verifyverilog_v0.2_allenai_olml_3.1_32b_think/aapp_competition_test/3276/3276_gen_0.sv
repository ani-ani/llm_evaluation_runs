module stamp_verification(input clk, input rst_n, input start, input [1:0] row_idx, input [1:0] col_idx, input [1:0] target_color, output reg result, output reg done);
wire valid_signal;
reg [31:0] grid;
reg [4:0] count;
reg [1:0] state;
localparam IDLE = 2'd0;
localparam LOAD_GRID = 2'd1;
localparam ANALYZE = 2'd2;
assign valid_signal = (grid[3:2] == grid[5:4]) && (grid[9:8] == grid[17:16]) && (grid[13:12] == grid[11:10] && grid[19:18] == grid[11:10] && grid[21:20] == grid[11:10]) && (grid[15:14] == grid[23:22]) && (grid[29:28] == grid[27:26]);
always_ff @(posedge clk) begin
if (!rst_n) begin
grid <= 32'd0;
count <= 5'd0;
state <= IDLE;
result <= 1'b0;
done <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start == 1'b1) begin
state <= LOAD_GRID;
count <= 5'd0;
end else begin
state <= IDLE;
end
end
LOAD_GRID: begin
if (start == 1'b1) begin
int r = row_idx;
int c = col_idx;
[1:0] color = target_color;
int addr = (r*4 + c)*2;
grid[addr +1] <= color[1];
grid[addr +0] <= color[0];
count <= count +1;
if (count == 16) begin
state <= ANALYZE;
end
end
end
ANALYZE: begin
result <= valid_signal;
done <= 1'b1;
state <= ANALYZE;
end
default: state <= IDLE;
endcase
end
end
endmodule