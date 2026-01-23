module quadrilateral_game_score (
input clk,
input rst_n,
input start,
input [11:0] x_i [0:7],
input [11:0] y_i [0:7],
output reg [31:0] total_score,
output reg done
);

localparam integer MOD = 1000003;
localparam integer MAX_COMBS = 70;

reg [11:0] x_reg [0:7];
reg [11:0] y_reg [0:7];
reg [31:0] total;
reg [6:0] count;
reg [2:0] state;
localparam IDLE = 3'd0, LOAD = 3'd1, CALCULATE = 3'd2, DONE = 3'd3;
reg [2:0] state;
reg done_reg;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
count <= 0;
total <= 0;
done_reg <= 0;
x_reg <= 0;
y_reg <= 0;
end else begin
if (state == IDLE) begin
if (start) state <= LOAD;
end else if (state == LOAD) begin
x_reg <= x_i;
y_reg <= y_i;
state <= CALCULATE;
count <= 0;
total <= 0;
end else if (state == CALCULATE) begin
if (count < MAX_COMBS) begin
integer i = count[5:3], j = count[2:0], k=0, l=0;
integer sum;
sum = (x_reg[i] * y_reg[j] - x_reg[j] * y_reg[i]) + (x_reg[j] * y_reg[k] - x_reg[k] * y_reg[j]) + (x_reg[k] * y_reg[l] - x_reg[l] * y_reg[k]) + (x_reg[l] * y_reg[i] - x_reg[i] * y_reg[l]);
if (sum <0) sum = -sum;
total = (total + sum) % MOD;
count <= count +1;
end else begin
state <= DONE;
done_reg <=1;
end
end
end
end

assign total_score = total;
assign done = done_reg;

endmodule