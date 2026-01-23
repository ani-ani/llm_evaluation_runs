module max_clique_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [31:0] d,
    input [7:0][31:0] x_coords,
    input [7:0][31:0] y_coords,
    output reg [2:0] size,
    output reg [2:0] sensor_indices [7:0],
    output reg done
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        COMPUTE_ADJ,
        ENUMERATE_SUBSETS,
        CHECK_CLIQUE,
        UPDATE_BEST,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Adjacency matrix (8x8)
    reg [7:0][7:0] adj_matrix;

    // Subset enumeration variables
    reg [7:0] subset;
    reg [7:0] best_subset;
    reg [2:0] best_size;

    // Clique checking variables
    reg [7:0] i, j;
    reg [7:0] subset_size;
    reg is_clique;

    // Distance calculation variables
    reg [63:0] dx, dy, dist_sq;
    reg [31:0] d_sq;

    // Initialize outputs
    initial begin
        size = 0;
        for (int k = 0; k < 8; k++) sensor_indices[k] = 0;
        done = 0;
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            size <= 0;
            for (int k = 0; k < 8; k++) sensor_indices[k] <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_ADJ;
                    // Initialize adjacency matrix
                    for (int k = 0; k < 8; k++) begin
                        for (int l = 0; l < 8; l++) begin
                            adj_matrix[k][l] = 0;
                        end
                    end
                    // Pre-compute d_sq
                    d_sq = d * d;
                    i = 0;
                    j = 0;
                end
            end

            COMPUTE_ADJ: begin
                // Compute adjacency matrix
                if (i < n && j < n) begin
                    if (i != j) begin
                        // Calculate dx = x_coords[i] - x_coords[j]
                        dx = $signed({x_coords[i], 32'h0}) - $signed({x_coords[j], 32'h0});
                        // Calculate dy = y_coords[i] - y_coords[j]
                        dy = $signed({y_coords[i], 32'h0}) - $signed({y_coords[j], 32'h0});
                        // Calculate dist_sq = dx^2 + dy^2
                        dist_sq = (dx * dx) + (dy * dy);
                        // Compare with d_sq (upper 32 bits)
                        if (dist_sq[63:32] <= d_sq) begin
                            adj_matrix[i][j] = 1;
                            adj_matrix[j][i] = 1;
                        end else begin
                            adj_matrix[i][j] = 0;
                            adj_matrix[j][i] = 0;
                        end
                    end
                    // Increment j
                    j = j + 1;
                    if (j >= n) begin
                        j = 0;
                        i = i + 1;
                    end
                end else begin
                    // Move to next state
                    next_state = ENUMERATE_SUBSETS;
                    subset = 0;
                    best_size = 0;
                    best_subset = 0;
                end
            end

            ENUMERATE_SUBSETS: begin
                // Enumerate all subsets
                if (subset < (1 << n)) begin
                    // Count number of bits set in subset
                    subset_size = 0;
                    for (int k = 0; k < 8; k++) begin
                        if (subset[k]) subset_size = subset_size + 1;
                    end
                    
                    // Check if subset is a clique
                    if (subset_size > 1) begin
                        next_state = CHECK_CLIQUE;
                        is_clique = 1;
                        i = 0;
                        j = 0;
                    end else begin
                        // Single node is always a clique
                        if (subset_size > best_size) begin
                            best_size = subset_size;
                            best_subset = subset;
                        end
                        subset = subset + 1;
                    end
                end else begin
                    next_state = DONE;
                end
            end

            CHECK_CLIQUE: begin
                // Check if subset is a clique
                if (is_clique && i < n && j < n) begin
                    if (subset[i] && subset[j] && i != j) begin
                        if (!adj_matrix[i][j]) begin
                            is_clique = 0;
                        end
                    end
                    j = j + 1;
                    if (j >= n) begin
                        j = 0;
                        i = i + 1;
                    end
                end else begin
                    if (is_clique && subset_size > best_size) begin
                        next_state = UPDATE_BEST;
                    end else begin
                        next_state = ENUMERATE_SUBSETS;
                        subset = subset + 1;
                    end
                end
            end

            UPDATE_BEST: begin
                // Update best subset
                best_size = subset_size;
                best_subset = subset;
                next_state = ENUMERATE_SUBSETS;
                subset = subset + 1;
            end

            DONE: begin
                // Output results
                size = best_size;
                for (int k = 0; k < 8; k++) begin
                    if (k < best_size) begin
                        // Find the k-th set bit in best_subset
                        for (int l = 0; l < 8; l++) begin
                            if (best_subset[l]) begin
                                if (k == 0) begin
                                    sensor_indices[k] = l + 1;
                                    break;
                                end
                                k = k - 1;
                            end
                        end
                    end else begin
                        sensor_indices[k] = 0;
                    end
                end
                done = 1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule