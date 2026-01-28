module FibonacciTour (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [15:0] heights [0:15],
    input wire [255:0] adj,
    output reg [4:0] max_len,
    output reg done
);

    // Fibonacci constants (fib[0] to fib[15])
    localparam [15:0] FIB_0 = 16'd1;
    localparam [15:0] FIB_1 = 16'd1;
    localparam [15:0] FIB_2 = 16'd2;
    localparam [15:0] FIB_3 = 16'd3;
    localparam [15:0] FIB_4 = 16'd5;
    localparam [15:0] FIB_5 = 16'd8;
    localparam [15:0] FIB_6 = 16'd13;
    localparam [15:0] FIB_7 = 16'd21;
    localparam [15:0] FIB_8 = 16'd34;
    localparam [15:0] FIB_9 = 16'd55;
    localparam [15:0] FIB_10 = 16'd89;
    localparam [15:0] FIB_11 = 16'd144;
    localparam [15:0] FIB_12 = 16'd233;
    localparam [15:0] FIB_13 = 16'd377;
    localparam [15:0] FIB_14 = 16'd610;
    localparam [15:0] FIB_15 = 16'd987;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE_K = 3'd2;
    localparam [2:0] COMPUTE_I = 3'd3;
    localparam [2:0] COMPUTE_J = 3'd4;
    localparam [2:0] UPDATE = 3'd5;
    localparam [2:0] FIND_MAX = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] k_idx, next_k_idx;  // Fibonacci index (0-15)
    reg [3:0] i_idx, next_i_idx;  // Node i (0-15)
    reg [3:0] j_idx, next_j_idx;  // Node j (0-15)
    reg [4:0] max_len_reg;  // Internal max length register
    reg [7:0] cycle_count, next_cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // DP table: dp[k][i] = longest path length starting from node i with Fib index k
    // We only need 16x16 entries, each 5 bits (max length 16)
    reg [4:0] dp [0:15][0:15];  // dp[fib_index][node]
    integer dp_k, dp_i;  // For initialization loop

    // Helper signals
    wire [15:0] current_fib, next_fib;
    wire edge_exists, height_matches, next_height_matches;
    wire [4:0] current_len, new_len;
    wire [3:0] num_nodes_limit;

    // Get current and next Fibonacci number
    assign current_fib = (k_idx == 5'd0) ? FIB_0 :
                         (k_idx == 5'd1) ? FIB_1 :
                         (k_idx == 5'd2) ? FIB_2 :
                         (k_idx == 5'd3) ? FIB_3 :
                         (k_idx == 5'd4) ? FIB_4 :
                         (k_idx == 5'd5) ? FIB_5 :
                         (k_idx == 5'd6) ? FIB_6 :
                         (k_idx == 5'd7) ? FIB_7 :
                         (k_idx == 5'd8) ? FIB_8 :
                         (k_idx == 5'd9) ? FIB_9 :
                         (k_idx == 5'd10) ? FIB_10 :
                         (k_idx == 5'd11) ? FIB_11 :
                         (k_idx == 5'd12) ? FIB_12 :
                         (k_idx == 5'd13) ? FIB_13 :
                         (k_idx == 5'd14) ? FIB_14 : FIB_15;

    assign next_fib = (k_idx == 5'd0) ? FIB_1 :
                      (k_idx == 5'd1) ? FIB_2 :
                      (k_idx == 5'd2) ? FIB_3 :
                      (k_idx == 5'd3) ? FIB_4 :
                      (k_idx == 5'd4) ? FIB_5 :
                      (k_idx == 5'd5) ? FIB_6 :
                      (k_idx == 5'd6) ? FIB_7 :
                      (k_idx == 5'd7) ? FIB_8 :
                      (k_idx == 5'd8) ? FIB_9 :
                      (k_idx == 5'd9) ? FIB_10 :
                      (k_idx == 5'd10) ? FIB_11 :
                      (k_idx == 5'd11) ? FIB_12 :
                      (k_idx == 5'd12) ? FIB_13 :
                      (k_idx == 5'd13) ? FIB_14 :
                      (k_idx == 5'd14) ? FIB_15 : 16'd0;

    // Check if heights match current/next Fibonacci
    assign height_matches = (heights[i_idx] == current_fib);
    assign next_height_matches = (heights[j_idx] == next_fib);

    // Check adjacency (row-major: adj[i*n + j])
    wire [7:0] adj_idx;
    assign adj_idx = {i_idx[3:0], j_idx[3:0]};  // i*16 + j
    assign edge_exists = adj[adj_idx] && (i_idx != j_idx);  // Ignore self-loops

    // Get current dp value and compute new value
    assign current_len = dp[k_idx][i_idx];
    assign new_len = current_len + 5'd1;

    // Limit num_nodes to prevent out-of-bounds
    assign num_nodes_limit = (num_nodes > 4'd16) ? 4'd16 : num_nodes;

    // State transition logic
    always @(*) begin
        next_state = state;
        next_k_idx = k_idx;
        next_i_idx = i_idx;
        next_j_idx = j_idx;
        next_cycle_count = cycle_count;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    next_cycle_count = 8'd0;
                end
            end

            INIT: begin
                next_k_idx = 5'd0;
                next_i_idx = 4'd0;
                next_j_idx = 4'd0;
                next_state = COMPUTE_K;
            end

            COMPUTE_K: begin
                if (k_idx <= 5'd14 && cycle_count < MAX_CYCLES) begin
                    next_state = COMPUTE_I;
                    next_i_idx = 4'd0;
                end else begin
                    next_state = FIND_MAX;
                end
            end

            COMPUTE_I: begin
                if (i_idx < num_nodes_limit && cycle_count < MAX_CYCLES) begin
                    next_state = COMPUTE_J;
                    next_j_idx = 4'd0;
                end else begin
                    next_k_idx = k_idx + 5'd1;
                    next_state = COMPUTE_K;
                end
            end

            COMPUTE_J: begin
                if (j_idx < num_nodes_limit && cycle_count < MAX_CYCLES) begin
                    next_state = UPDATE;
                end else begin
                    next_i_idx = i_idx + 4'd1;
                    next_state = COMPUTE_I;
                end
            end

            UPDATE: begin
                next_cycle_count = cycle_count + 8'd1;
                next_j_idx = j_idx + 4'd1;
                next_state = COMPUTE_J;
            end

            FIND_MAX: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic and DP update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            k_idx <= 5'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            max_len <= 5'd0;
            max_len_reg <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize DP table to 0
            for (dp_k = 0; dp_k < 16; dp_k = dp_k + 1) begin
                for (dp_i = 0; dp_i < 16; dp_i = dp_i + 1) begin
                    dp[dp_k][dp_i] <= 5'd0;
                end
            end
        end else begin
            state <= next_state;
            k_idx <= next_k_idx;
            i_idx <= next_i_idx;
            j_idx <= next_j_idx;
            cycle_count <= next_cycle_count;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // Keep previous max_len
                end

                INIT: begin
                    // Reset done flag
                    done <= 1'b0;
                    max_len_reg <= 5'd0;
                    // DP table already initialized in reset block
                end

                COMPUTE_J: begin
                    // Check condition for update
                    if (edge_exists && next_height_matches) begin
                        // Update dp[k+1][j] = max(dp[k+1][j], dp[k][i] + 1)
                        // Also handle starting condition: if dp[k][i] == 0 and heights[i] == fib[k], start new path
                        if (current_len > 5'd0 && new_len > dp[k_idx + 5'd1][j_idx]) begin
                            dp[k_idx + 5'd1][j_idx] <= new_len;
                        end else if (current_len == 5'd0 && height_matches) begin
                            // Starting a new path from i
                            if (5'd1 > dp[k_idx + 5'd1][j_idx]) begin
                                dp[k_idx + 5'd1][j_idx] <= 5'd1;
                            end
                        end
                    end
                    // Also handle self-loop as starting condition (length 1)
                    if (i_idx == j_idx && height_matches && current_len == 5'd0) begin
                        // Single node path of length 1 (if it matches fib[k])
                        // This is handled when looking for max_len
                    end
                end

                UPDATE: begin
                    // Combined logic with COMPUTE_J
                    // The update happens in COMPUTE_J, this state just increments counters
                    // (Already handled in COMPUTE_J)
                end

                FIND_MAX: begin
                    // Find maximum over all dp[k][i] and starting nodes
                    // Check all dp entries and also consider single nodes
                    for (dp_k = 0; dp_k < 16; dp_k = dp_k + 1) begin
                        for (dp_i = 0; dp_i < 16; dp_i = dp_i + 1) begin
                            if (dp[dp_k][dp_i] > max_len_reg) begin
                                max_len_reg <= dp[dp_k][dp_i];
                            end
                            // Check single node paths
                            if (dp_k < 16 && dp_i < num_nodes_limit) begin
                                // Check if heights[dp_i] matches fib[dp_k]
                                if ((dp_k == 0 && heights[dp_i] == FIB_0) ||
                                    (dp_k == 1 && heights[dp_i] == FIB_1) ||
                                    (dp_k == 2 && heights[dp_i] == FIB_2) ||
                                    (dp_k == 3 && heights[dp_i] == FIB_3) ||
                                    (dp_k == 4 && heights[dp_i] == FIB_4) ||
                                    (dp_k == 5 && heights[dp_i] == FIB_5) ||
                                    (dp_k == 6 && heights[dp_i] == FIB_6) ||
                                    (dp_k == 7 && heights[dp_i] == FIB_7) ||
                                    (dp_k == 8 && heights[dp_i] == FIB_8) ||
                                    (dp_k == 9 && heights[dp_i] == FIB_9) ||
                                    (dp_k == 10 && heights[dp_i] == FIB_10) ||
                                    (dp_k == 11 && heights[dp_i] == FIB_11) ||
                                    (dp_k == 12 && heights[dp_i] == FIB_12) ||
                                    (dp_k == 13 && heights[dp_i] == FIB_13) ||
                                    (dp_k == 14 && heights[dp_i] == FIB_14) ||
                                    (dp_k == 15 && heights[dp_i] == FIB_15)) begin
                                    if (5'd1 > max_len_reg) begin
                                        max_len_reg <= 5'd1;
                                    end
                                end
                            end
                        end
                    end
                end

                FINISH: begin
                    max_len <= max_len_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule