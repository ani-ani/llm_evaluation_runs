module fence_cuts (input clk, input rst_n, input start, input [7:0] k, input [7:0] p0, p1, p2, p3, output reg [7:0] min_cuts, output reg done);

wire [7:0] max_pole;
assign max_pole = p0 > p1 ? p0 : p1;
assign max_pole = max_pole > p2 ? max_pole : p2;
assign max_pole = max_pole > p3 ? max_pole : p3;

reg [2:0] state;
reg [7:0] low_reg, high_reg, best_L_reg;
reg [7:0] min_cuts_reg;
reg done_reg;

parameter IDLE = 3'd0;
parameter SEARCH = 3'd1;
parameter CALC = 3'd2;
parameter UPDATE = 3'd3;
parameter DONE = 3'd4;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
low_reg <= 8'b0;
high_reg <= 8'b0;
best_L_reg <= 8'b0;
min_cuts_reg <= 8'b0;
done_reg <= 1'b0;
end else begin
if (state == IDLE) begin
if (start) begin
low_reg <= 1;
high_reg <= max_pole;
best_L_reg <= 8'b0;
state <= SEARCH;
end
end
else if (state == SEARCH) begin
if (low_reg <= high_reg) begin
int mid;
mid = (low_reg + high_reg) / 2;
int total_posts;
total_posts = 0;
if (k >= 1) total_posts += p0 / mid;
if (k >= 2) total_posts += p1 / mid;
if (k >= 3) total_posts += p2 / mid;
if (k >= 4) total_posts += p3 / mid;

if (total_posts >= n) begin
best_L_reg <= mid;
low_reg <= mid + 1;
end else begin
high_reg <= mid - 1;
end
end else begin
state <= CALC;
end
end
else if (state == CALC) begin
int total_cuts;
total_cuts = 0;
if (best_L_reg != 0) begin
if (k >=1) begin
int len = p0;
if (len % best_L_reg == 0) begin
total_cuts += len / best_L_reg - 1;
end else begin
total_cuts += len / best_L_reg;
end
end
if (k >=2) begin
int len = p1;
if (len % best_L_reg == 0) begin
total_cuts += len / best_L_reg - 1;
end else begin
total_cuts += len / best_L_reg;
end
end
if (k >=3) begin
int len = p2;
if (len % best_L_reg == 0) begin
total_cuts += len / best_L_reg - 1;
end else begin
total_cuts += len / best_L_reg;
end
end
if (k >=4) begin
int len = p3;
if (len % best_L_reg == 0) begin
total_cuts += len / best_L_reg - 1;
end else begin
total_cuts += len / best_L_reg;
end
end
end
min_cuts_reg <= total_cuts;
state <= UPDATE;
end
else if (state == UPDATE) begin
done_reg <= 1'b1;
state <= DONE;
end
end
end

always @(*) begin
min_cuts = min_cuts_reg;
done = done_reg;
end

endmodule