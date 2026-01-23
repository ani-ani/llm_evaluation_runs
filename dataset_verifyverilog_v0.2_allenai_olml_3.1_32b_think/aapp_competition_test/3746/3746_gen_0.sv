module hanoi_min_cost (
input clk,
input rst_n,
input start,
input [2:0] matrix_in,
input [5:0] n,
input [2:0] rod_index,
input load_matrix,
output reg [63:0] result,
output reg done
);

reg [1:0] state, next_state;
reg [1:0] row_count;
reg [5:0] disk;
reg [63:0] prev_dp [3][3], next_dp [3][3];
reg [3][3] matrix_reg;

localparam IDLE = 2'd0, LOAD_MATRIX = 2'd1, PROCESSING = 2'd2, DONE = 2'd3;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE; next_state <= IDLE;
row_count <=0; disk <=0;
prev_dp[0][0] <=0; prev_dp[0][1] <=0; prev_dp[0][2] <=0;
prev_dp[1][0] <=0; prev_dp[1][1] <=0; prev_dp[1][2] <=0;
prev_dp[2][0] <=0; prev_dp[2][1] <=0; prev_dp[2][2] <=0;
matrix_reg[0][0] <=0; matrix_reg[0][1] <=0; matrix_reg[0][2] <=0;
matrix_reg[1][0] <=0; matrix_reg[1][1] <=0; matrix_reg[1][2] <=0;
matrix_reg[2][0] <=0; matrix_reg[2][1] <=0; matrix_reg[2][2] <=0;
result <=0; done <=0;
end else begin
state <= next_state;
if (state == IDLE) begin
if (start) next_state <= LOAD_MATRIX; else next_state <= IDLE;
end else if (state == LOAD_MATRIX) begin
if (load_matrix && (rod_index == row_count)) begin
matrix_reg[row_count][0] <= matrix_in[0];
matrix_reg[row_count][1] <= matrix_in[1];
matrix_reg[row_count][2] <= matrix_in[2];
if (row_count < 2) row_count <= row_count +1; else next_state <= PROCESSING;
end else next_state <= LOAD_MATRIX;
end else if (state == PROCESSING) begin
if (disk < n) begin
prev_dp <= next_dp; disk <= disk +1; next_state <= PROCESSING;
end else begin
result <= prev_dp[0][2]; done <=1; next_state <= DONE;
end
end else if (state == DONE) next_state <= DONE;
end
end

always @(*) begin
if (state == PROCESSING && disk < n) begin
// Compute next_dp for all pairs
// 0,1
if (0!=1) begin
logic [63:0] cost1, cost2;
logic [1:0] other=2;
cost1 = prev_dp[0][other] + matrix_reg[0][1] + prev_dp[other][1];
cost2 = prev_dp[0][1] + matrix_reg[0][other] + prev_dp[1][0] + matrix_reg[other][1] + prev_dp[0][1];
if (cost1 < cost2) next_dp[0][1] = cost1; else next_dp[0][1] = cost2;
end else next_dp[0][1] =0;
// 0,2
if (0!=2) begin
logic [63:0] cost1, cost2;
logic [1:0] other=1;
cost1 = prev_dp[0][other] + matrix_reg[0][2] + prev_dp[other][2];
cost2 = prev_dp[0][2] + matrix_reg[0][other] + prev_dp[2][0] + matrix_reg[other][2] + prev_dp[0][2];
if (cost1 < cost2) next_dp[0][2] = cost1; else next_dp[0][2] = cost2;
end else next_dp[0][2] =0;
// 1,0
if (1!=0) begin
logic [63:0] cost1, cost2;
logic [1:0] other=2;
cost1 = prev_dp[1][other] + matrix_reg[1][0] + prev_dp[other][0];
cost2 = prev_dp[1][0] + matrix_reg[1][other] + prev_dp[0][1] + matrix_reg[other][0] + prev_dp[1][0];
if (cost1 < cost2) next_dp[1][0] = cost1; else next_dp[1][0] = cost2;
end else next_dp[1][0] =0;
// 1,2
if (1!=2) begin
logic [63:0] cost1, cost2;
logic [1:0] other=0;
cost1 = prev_dp[1][other] + matrix_reg[1][2] + prev_dp[other][2];
cost2 = prev_dp[1][2] + matrix_reg[1][other] + prev_dp[2][1] + matrix_reg[other][2] + prev_dp[1][2];
if (cost1 < cost2) next_dp[1][2] = cost1; else next_dp[1][2] = cost2;
end else next_dp[1][2] =0;
// 2,0
if (2!=0) begin
logic [63:0] cost1, cost2;
logic [1:0] other=1;
cost1 = prev_dp[2][other] + matrix_reg[2][0] + prev_dp[other][0];
cost2 = prev_dp[2][0] + matrix_reg[2][other] + prev_dp[0][2] + matrix_reg[other][0] + prev_dp[2][0];
if (cost1 < cost2) next_dp[2][0] = cost1; else next_dp[2][0] = cost2;
end else next_dp[2][0] =0;
// 2,1
if (2!=1) begin
logic [63:0] cost1, cost2;
logic [1:0] other=0;
cost1 = prev_dp[2][other] + matrix_reg[2][1] + prev_dp[other][1];
cost2 = prev_dp[2][1] + matrix_reg[2][other] + prev_dp[1][2] + matrix_reg[other][1] + prev_dp[2][1];
if (cost1 < cost2) next_dp[2][1] = cost1; else next_dp[2][1] = cost2;
end else next_dp[2][1] =0;
next_dp[0][0] =0; next_dp[1][1]=0; next_dp[2][2]=0;
end
end
endmodule