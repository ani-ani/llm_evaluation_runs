module chemical_table (
input clk,
input rst_n, 
input start,
input [3:0] n,
input [3:0] m,
input [3:0] q,
input valid_in,
input [3:0] r,
input [3:0] c,
output reg [7:0] result,
output reg done,
output reg rden
);
reg [15:0] parent [0:15];
reg [15:0] rank [0:15];
reg [2:0] state;
localparam IDLE = 3'd0, INIT_DSU = 3'd1, READ_ELEMENTS = 3'd2, COUNT_COMPONENTS = 3'd3, DONE_STATE = 3'd4;
reg [3:0] sampled_n, sampled_m, sampled_q;
reg [3:0] element_counter;
reg [3:0] current_r, current_c;
reg [15:0] current_node;
reg [15:0] unique_components;
reg [15:0] last_root;
function automatic [15:0] find;
input [15:0] node;
reg [15:0] temp;
begin
temp = node;
for (int i=0; i<16; i++) begin
if (parent[temp] == temp) begin
parent[node] = temp;
return temp;
end
temp = parent[temp];
end
parent[node] = temp;
return temp;
end
endfunction
function automatic;
input [15:0] a, b;
reg [15:0] roota, rootb;
begin
roota = find(a);
rootb = find(b);
if (roota == rootb) return;
if (rank[roota] > rank[rootb]) begin
parent[rootb] = roota;
end else begin
parent[roota] = rootb;
if (rank[roota] == rank[rootb]) begin
rank[rootb] = rank[rootb] + 1;
end
end
end
endfunction
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
sampled_n <= 4'd0;
sampled_m <= 4'd0;
sampled_q <= 4'd0;
element_counter <= 4'd0;
result <= 8'd0;
done <= 1'b0;
current_r <= 4'd0;
current_c <= 4'd0;
current_node <= 16'd0;
unique_components <= 16'd0;
last_root <= 16'd0;
end else begin
case (state)
IDLE: begin
if (start) begin
sampled_n <= n;
sampled_m <= m;
sampled_q <= q;
state <= INIT_DSU;
end
end
INIT_DSU: begin
parent[0] = 0; rank[0] = 0;
parent[1] = 1; rank[1] = 0;
parent[2] = 2; rank[2] = 0;
parent[3] = 3; rank[3] = 0;
parent[4] = 4; rank[4] = 0;
parent[5] = 5; rank[5] = 0;
parent[6] = 6; rank[6] = 0;
parent[7] = 7; rank[7] = 0;
parent[8] = 8; rank[8] = 0;
parent[9] = 9; rank[9] = 0;
parent[10] = 10; rank[10] = 0;
parent[11] = 11; rank[11] = 0;
parent[12] = 12; rank[12] = 0;
parent[13] = 13; rank[13] = 0;
parent[14] = 14; rank[14] = 0;
parent[15] = 15; rank[15] = 0;
state <= READ_ELEMENTS;
end
READ_ELEMENTS: begin
if (valid_in) begin
current_r <= r;
current_c <= c;
int c_node = current_c + sampled_n;
union(current_r, c_node);
element_counter <= element_counter + 1;
if (element_counter == sampled_q) begin
state <= COUNT_COMPONENTS;
current_node <= 16'd0;
unique_components <= 16'd0;
last_root <= 16'd0;
end
end
rden <= valid_in;
end
COUNT_COMPONENTS: begin
if (current_node < (sampled_n + sampled_m)) begin
int root = find(current_node);
if (root != last_root) begin
unique_components <= unique_components + 1;
last_root <= root;
end
current_node <= current_node + 1;
end else begin
result <= unique_components - 1;
done <= 1'b1;
state <= DONE_STATE;
end
end
DONE_STATE: begin
done <= 1'b1;
end
endcase
end
endmodule
endmodule