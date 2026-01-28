module KthRootPermutation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] k,
    input wire [3:0] a [0:15],
    output reg [3:0] result [0:15],
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] FIND_CYCLE = 3'd2;
    localparam [2:0] PROCESS_CYCLE = 3'd3;
    localparam [2:0] CALC_ROOT = 3'd4;
    localparam [2:0] FINISH    = 3'd5;
    localparam [2:0] ERROR     = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] result_reg [0:15];
    reg [15:0] visited;
    reg [3:0] cycle_start;
    reg [3:0] cycle_length;
    reg [3:0] cycle_nodes [0:15];
    reg [3:0] cycle_idx;
    reg [7:0] k_shift;
    reg [3:0] i, j;
    reg [3:0] n_reg;
    reg [7:0] k_reg;
    reg valid_reg;
    reg done_reg;
    reg [15:0] visited_count;
    reg [3:0] shift_val;
    reg [3:0] src_idx;
    reg [3:0] dest_idx;
    reg [3:0] temp_idx;
    reg [3:0] cycle_node;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                result[idx] <= 4'd0;
                result_reg[idx] <= 4'd0;
                cycle_nodes[idx] <= 4'd0;
            end
            visited <= 16'd0;
            cycle_start <= 4'd0;
            cycle_length <= 4'd0;
            cycle_idx <= 4'd0;
            k_shift <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            n_reg <= 4'd0;
            k_reg <= 8'd0;
            valid_reg <= 1'b0;
            done_reg <= 1'b0;
            visited_count <= 16'd0;
            shift_val <= 4'd0;
            src_idx <= 4'd0;
            dest_idx <= 4'd0;
            temp_idx <= 4'd0;
            cycle_node <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        k_reg <= k;
                        // Validate inputs
                        if (n > 4'd16 || n < 4'd1 || k < 8'd1) begin
                            valid_reg <= 1'b0;
                            done_reg <= 1'b1;
                        end else begin
                            done_reg <= 1'b0;
                            valid_reg <= 1'b0;
                        end
                    end
                end
                INIT: begin
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        result_reg[idx] <= 4'd0;
                        cycle_nodes[idx] <= 4'd0;
                    end
                    visited <= 16'd0;
                    visited_count <= 16'd0;
                    i <= 4'd0;
                end
                FIND_CYCLE: begin
                    if (visited_count >= n_reg) begin
                        // All nodes processed
                    end else begin
                        // Find next unvisited node
                        if (i >= n_reg) begin
                            i <= 4'd0;
                        end else if (visited[i]) begin
                            i <= i + 4'd1;
                        end else begin
                            // Start new cycle
                            cycle_start <= i;
                            cycle_idx <= 4'd0;
                            cycle_nodes[0] <= i;
                            cycle_length <= 4'd1;
                            visited[i] <= 1'b1;
                            visited_count <= visited_count + 16'd1;
                            temp_idx <= i;
                        end
                    end
                end
                PROCESS_CYCLE: begin
                    // Follow cycle to find length and nodes
                    if (a[temp_idx] > n_reg || a[temp_idx] < 4'd1) begin
                        // Invalid permutation (out of range)
                        valid_reg <= 1'b0;
                        done_reg <= 1'b1;
                    end else if (a[temp_idx] == cycle_start + 4'd1) begin
                        // Cycle completed
                        // Check for consistency
                    end else begin
                        // Continue following cycle
                        if (a[temp_idx] == cycle_start + 4'd1) begin
                            // Already handled, should not happen
                        end else begin
                            temp_idx <= a[temp_idx] - 4'd1;
                            if (visited[a[temp_idx] - 4'd1]) begin
                                // Already visited - not a simple cycle or error
                                valid_reg <= 1'b0;
                                done_reg <= 1'b1;
                            end else begin
                                visited[a[temp_idx] - 4'd1] <= 1'b1;
                                visited_count <= visited_count + 16'd1;
                                cycle_length <= cycle_length + 4'd1;
                                cycle_nodes[cycle_length] <= a[temp_idx] - 4'd1;
                                // Check for cycle completion
                                if (a[a[temp_idx] - 4'd1] == cycle_start + 4'd1) begin
                                    // Cycle completed
                                end
                            end
                        end
                    end
                end
                CALC_ROOT: begin
                    // Calculate K-th root for current cycle
                    // shift_val = K mod L
                    if (cycle_length > 4'd0) begin
                        shift_val <= k_reg % cycle_length;
                        j <= 4'd0;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                    valid <= valid_reg;
                    // Copy result_reg to output
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        result[idx] <= result_reg[idx];
                    end
                end
                ERROR: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (n > 4'd16 || n < 4'd1 || k < 8'd1) begin
                        next_state = ERROR;
                    end else begin
                        next_state = INIT;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            INIT: begin
                next_state = FIND_CYCLE;
            end
            FIND_CYCLE: begin
                if (visited_count >= n_reg) begin
                    next_state = FINISH;
                end else if (i >= n_reg) begin
                    next_state = ERROR; // Should not happen
                end else if (visited[i]) begin
                    next_state = FIND_CYCLE;
                end else begin
                    next_state = PROCESS_CYCLE;
                end
            end
            PROCESS_CYCLE: begin
                if (a[temp_idx] > n_reg || a[temp_idx] < 4'd1) begin
                    next_state = ERROR;
                end else if (a[temp_idx] == cycle_start + 4'd1) begin
                    // Cycle complete
                    if (cycle_length == 4'd0) begin
                        next_state = ERROR;
                    end else begin
                        next_state = CALC_ROOT;
                    end
                end else begin
                    if (visited[a[temp_idx] - 4'd1]) begin
                        next_state = ERROR;
                    end else begin
                        next_state = PROCESS_CYCLE;
                    end
                end
            end
            CALC_ROOT: begin
                if (j < cycle_length) begin
                    next_state = CALC_ROOT;
                end else begin
                    next_state = FIND_CYCLE;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            ERROR: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == CALC_ROOT) begin
                if (j < cycle_length) begin
                    // Calculate source index for each destination
                    // For K-th root: shift backwards by K mod L
                    // source = cycle_nodes[(j + (L - shift_val)) % L]
                    reg [3:0] idx_in_cycle;
                    reg [3:0] src_node;
                    reg [3:0] dest_node;
                    
                    // Calculate index in cycle
                    if (j >= shift_val) begin
                        idx_in_cycle = j - shift_val;
                    end else begin
                        idx_in_cycle = cycle_length - shift_val + j;
                    end
                    
                    src_node = cycle_nodes[idx_in_cycle];
                    dest_node = cycle_nodes[j];
                    
                    // The node src_node goes to dest_node
                    // result[dest_node] should be src_node + 1 (1-indexed)
                    result_reg[dest_node] <= src_node + 4'd1;
                    
                    j <= j + 4'd1;
                    
                    valid_reg <= 1'b1; // Mark as valid if we get here
                end
            end
        end
    end

endmodule