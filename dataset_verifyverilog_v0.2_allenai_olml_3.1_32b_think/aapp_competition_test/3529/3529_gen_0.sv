module spanning_tree_check(input clk, input rst_n, input start, input [2:0] n, input [4:0] k, input [3:0] m, input [3:0] edge_index, input edge_valid, input [2:0] node_u, input [2:0] node_v, input edge_color, output reg result, output reg done);

localparam IDLE = 4'd0, LOAD_EDGES = 4'd1, INIT_DSU = 4'd2, COMPUTE_MIN_FIRST_PASS = 4'd3, COMPUTE_MIN_SECOND_PASS = 4'd4, COMPUTE_MAX_FIRST_PASS = 4'd5, COMPUTE_MAX_SECOND_PASS = 4'd6, CHECK_RESULT = 4'd7, DONE_STATE = 4'd8;

reg [3:0] state, edge_count, min_blue_count, max_blue_count, k_value;
reg [2:0] parent [8];
reg [7:0] edge_buf_u [16], edge_buf_v [16];
reg [0:0] edge_buf_color [16];
reg [2:0] min_first_counter, min_second_counter, max_first_counter, max_second_counter;

always @(posedge clk) begin
 if (!rst_n) begin
 state <= IDLE;
 edge_count <= 0;
 min_blue_count <= 0;
 max_blue_count <= 0;
 k_value <= 0;
 min_first_counter <= 0;
 min_second_counter <= 0;
 max_first_counter <= 0;
 max_second_counter <= 0;
 parent[0] <= 0;
 parent[1] <= 1;
 parent[2] <= 2;
 parent[3] <= 3;
 parent[4] <= 4;
 parent[5] <= 5;
 parent[6] <= 6;
 parent[7] <= 7;
 end
 else begin
 if (state == IDLE) begin
 if (start) begin
 k_value <= k;
 state <= LOAD_EDGES;
 end
 end
 if (state == LOAD_EDGES) begin
 if (edge_valid) begin
 edge_buf_u[edge_count] <= node_u - 1;
 edge_buf_v[edge_count] <= node_v - 1;
 edge_buf_color[edge_count] <= edge_color;
 edge_count <= edge_count + 1;
 end
 if (edge_count == m) state <= INIT_DSU;
 end
 if (state == INIT_DSU) begin
 parent[0] <= 0;
 parent[1] <= 1;
 parent[2] <= 2;
 parent[3] <= 3;
 parent[4] <= 4;
 parent[5] <= 5;
 parent[6] <= 6;
 parent[7] <= 7;
 state <= COMPUTE_MIN_FIRST_PASS;
 min_first_counter <= 0;
 min_blue_count <= 0;
 end
 if (state == COMPUTE_MIN_FIRST_PASS) begin
 if (min_first_counter < m) begin
 int current_color = edge_buf_color[min_first_counter];
 if (current_color == 0) begin
 int u = edge_buf_u[min_first_counter];
 int v = edge_buf_v[min_first_counter];
 int root_u = u;
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 int root_v = v;
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (root_u != root_v) parent[root_v] <= root_u;
 end
 min_first_counter <= min_first_counter + 1;
 end else begin
 state <= COMPUTE_MIN_SECOND_PASS;
 min_first_counter <= 0;
 min_blue_count <= 0;
 end
 end
 if (state == COMPUTE_MIN_SECOND_PASS) begin
 if (min_second_counter < m) begin
 int current_color = edge_buf_color[min_second_counter];
 if (current_color == 1) begin
 int u = edge_buf_u[min_second_counter];
 int v = edge_buf_v[min_second_counter];
 int root_u = u;
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 int root_v = v;
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (root_u != root_v) begin
 parent[root_v] <= root_u;
 min_blue_count <= min_blue_count + 1;
 end
 end
 min_second_counter <= min_second_counter + 1;
 end else begin
 state <= INIT_DSU;
 min_second_counter <= 0;
 end
 end
 if (state == COMPUTE_MAX_FIRST_PASS) begin
 if (max_first_counter < m) begin
 int current_color = edge_buf_color[max_first_counter];
 if (current_color == 1) begin
 int u = edge_buf_u[max_first_counter];
 int v = edge_buf_v[max_first_counter];
 int root_u = u;
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 int root_v = v;
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (root_u != root_v) begin
 parent[root_v] <= root_u;
 max_blue_count <= max_blue_count + 1;
 end
 end
 max_first_counter <= max_first_counter + 1;
 end else begin
 state <= COMPUTE_MAX_SECOND_PASS;
 max_first_counter <= 0;
 max_blue_count <= 0;
 end
 end
 if (state == COMPUTE_MAX_SECOND_PASS) begin
 if (max_second_counter < m) begin
 int current_color = edge_buf_color[max_second_counter];
 if (current_color == 0) begin
 int u = edge_buf_u[max_second_counter];
 int v = edge_buf_v[max_second_counter];
 int root_u = u;
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 if (parent[root_u] != root_u) root_u = parent[root_u];
 int root_v = v;
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (parent[root_v] != root_v) root_v = parent[root_v];
 if (root_u != root_v) parent[root_v] <= root_u;
 end
 max_second_counter <= max_second_counter + 1;
 end else begin
 state <= CHECK_RESULT;
 max_second_counter <= 0;
 end
 end
 if (state == CHECK_RESULT) begin
 if (k_value >= min_blue_count && k_value <= max_blue_count) result <= 1;
 else result <= 0;
 done <= 1;
 state <= DONE_STATE;
 end
 if (state == DONE_STATE) done <= 1;
 end
endmodule