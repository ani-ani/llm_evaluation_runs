module min_pair_distance (
input clk,
input rst_n, // Active-low reset
input start,
input [3:0] n,
input signed [15:0] a [0:7],
output reg [31:0] min_dist,
output reg done)

reg [2:0] state; // 0:IDLE, 1:CALC_PREFIX, 2:CALC_DIST, 3:DONE
reg [31:0] min_dist_reg;
reg [31:0] prefix_reg [0:8];
reg [2:0] current_i;
reg [2:0] current_j;
reg [3:0] prefix_counter;
reg [31:0] temp_distance;

localparam N_MAX = 8;
assign n_clamped = (n > N_MAX) ? N_MAX : n;

always_ff @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 0;
min_dist_reg <= 32'hFFFFFFFF;
prefix_counter <= 0;
current_i <= 0;
current_j <= 0;
prefix_reg <= 32'h0;
end else begin
case (state)
0: // IDLE
if (start) begin
state <= 1;
prefix_counter <= 0;
end
1: // CALC_PREFIX
if (prefix_counter < 8) begin
prefix_reg[prefix_counter + 1] = prefix_reg[prefix_counter] + a[prefix_counter];
prefix_counter <= prefix_counter + 1;
end else begin
state <= 2;
current_i <= 0;
current_j <= 1;
end
2: // CALC_DIST
if (current_i >= n_clamped - 1) begin
state <= 3;
end else begin
temp_distance = (current_i - current_j) * (current_i - current_j) + (prefix_reg[current_i + 1] - prefix_reg[current_j + 1]) * (prefix_reg[current_i + 1] - prefix_reg[current_j + 1]);
if (temp_distance < min_dist_reg) begin
min_dist_reg <= temp_distance;
end
if (current_j < n_clamped - 1) begin
current_j <= current_j + 1;
end else begin
current_i <= current_i + 1;
if (current_i < n_clamped - 1) begin
current_j <= current_i + 1;
end else begin
state <= 3;
end
end
end
3: // DONE
if (!start) begin
state <= 0;
end
default: state <=3;
endcase
end
end

assign min_dist = min_dist_reg;
assign done = (state == 3);

endmodule