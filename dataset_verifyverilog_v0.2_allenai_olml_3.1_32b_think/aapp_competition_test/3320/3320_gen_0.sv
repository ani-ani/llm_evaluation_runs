module or_path_calculator (
input clk
input rst_n
input start
input [3:0] node_count
input [3:0] edge_count
input [15:0] edges [0:15]
input [3:0] query_s
input [3:0] query_t
output reg [15:0] result
output reg done
);

reg [2:0] state;
reg [3:0] n_nodes;
reg [3:0] n_edges;
reg [15:0] edges_reg [0:15];
reg [3:0] query_src;
reg [3:0] query_dst;
reg [15:0] dist [7:0][7:0];
reg [6:0] counter;

always @(posedge clk) begin
if (!rst_n) begin
state <= 3'd0;
done <= 1'b0;
n_nodes <= 4'd0;
n_edges <= 4'd0;
query_src <= 4'd0;
query_dst <= 4'd0;
counter <= 16'd0;
end else begin
if (state == 3'd0) begin
if (start == 1'b1) state <= 3'd1;
end
else if (state == 3'd1) begin
n_nodes <= node_count;
n_edges <= edge_count;
edges_reg <= edges;
query_src <= query_s;
query_dst <= query_t;
state <= 3'd2;
end
else if (state == 3'd2) begin
if (query_src < n_nodes && query_dst < n_nodes) begin
if (query_src == query_dst) result <= 16'd0;
else result <= 16'dFFFF;
end
else result <= 16'dFFFF;
if (counter < 50) begin
counter <= counter + 1;
state <= 3'd2;
end
else begin
state <= 3'd3;
done <= 1'b1;
end
end
else if (state == 3'd3) begin
done <= 1'b1;
state <= 3'd3;
end
end
end
endmodule