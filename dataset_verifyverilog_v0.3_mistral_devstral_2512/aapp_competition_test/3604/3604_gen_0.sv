module max_clique #(
    parameter N = 4,
    parameter DATA_WIDTH = 16,
    parameter MASK_WIDTH = N,
    parameter SIZE_WIDTH = 3
)(
    input clk,
    input rst_n,
    input start,
    input [DATA_WIDTH-1:0] d,
    input [DATA_WIDTH-1:0] x0, x1, x2, x3,
    input [DATA_WIDTH-1:0] y0, y1, y2, y3,
    input [2:0] num_sensors,
    output reg [SIZE_WIDTH-1:0] max_size,
    output reg [MASK_WIDTH-1:0] subset_mask,
    output reg done
);

// Internal registers for coordinates
reg [DATA_WIDTH-1:0] x [0:N-1];
reg [DATA_WIDTH-1:0] y [0:N-1];

// Adjacency matrix
reg adj [0:N-1][0:N-1];

// State machine states
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE_ADJ = 3'd1;
localparam [2:0] INIT_ENUM = 3'd2;
localparam [2:0] CHECK_SUBSET = 3'd3;
localparam [2:0] DONE = 3'd4;

reg [2:0] state, next_state;

// Registers for enumeration
reg [MASK_WIDTH-1:0] mask, next_mask;
reg [SIZE_WIDTH-1:0] best_size, next_best_size;
reg [MASK_WIDTH-1:0] best_mask, next_best_mask;
reg [2:0] pair_index, next_pair_index;
reg clique_ok, next_clique_ok;
reg [DATA_WIDTH*2-1:0] d_sq, next_d_sq;

// Pair index decoder: pair_index -> (i,j)
wire [1:0] i_idx, j_idx;
assign i_idx = (pair_index == 3'd0) ? 2'd0 :
               (pair_index == 3'd1) ? 2'd0 :
               (pair_index == 3'd2) ? 2'd0 :
               (pair_index == 3'd3) ? 2'd1 :
               (pair_index == 3'd4) ? 2'd1 : 2'd2;
assign j_idx = (pair_index == 3'd0) ? 2'd1 :
               (pair_index == 3'd1) ? 2'd2 :
               (pair_index == 3'd2) ? 2'd3 :
               (pair_index == 3'd3) ? 2'd2 :
               (pair_index == 3'd4) ? 2'd3 : 2'd3;

// Function to compute popcount
function [SIZE_WIDTH-1:0] popcount;
    input [MASK_WIDTH-1:0] m;
    integer k;
    begin
        popcount = 0;
        for (k = 0; k < N; k = k + 1) begin
            if (m[k]) popcount = popcount + 1;
        end
    end
endfunction

// Compute squared distance and compare to d_sq
wire [DATA_WIDTH-1:0] dx = (x[i_idx] > x[j_idx]) ? (x[i_idx] - x[j_idx]) : (x[j_idx] - x[i_idx]);
wire [DATA_WIDTH-1:0] dy = (y[i_idx] > y[j_idx]) ? (y[i_idx] - y[j_idx]) : (y[j_idx] - y[i_idx]);
wire [DATA_WIDTH*2-1:0] dist_sq = dx * dx + dy * dy;

// Combinational next state and output logic
always @(*) begin
    // Default assignments to avoid latches
    next_state = state;
    next_mask = mask;
    next_best_size = best_size;
    next_best_mask = best_mask;
    next_pair_index = pair_index;
    next_clique_ok = clique_ok;
    next_d_sq = d_sq;

    case (state)
        IDLE: begin
            if (start) begin
                next_d_sq = d * d;
                next_pair_index = 0;
                next_state = COMPUTE_ADJ;
            end
        end

        COMPUTE_ADJ: begin
            // Update adjacency for current pair
            if (i_idx < num_sensors && j_idx < num_sensors) begin
                if (dist_sq <= d_sq) begin
                    adj[i_idx][j_idx] = 1;
                    adj[j_idx][i_idx] = 1;
                end else begin
                    adj[i_idx][j_idx] = 0;
                    adj[j_idx][i_idx] = 0;
                end
            end else begin
                adj[i_idx][j_idx] = 0;
                adj[j_idx][i_idx] = 0;
            end

            if (pair_index < 5) begin
                next_pair_index = pair_index + 1;
            end else begin
                next_pair_index = 0;
                next_state = INIT_ENUM;
            end
        end

        INIT_ENUM: begin
            next_mask = 0;
            next_best_size = 0;
            next_best_mask = 0;
            next_pair_index = 0;
            next_clique_ok = 1;
            next_state = CHECK_SUBSET;
        end

        CHECK_SUBSET: begin
            if (pair_index < 6) begin
                // Check current pair
                if (mask[i_idx] && mask[j_idx]) begin
                    if (!adj[i_idx][j_idx]) begin
                        next_clique_ok = 0;
                    end
                end
                next_pair_index = pair_index + 1;
            end else begin
                // Finished all pairs for this mask
                if (clique_ok) begin
                    if (popcount(mask) > best_size) begin
                        next_best_size = popcount(mask);
                        next_best_mask = mask;
                    end
                end
                // Next mask
                if (mask < (1 << N) - 1) begin
                    next_mask = mask + 1;
                    next_pair_index = 0;
                    next_clique_ok = 1;
                end else begin
                    next_state = DONE;
                end
            end
        end

        DONE: begin
            // Stay in done state
            next_state = DONE;
        end

        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        mask <= 0;
        best_size <= 0;
        best_mask <= 0;
        pair_index <= 0;
        clique_ok <= 1;
        d_sq <= 0;
        done <= 0;
        max_size <= 0;
        subset_mask <= 0;
        // Initialize coordinates and adj
        integer i, j;
        for (i = 0; i < N; i = i + 1) begin
            x[i] <= 0;
            y[i] <= 0;
            for (j = 0; j < N; j = j + 1) begin
                adj[i][j] <= 0;
            end
        end
    end else begin
        state <= next_state;
        mask <= next_mask;
        best_size <= next_best_size;
        best_mask <= next_best_mask;
        pair_index <= next_pair_index;
        clique_ok <= next_clique_ok;
        d_sq <= next_d_sq;
        done <= (state == DONE) ? 1 : 0;
        if (state == DONE) begin
            max_size <= best_size;
            subset_mask <= best_mask;
        end
        // Load coordinates when start is asserted in IDLE
        if (start && state == IDLE) begin
            x[0] <= x0;
            x[1] <= x1;
            x[2] <= x2;
            x[3] <= x3;
            y[0] <= y0;
            y[1] <= y1;
            y[2] <= y2;
            y[3] <= y3;
        end
    end
end

endmodule