module MentorAssignment(
    input clk,
    input rst_n,
    input start,
    input [2:0] a [0:7],
    output reg [2:0] b [0:7],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] CHECK_PERM = 4'd1;
    localparam [3:0] CHECK_CYCLE = 4'd2;
    localparam [3:0] COMPARE    = 4'd3;
    localparam [3:0] UPDATE_BEST = 4'd4;
    localparam [3:0] NEXT_PERM  = 4'd5;
    localparam [3:0] FINISH     = 4'd6;
    
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers for candidate permutation
    reg [2:0] candidate_b [0:7];
    reg [2:0] best_b [0:7];
    
    // Permutation generation: use lexicographic permutation algorithm
    reg [3:0] indices [0:7]; // permutation of {0,1,2,3,4,5,6,7}
    reg [2:0] values [0:7];  // actual values {1,2,3,4,5,6,7,8}
    
    // Control signals
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Helper variables
    integer i, j, k;
    reg [3:0] node;
    reg visited [0:7];
    reg found_cycle;
    reg [3:0] current_idx;
    reg [3:0] visited_count;
    
    // Comparison flags
    reg best_valid;
    reg new_is_better;
    reg difference_found;
    reg [2:0] best_val_at_diff;
    reg [2:0] new_val_at_diff;
    
    // Permutation generation helper
    reg [3:0] pivot;
    reg [3:0] swap_idx;
    reg [2:0] temp_val;
    reg [3:0] temp_idx;
    
    // Initialize best_b to invalid (all zeros)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                best_b[i] <= 3'd0;
            end
        end
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            best_valid <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                candidate_b[i] <= 3'd0;
                b[i] <= 3'd0;
                indices[i] <= i;
                values[i] <= i + 4'd1; // {1,2,3,4,5,6,7,8}
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    best_valid <= 1'b0;
                    // Initialize to identity permutation
                    for (i = 0; i < 8; i = i + 1) begin
                        indices[i] <= i;
                        values[i] <= i + 4'd1;
                    end
                    if (start) begin
                        state <= CHECK_PERM;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                CHECK_PERM: begin
                    // Build candidate_b from current permutation
                    for (i = 0; i < 8; i = i + 1) begin
                        candidate_b[i] <= values[indices[i]];
                    end
                    state <= CHECK_CYCLE;
                end
                
                CHECK_CYCLE: begin
                    // Check if this permutation forms a single cycle
                    // Initialize visited array
                    for (i = 0; i < 8; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    node <= 4'd0; // Start from node 0 (Gaggler 1)
                    visited_count <= 4'd0;
                    state <= COMPARE;
                end
                
                COMPARE: begin
                    // Visit nodes following the cycle
                    if (visited[node]) begin
                        // Back to start - check if all visited
                        if (visited_count == 4'd8) begin
                            found_cycle <= 1'b1;
                        end else begin
                            found_cycle <= 1'b0;
                        end
                        state <= UPDATE_BEST;
                    end else begin
                        visited[node] <= 1'b1;
                        visited_count <= visited_count + 4'd1;
                        // Next node: value - 1 (since nodes are 1-indexed, indices 0-indexed)
                        node <= candidate_b[node] - 4'd1;
                        state <= COMPARE;
                    end
                end
                
                UPDATE_BEST: begin
                    if (found_cycle) begin
                        if (!best_valid) begin
                            // First valid cycle found
                            best_valid <= 1'b1;
                            for (i = 0; i < 8; i = i + 1) begin
                                best_b[i] <= candidate_b[i];
                            end
                        end else begin
                            // Compare with current best using tie-breaking rule
                            new_is_better <= 1'b0;
                            difference_found <= 1'b0;
                            current_idx <= 4'd0;
                            // Comparison loop will happen in next state
                            state <= COMPARE_BEST;
                        end
                        if (!best_valid || !difference_found) begin
                            state <= NEXT_PERM;
                        end
                    end else begin
                        state <= NEXT_PERM;
                    end
                    if (!found_cycle || !best_valid) begin
                        state <= NEXT_PERM;
                    end
                end
                
                COMPARE_BEST: begin
                    // Lexicographic comparison
                    if (current_idx < 4'd8 && !difference_found) begin
                        if (candidate_b[current_idx] != best_b[current_idx]) begin
                            difference_found <= 1'b1;
                            // Determine if new is better
                            // Preference: a[i]==b[i] > smaller > larger
                            if (candidate_b[current_idx] == a[current_idx]) begin
                                // New keeps original mentor
                                new_is_better <= 1'b1;
                            end else if (best_b[current_idx] == a[current_idx]) begin
                                // Best keeps original mentor, new doesn't
                                new_is_better <= 1'b0;
                            end else if (candidate_b[current_idx] < best_b[current_idx]) begin
                                new_is_better <= 1'b1;
                            end else begin
                                new_is_better <= 1'b0;
                            end
                        end
                        current_idx <= current_idx + 4'd1;
                        state <= COMPARE_BEST;
                    end else begin
                        // Update best if new is better or if no difference found (equal)
                        if (!difference_found || new_is_better) begin
                            for (i = 0; i < 8; i = i + 1) begin
                                best_b[i] <= candidate_b[i];
                            end
                        end
                        state <= NEXT_PERM;
                    end
                end
                
                NEXT_PERM: begin
                    // Generate next lexicographic permutation
                    // Find the largest index i such that indices[i] < indices[i+1]
                    pivot <= 4'd7;
                    for (i = 0; i < 7; i = i + 1) begin
                        if (indices[i] < indices[i+1]) begin
                            pivot <= i;
                        end
                    end
                    
                    if (pivot == 4'd7 && indices[6] >= indices[7]) begin
                        // No more permutations
                        state <= FINISH;
                    end else begin
                        // Find rightmost element greater than pivot
                        swap_idx <= 4'd7;
                        for (i = 7; i > pivot; i = i + 1) begin
                            if (indices[i] > indices[pivot]) begin
                                swap_idx <= i;
                            end
                        end
                        // Swap pivot and swap_idx
                        state <= NEXT_PERM_SWAP;
                    end
                end
                
                NEXT_PERM_SWAP: begin
                    // Swap values
                    temp_idx <= indices[pivot];
                    indices[pivot] <= indices[swap_idx];
                    indices[swap_idx] <= temp_idx;
                    state <= NEXT_PERM_REVERSE;
                end
                
                NEXT_PERM_REVERSE: begin
                    // Reverse sequence from pivot+1 to end
                    // This is complex in Verilog, using a simple approach:
                    // We'll use a counter to track reversal progress
                    i <= 4'd0;
                    state <= NEXT_PERM_REVERSE_LOOP;
                end
                
                NEXT_PERM_REVERSE_LOOP: begin
                    if (i < 4'd4) begin
                        // Swap indices[pivot+1+i] with indices[7-i]
                        temp_idx <= indices[pivot + 1 + i];
                        indices[pivot + 1 + i] <= indices[7 - i];
                        indices[7 - i] <= temp_idx;
                        i <= i + 4'd1;
                        state <= NEXT_PERM_REVERSE_LOOP;
                    end else begin
                        state <= CHECK_PERM;
                    end
                end
                
                FINISH: begin
                    // Copy best_b to output b
                    for (i = 0; i < 8; i = i + 1) begin
                        b[i] <= best_b[i];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Cycle counter for timeout
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
            end
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
                done <= 1'b1;
            end
        end
    end
    
endmodule