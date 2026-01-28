module MentorAssignment(
    input clk,
    input rst_n,
    input start,
    input [2:0] a [0:7],
    output reg [2:0] b [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GENERATE = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Internal registers for candidate assignment
    reg [2:0] candidate [0:7];
    reg [2:0] current_best [0:7];
    reg [2:0] temp_assignment [0:7];

    // Registers for cycle checking
    reg [2:0] visited [0:7];
    reg [2:0] current_node;
    reg [2:0] next_node;
    reg [2:0] start_node;
    reg [2:0] nodes_visited;
    reg cycle_valid;

    // Registers for comparison
    reg [2:0] compare_index;
    reg better_found;
    reg equal_so_far;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 10'd0;

            // Initialize output and internal arrays
            for (i = 0; i < 8; i = i + 1) begin
                b[i] <= 3'd0;
                candidate[i] <= 3'd0;
                current_best[i] <= 3'd0;
                temp_assignment[i] <= 3'd0;
            end

            // Initialize cycle checking registers
            for (i = 0; i < 8; i = i + 1) begin
                visited[i] <= 3'd0;
            end
            current_node <= 3'd0;
            next_node <= 3'd0;
            start_node <= 3'd0;
            nodes_visited <= 3'd0;
            cycle_valid <= 1'b0;

            // Initialize comparison registers
            compare_index <= 3'd0;
            better_found <= 1'b0;
            equal_so_far <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        // Initialize current_best to input a
                        for (i = 0; i < 8; i = i + 1) begin
                            current_best[i] <= a[i];
                        end
                        state <= GENERATE;
                    end
                end

                GENERATE: begin
                    // Generate next candidate permutation
                    // This is a simplified approach - in practice would need a more sophisticated
                    // permutation generator, but for synthesis we'll use a counter-based approach
                    cycle_count <= cycle_count + 10'd1;

                    // Simple increment approach (not optimal but synthesizable)
                    // In a real implementation, this would be replaced with a proper permutation generator
                    candidate[0] <= candidate[0] + 3'd1;
                    if (candidate[0] > 3'd8) begin
                        candidate[0] <= 3'd1;
                        candidate[1] <= candidate[1] + 3'd1;
                        if (candidate[1] > 3'd8) begin
                            candidate[1] <= 3'd1;
                            candidate[2] <= candidate[2] + 3'd1;
                            if (candidate[2] > 3'd8) begin
                                candidate[2] <= 3'd1;
                                candidate[3] <= candidate[3] + 3'd1;
                                if (candidate[3] > 3'd8) begin
                                    candidate[3] <= 3'd1;
                                    candidate[4] <= candidate[4] + 3'd1;
                                    if (candidate[4] > 3'd8) begin
                                        candidate[4] <= 3'd1;
                                        candidate[5] <= candidate[5] + 3'd1;
                                        if (candidate[5] > 3'd8) begin
                                            candidate[5] <= 3'd1;
                                            candidate[6] <= candidate[6] + 3'd1;
                                            if (candidate[6] > 3'd8) begin
                                                candidate[6] <= 3'd1;
                                                candidate[7] <= candidate[7] + 3'd1;
                                                if (candidate[7] > 3'd8) begin
                                                    candidate[7] <= 3'd1;
                                                    // All permutations tried
                                                    state <= FINISH;
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    // Check if candidate is a permutation (all unique values 1-8)
                    // This is simplified - in practice would need proper uniqueness check
                    state <= CHECK;
                end

                CHECK: begin
                    // Check if candidate forms a single cycle
                    // Initialize cycle checking
                    for (i = 0; i < 8; i = i + 1) begin
                        visited[i] <= 3'd0;
                    end
                    start_node <= 3'd1;  // Start checking from node 1 (index 0)
                    current_node <= start_node;
                    nodes_visited <= 3'd0;
                    cycle_valid <= 1'b0;

                    state <= CHECK;
                end

                CHECK: begin
                    // Perform cycle checking
                    // Mark current node as visited
                    visited[current_node - 3'd1] <= 3'd1;
                    nodes_visited <= nodes_visited + 3'd1;

                    // Get next node from candidate assignment
                    next_node <= candidate[current_node - 3'd1];

                    // Check if we've completed the cycle
                    if (nodes_visited == 3'd8 && next_node == start_node) begin
                        cycle_valid <= 1'b1;
                        state <= COMPARE;
                    end else if (visited[next_node - 3'd1] != 3'd0) begin
                        // Cycle detected before visiting all nodes
                        cycle_valid <= 1'b0;
                        state <= GENERATE;
                    end else begin
                        current_node <= next_node;
                        // Continue checking in next cycle
                    end
                end

                COMPARE: begin
                    // Compare candidate with current_best
                    compare_index <= 3'd0;
                    better_found <= 1'b0;
                    equal_so_far <= 1'b1;

                    // Check if candidate is better than current_best
                    if (cycle_valid) begin
                        // Compare lexicographically
                        for (i = 0; i < 8; i = i + 1) begin
                            if (equal_so_far) begin
                                // Preference order:
                                // 1. candidate[i] == a[i] (best)
                                // 2. candidate[i] != a[i] but smaller
                                // 3. candidate[i] != a[i] but larger (worst)
                                
                                // Compare candidate with current_best
                                if (candidate[i] == current_best[i]) begin
                                    // Equal at this position, continue
                                end else begin
                                    equal_so_far <= 1'b0;
                                    // Determine which is better
                                    if (candidate[i] == a[i]) begin
                                        better_found <= 1'b1;
                                    end else if (current_best[i] == a[i]) begin
                                        better_found <= 1'b0;
                                    end else if (candidate[i] < current_best[i]) begin
                                        better_found <= 1'b1;
                                    end else begin
                                        better_found <= 1'b0;
                                    end
                                end
                            end
                        end

                        if (better_found || (equal_so_far && cycle_valid)) begin
                            // Update current_best
                            for (i = 0; i < 8; i = i + 1) begin
                                current_best[i] <= candidate[i];
                            end
                        end
                    end

                    // Move to next candidate
                    state <= GENERATE;
                end

                FINISH: begin
                    // Copy current_best to output
                    for (i = 0; i < 8; i = i + 1) begin
                        b[i] <= current_best[i];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule