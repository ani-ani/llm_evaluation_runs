module max_ranks (
input clk,
input rst_n, // active low
input start,
input [2:0] n,
input [7:0] k,
input [7:0] a [0:7],
input [7:0] b [0:7],
output reg [3:0] result,
output reg done
);

parameter IDLE = 2'd0, BUILD_GRAPH = 2'd1, COMPUTE_MATCHING = 2'd2, DONE = 2'd3;
parameter MATCH_NONE = 8'hFF;

reg [2:0] state;
reg [7:0] n_reg;
reg [7:0] k_reg;
reg [7:0] a_reg [0:7];
reg [7:0] b_reg [0:7];
reg [7:0] matchR [0:7];
reg [3:0] result_reg;
reg done_reg;

reg [7:0][7:0] bipart_adj;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
n_reg <= 8'd0;
k_reg <= 8'd0;
a_reg <= 8'd0;
b_reg <= 8'd0;
matchR <= MATCH_NONE;
result_reg <= 4'd0;
done_reg <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
state <= BUILD_GRAPH;
end else begin
state <= IDLE;
end
end
BUILD_GRAPH: begin
n_reg <= n;
k_reg <= k;
a_reg <= a;
b_reg <= b;
state <= COMPUTE_MATCHING;
end
COMPUTE_MATCHING: begin
for (int i=0; i < n_reg; i++) begin
for (int j=0; j < n_reg; j++) begin
if (i == j) begin
bipart_adj[i][j] = 1'b0;
end else begin
integer cond;
cond = (a_reg[i] + k_reg < a_reg[j]) || (b_reg[i] + k_reg < b_reg[j]);
bipart_adj[i][j] = cond ? 1'b1 : 1'b0;
end
end
end
for (int j=0; j < n_reg; j++) begin
matchR[j] = MATCH_NONE;
end
for (int u=0; u < n_reg; u++) begin
for (int v=0; v < n_reg; v++) begin
if (bipart_adj[u][v] == 1'b1 && matchR[v] == MATCH_NONE) begin
matchR[v] = u;
end
end
end
integer matching_size = 0;
for (int j=0; j < n_reg; j++) begin
if (matchR[j] != MATCH_NONE) begin
matching_size++;
end
end
result_reg <= n_reg - matching_size;
done_reg <= 1'b1;
state <= DONE;
end
DONE: begin
done_reg <= 1'b1;
// stay in DONE
end
endcase
end
end

assign result = result_reg;
assign done = done_reg;

endmodule