module rectangular_sum(input clk, input rst_n, input start, input [31:0] a, input [3:0] length, input [15:0][3:0] digits, output reg [31:0] result, output reg done);
localparam IDLE = 3'd0, PHASE1_GEN_SUBARRAYS = 3'd1, PHASE1_STORE = 3'd2, PHASE2_COUNT = 3'd3, PHASE3_CALC = 3'd4, DONE = 3'd5;
reg [2:0] state;
reg [3:0] i, j;
reg [31:0] current_sum;
reg [31:0] subarray_sums[136];
reg [7:0] subarray_idx;
reg [7:0] freq[145];
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
i <= 0;
j <= 0;
current_sum <= 0;
subarray_idx <= 0;
end else begin
if (state == IDLE) begin
if (start) state <= PHASE1_GEN_SUBARRAYS;
end else if (state == PHASE1_GEN_SUBARRAYS) begin
if (i < length) begin
if (j < i) begin
j <= i;
current_sum <= 0;
end else if (j < length) begin
reg [3:0] d;
case (j)
0: d = digits[0][3:0];
1: d = digits[1][3:0];
2: d = digits[2][3:0];
3: d = digits[3][3:0];
4: d = digits[4][3:0];
5: d = digits[5][3:0];
6: d = digits[6][3:0];
7: d = digits[7][3:0];
8: d = digits[8][3:0];
9: d = digits[9][3:0];
10: d = digits[10][3:0];
11: d = digits[11][3:0];
12: d = digits[12][3:0];
13: d = digits[13][3:0];
14: d = digits[14][3:0];
15: d = digits[15][3:0];
default: d = 4'd0;
endcase
current_sum <= current_sum + d;
subarray_sums[subarray_idx] <= current_sum;
subarray_idx <= subarray_idx + 1;
j <= j + 1;
end
else begin
i <= i + 1;
j <= i;
current_sum <= 0;
end
end else begin
if (j >= length) begin
i <= i + 1;
j <= i;
current_sum <= 0;
end
end
end else if (state == PHASE1_STORE) state <= PHASE2_COUNT;
end
assign done = (state == DONE);
endmodule