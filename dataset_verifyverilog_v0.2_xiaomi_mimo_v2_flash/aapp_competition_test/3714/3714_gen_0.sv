module crush_game (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] crush [15:0],
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK_CYCLES = 3'b010;
    localparam COMPUTE_LCM = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [3:0] i, j; // counters for nodes and steps
    reg [3:0] visited_node;
    reg [31:0] cycle_len_acc;
    reg [31:0] current_len;
    reg [31:0] lcm_val;
    reg [31:0] gcd_val;
    reg [31:0] a_reg, b_reg;
    reg [31:0] temp_a, temp_b;
    reg error_flag;
    reg [3:0] path_len;
    reg [3:0] cur_node;
    reg [15:0] visited_nodes_mask;
    reg [3:0] start_node;
    reg [15:0] visited_mark;
    reg [31:0] gcd_a, gcd_b;
    reg gcd_done;
    reg [31:0] adjusted_len;

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // State transition and operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
            error_flag <= 0;
            lcm_val <= 1;
            gcd_val <= 0;
            a_reg <= 0;
            b_reg <= 0;
            visited_nodes_mask <= 0;
            start_node <= 0;
            path_len <= 0;
            cur_node <= 0;
            visited_mark <= 0;
            gcd_a <= 0;
            gcd_b <= 0;
            gcd_done <= 0;
            adjusted_len <= 0;
            visited_node <= 0;
            cycle_len_acc <= 0;
            current_len <= 0;
            temp_a <= 0;
            temp_b <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error_flag <= 0;
                    lcm_val <= 1;
                    i <= 0;
                    if (start) begin
                        // Validate input
                        if (n > 16) begin
                            // If n > 16, we set error immediately in IDLE or next state
                            // But requirement says validate on start. 
                            // We can handle error in INIT state or stay IDLE.
                            // Let's transition to INIT and check there.
                            next_state <= INIT;
                        end else begin
                            next_state <= INIT;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Reset counters for cycle checking
                    i <= 0;
                    j <= 0;
                    visited_nodes_mask <= 0;
                    error_flag <= 0;
                    if (n > 16) begin
                        // Invalid input
                        error_flag <= 1;
                        result <= 32'hFFFFFFFF; // -1
                        done <= 1;
                        next_state <= DONE;
                    end else begin
                        if (n == 0) begin
                            // No nodes, trivial 1? Or invalid. Let's say 1 or -1. 
                            // Problem says t>=1. For 0 nodes, LCM of empty set is usually 1.
                            result <= 1;
                            done <= 1;
                            next_state <= DONE;
                        end else begin
                            next_state <= CHECK_CYCLES;
                            start_node <= 0;
                            visited_mark <= 0;
                            path_len <= 0;
                            cur_node <= 0;
                        end
                    end
                end

                CHECK_CYCLES: begin
                    // Iterates through each node to verify it belongs to a cycle
                    // We track path from i. If we hit a node already visited in current path, check if it's i.
                    // If cycle detected, check length.
                    // If path length > n, error.
                    
                    if (start_node < n) begin
                        if (path_len == 0) begin
                            // Start new path trace from start_node
                            cur_node <= start_node;
                            visited_mark <= (1 << start_node);
                            path_len <= 1;
                        end else begin
                            // Trace next step
                            if (path_len > n) begin
                                // Path too long, no self cycle
                                error_flag <= 1;
                                result <= 32'hFFFFFFFF;
                                done <= 1;
                                next_state <= DONE;
                            end else begin
                                // Check if current crush is start_node (completed cycle)
                                if (crush[cur_node] == start_node) begin
                                    // Cycle found
                                    current_len <= path_len; // Store cycle length
                                    // Adjust length: if even, divide by 2
                                    adjusted_len <= (path_len[0] == 1'b0) ? (path_len >> 1) : path_len;
                                    next_state <= COMPUTE_LCM;
                                    // Initialize GCD inputs
                                    gcd_a <= lcm_val;
                                    gcd_b <= (path_len[0] == 1'b0) ? (path_len >> 1) : path_len;
                                    gcd_done <= 0;
                                end else begin
                                    // Check if crush[cur_node] is already visited in this path (loop not to start)
                                    if (visited_mark[crush[cur_node]]) begin
                                        // Loop detected but not returning to start_node
                                        error_flag <= 1;
                                        result <= 32'hFFFFFFFF;
                                        done <= 1;
                                        next_state <= DONE;
                                    end else begin
                                        // Continue path
                                        cur_node <= crush[cur_node];
                                        visited_mark[crush[cur_node]] <= 1'b1;
                                        path_len <= path_len + 1;
                                    end
                                end
                            end
                        end
                    end else begin
                        // Done checking all nodes
                        if (error_flag) begin
                            result <= 32'hFFFFFFFF;
                            done <= 1;
                            next_state <= DONE;
                        end else begin
                            result <= lcm_val;
                            done <= 1;
                            next_state <= DONE;
                        end
                    end
                end

                COMPUTE_LCM: begin
                    // Compute GCD of lcm_val and adjusted_len (stored in gcd_a and gcd_b)
                    // Euclidean algorithm
                    if (!gcd_done) begin
                        if (gcd_b == 0) begin
                            // GCD found in gcd_a
                            gcd_val <= gcd_a;
                            gcd_done <= 1;
                            // LCM = (A * B) / GCD
                            // We do: lcm_val = (lcm_val * adjusted_len) / gcd_val
                            // Since adjusted_len is small (<=16), we can just store it.
                            // But we need to be careful with overflow. Result is 32-bit.
                            // Use temp registers for multiplication
                            temp_a <= lcm_val;
                            temp_b <= (current_len[0] == 1'b0) ? (current_len >> 1) : current_len;
                            gcd_val <= gcd_a; // gcd_a holds the GCD result
                        end else begin
                            temp_a <= gcd_b;
                            temp_b <= gcd_a % gcd_b;
                            // Update inputs for next iteration
                            gcd_a <= gcd_b;
                            gcd_b <= gcd_a % gcd_b;
                        end
                    end else begin
                        // Calculate LCM = (lcm_val * adjusted_len) / gcd_val
                        // Since adjusted_len is small (<=16), the product fits in 64-bit, but we stick to 32-bit logic
                        // We know adjusted_len <= 16.
                        if (temp_a * temp_b / gcd_val < 32'h100000000) begin
                            lcm_val <= (temp_a * temp_b) / gcd_val;
                        end else begin
                            // Should not happen given constraints, but safe fallback
                            lcm_val <= 32'hFFFFFFFF;
                        end
                        // Move to next node in CHECK_CYCLES
                        start_node <= start_node + 1;
                        path_len <= 0;
                        next_state <= CHECK_CYCLES;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (start) begin
                        // Restart if start is pressed again
                        next_state <= INIT;
                        done <= 0;
                    end else begin
                        next_state <= DONE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule
