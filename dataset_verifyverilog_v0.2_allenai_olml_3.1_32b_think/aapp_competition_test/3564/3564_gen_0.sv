module island_network_min_tunnel (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_islands,
    input [7:0] num_trees,
    input [31:0] k_ratio,
    input [31:0] island_x [0:7],
    input [31:0] island_y [0:7],
    input [31:0] island_r [0:7],
    input [31:0] tree_x [0:7],
    input [31:0] tree_y [0:7],
    input [31:0] tree_h [0:7],
    output reg [31:0] min_tunnel_length,
    output reg done,
    output reg impossible
);

reg [31:0] reg_num_islands, reg_num_trees, reg_k_ratio;
reg [31:0] reg_island_x [0:7], reg_island_y [0:7], reg_island_r [0:7];
reg [31:0] reg_tree_x [0:7], reg_tree_y [0:7], reg_tree_h [0:7];
reg [31:0] range_tree [0:7];

// State machine
typedef enum {IDLE, PREPARE, COMPUTE_RANGES, BUILD_GRAPH, FIND_COMPONENTS, CHECK_CONNECTION, CALCULATE_MIN, DONE} state_t;
reg [7:0] state, next_state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        reg_num_islands <= 8'd0;
        reg_num_trees <= 8'd0;
        reg_k_ratio <= 32'd0;
        reg_island_x[0] <= 32'd0; reg_island_x[1] <=32'd0; reg_island_x[2] <=32'd0; reg_island_x[3] <=32'd0;
        reg_island_x[4] <=32'd0; reg_island_x[5] <=32'd0; reg_island_x[6] <=32'd0; reg_island_x[7] <=32'd0;
        reg_island_y[0] <= 32'd0; reg_island_y[1] <=32'd0; reg_island_y[2] <=32'd0; reg_island_y[3] <=32'd0;
        reg_island_y[4] <=32'd0; reg_island_y[5] <=32'd0; reg_island_y[6] <=32'd0; reg_island_y[7] <=32'd0;
        reg_island_r[0] <= 32'd0; reg_island_r[1] <=32'd0; reg_island_r[2] <=32'd0; reg_island_r[3] <=32'd0;
        reg_island_r[4] <=32'd0; reg_island_r[5] <=32'd0; reg_island_r[6] <=32'd0; reg_island_r[7] <=32'd0;
        reg_tree_x[0] <= 32'd0; reg_tree_x[1] <=32'd0; reg_tree_x[2] <=32'd0; reg_tree_x[3] <=32'd0;
        reg_tree_x[4] <=32'd0; reg_tree_x[5] <=32'd0; reg_tree_x[6] <=32'd0; reg_tree_x[7] <=32'd0;
        reg_tree_y[0] <= 32'd0; reg_tree_y[1] <=32'd0; reg_tree_y[2] <=32'd0; reg_tree_y[3] <=32'd0;
        reg_tree_y[4] <=32'd0; reg_tree_y[5] <=32'd0; reg_tree_y[6] <=32'd0; reg_tree_y[7] <=32'd0;
        reg_tree_h[0] <= 32'd0; reg_tree_h[1] <=32'd0; reg_tree_h[2] <=32'd0; reg_tree_h[3] <=32'd0;
        reg_tree_h[4] <=32'd0; reg_tree_h[5] <=32'd0; reg_tree_h[6] <=32'd0; reg_tree_h[7] <=32'd0;
        range_tree[0] <=32'd0; range_tree[1] <=32'd0; range_tree[2] <=32'd0; range_tree[3] <=32'd0;
        range_tree[4] <=32'd0; range_tree[5] <=32'd0; range_tree[6] <=32'd0; range_tree[7] <=32'd0;
        next_state <= IDLE;
        min_tunnel_length <=32'd0;
        done <=1'b0;
        impossible <=1'b0;
    end else begin
        state <= next_state;
        if (state == PREPARE) begin
            reg_num_islands <= num_islands;
            reg_num_trees <= num_trees;
            reg_k_ratio <= k_ratio;
            reg_island_x[0] <= island_x[0]; reg_island_x[1] <= island_x[1]; reg_island_x[2] <= island_x[2]; reg_island_x[3] <= island_x[3];
            reg_island_x[4] <= island_x[4]; reg_island_x[5] <= island_x[5]; reg_island_x[6] <= island_x[6]; reg_island_x[7] <= island_x[7];
            reg_island_y[0] <= island_y[0]; reg_island_y[1] <= island_y[1]; reg_island_y[2] <= island_y[2]; reg_island_y[3] <= island_y[3];
            reg_island_y[4] <= island_y[4]; reg_island_y[5] <= island_y[5]; reg_island_y[6] <= island_y[6]; reg_island_y[7] <= island_y[7];
            reg_island_r[0] <= island_r[0]; reg_island_r[1] <= island_r[1]; reg_island_r[2] <= island_r[2]; reg_island_r[3] <= island_r[3];
            reg_island_r[4] <= island_r[4]; reg_island_r[5] <= island_r[5]; reg_island_r[6] <= island_r[6]; reg_island_r[7] <= island_r[7];
            reg_tree_x[0] <= tree_x[0]; reg_tree_x[1] <= tree_x[1]; reg_tree_x[2] <= tree_x[2]; reg_tree_x[3] <= tree_x[3];
            reg_tree_x[4] <= tree_x[4]; reg_tree_x[5] <= tree_x[5]; reg_tree_x[6] <= tree_x[6]; reg_tree_x[7] <= tree_x[7];
            reg_tree_y[0] <= tree_y[0]; reg_tree_y[1] <= tree_y[1]; reg_tree_y[2] <= tree_y[2]; reg_tree_y[3] <= tree_y[3];
            reg_tree_y[4] <= tree_y[4]; reg_tree_y[5] <= tree_y[5]; reg_tree_y[6] <= tree_y[6]; reg_tree_y[7] <= tree_y[7];
            reg_tree_h[0] <= tree_h[0]; reg_tree_h[1] <= tree_h[1]; reg_tree_h[2] <= tree_h[2]; reg_tree_h[3] <= tree_h[3];
            reg_tree_h[4] <= tree_h[4]; reg_tree_h[5] <= tree_h[5]; reg_tree_h[6] <= tree_h[6]; reg_tree_h[7] <= tree_h[7];
            next_state <= COMPUTE_RANGES;
        end
        if (state == COMPUTE_RANGES) begin
            range_tree[0] = (reg_k_ratio * reg_tree_h[0]) >> 16;
            range_tree[1] = (reg_k_ratio * reg_tree_h[1]) >> 16;
            range_tree[2] = (reg_k_ratio * reg_tree_h[2]) >> 16;
            range_tree[3] = (reg_k_ratio * reg_tree_h[3]) >> 16;
            range_tree[4] = (reg_k_ratio * reg_tree_h[4]) >> 16;
            range_tree[5] = (reg_k_ratio * reg_tree_h[5]) >> 16;
            range_tree[6] = (reg_k_ratio * reg_tree_h[6]) >> 16;
            range_tree[7] = (reg_k_ratio * reg_tree_h[7]) >> 16;
            next_state <= BUILD_GRAPH;
        end
        if (state == DONE) next_state <= DONE;
    end
end

assign min_tunnel_length = 32'd0;
assign done = 1'b0;
assign impossible = 1'b0;

endmodule