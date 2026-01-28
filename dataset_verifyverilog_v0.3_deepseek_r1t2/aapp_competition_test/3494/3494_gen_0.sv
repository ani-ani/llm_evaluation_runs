module apple_distance #(
    parameter GRID_R = 8,
    parameter GRID_S = 8,
    parameter MAX_TREES = 24,
    parameter COORD_BITS = 4,
    parameter DIST_BITS = 7,
    parameter TREE_IDX_BITS = 5
)(
    input wire clk,
    input wire rst_n,
    input wire load_en,
    input wire process,
    input wire [COORD_BITS-1:0] r,
    input wire [COORD_BITS-1:0] s,
    output reg [DIST_BITS-1:0] distance,
    output reg done,
    output reg full
);

// FSM states
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] UPDATE = 2'd2;

// Tree storage and registers
reg [COORD_BITS-1:0] tree_r [0:MAX_TREES-1];
reg [COORD_BITS-1:0] tree_s [0:MAX_TREES-1];
reg [TREE_IDX_BITS-1:0] num_trees;
reg [1:0] state;

// Computation registers
reg [TREE_IDX_BITS-1:0] tree_index;
reg [DIST_BITS-1:0] current_min;
reg [COORD_BITS-1:0] query_r, query_s;
genvar i; // For loop variable

// Combinational distance wires
wire [COORD_BITS-1:0] current_r = tree_r[tree_index];
wire [COORD_BITS-1:0] current_s = tree_s[tree_index];
wire [COORD_BITS-1:0] diff_r = (query_r >= current_r) ? 
                              query_r - current_r : 
                              current_r - query_r;
wire [COORD_BITS-1:0] diff_s = (query_s >= current_s) ? 
                              query_s - current_s : 
                              current_s - query_s;
wire [6:0] current_dist = (diff_r * diff_r) + (diff_s * diff_s);

always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        // Initialize ALL registers
        for (i = 0; i < MAX_TREES; i = i + 1) begin
            tree_r[i] <= {COORD_BITS{1'b0}};
            tree_s[i] <= {COORD_BITS{1'b0}};
        end
        state <= IDLE;
        num_trees <= {TREE_IDX_BITS{1'b0}};
        done <= 1'b0;
        full <= 1'b0;
        distance <= {DIST_BITS{1'b0}};
        tree_index <= {TREE_IDX_BITS{1'b0}};
        current_min <= {DIST_BITS{1'b1}};
        query_r <= {COORD_BITS{1'b0}};
        query_s <= {COORD_BITS{1'b0}};
    end else begin
        done <= 1'b0; // Default done to 0
        full <= (num_trees >= MAX_TREES); // Combinational full signal

        case (state)
            IDLE: begin
                if (load_en && !full) begin
                    // Load new tree at current r,s position
                    tree_r[num_trees] <= r;
                    tree_s[num_trees] <= s;
                    num_trees <= num_trees + 1'b1;
                end else if (process && (num_trees != 0) && !full) begin
                    // Latch query position
                    query_r <= r;
                    query_s <= s;
                    tree_index <= 0;
                    current_min <= {DIST_BITS{1'b1}};
                    state <= COMPUTE;
                end
            end

            COMPUTE: begin
                // Check current computed distance
                if (current_dist < current_min) begin
                    current_min <= current_dist;
                end

                // Move to next tree or finish
                if (tree_index == (num_trees - 1)) begin
                    state <= UPDATE;
                end else begin
                    tree_index <= tree_index + 1'b1;
                end
            end

            UPDATE: begin
                // Update result and add query point
                distance <= current_min;
                if (!full) begin
                    tree_r[num_trees] <= query_r;
                    tree_s[num_trees] <= query_s;
                    num_trees <= num_trees + 1'b1;
                end
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule