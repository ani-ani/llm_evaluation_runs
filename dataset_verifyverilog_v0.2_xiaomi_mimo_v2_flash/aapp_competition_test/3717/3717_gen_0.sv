module find_common_point (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] x1_in, y1_in, x2_in, y2_in,
    input wire [2:0] n,
    output reg [7:0] result_x,
    output reg [7:0] result_y,
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_RECTS = 3'b001;
    localparam COMPUTE_PREFIX = 3'b010;
    localparam COMPUTE_SUFFIX = 3'b011;
    localparam CHECK_EXCLUSION = 3'b100;
    localparam DONE = 3'b101;

    // Registers for state and control
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [2:0] count; // General counter
    reg [2:0] n_reg; // Store n value
    
    // Memory for rectangles (8 entries, 4 bytes each)
    // We treat them as 32-bit vectors for easier indexing: {x2, y2, x1, y1}
    reg [31:0] rects [0:7];
    
    // Prefix and suffix arrays: {max_x1, max_y1, min_x2, min_y2}
    reg [31:0] prefix [0:7];
    reg [31:0] suffix [0:7];
    
    // Temporary registers for computation
    reg [7:0] temp_max_x1;
    reg [7:0] temp_max_y1;
    reg [7:0] temp_min_x2;
    reg [7:0] temp_min_y2;
    
    // Helper wires for signed comparison
    wire signed [7:0] s_x1_a, s_x1_b;
    wire signed [7:0] s_y1_a, s_y1_b;
    wire signed [7:0] s_x2_a, s_x2_b;
    wire signed [7:0] s_y2_a, s_y2_b;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_RECTS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD_RECTS: begin
                // Load n rectangles (one per cycle)
                if (count == n_reg - 1) begin
                    next_state = COMPUTE_PREFIX;
                end else begin
                    next_state = LOAD_RECTS;
                end
            end
            
            COMPUTE_PREFIX: begin
                if (count == n_reg - 1) begin
                    next_state = COMPUTE_SUFFIX;
                end else begin
                    next_state = COMPUTE_PREFIX;
                end
            end
            
            COMPUTE_SUFFIX: begin
                if (count == n_reg - 1) begin
                    next_state = CHECK_EXCLUSION;
                end else begin
                    next_state = COMPUTE_SUFFIX;
                end
            end
            
            CHECK_EXCLUSION: begin
                // Check all exclusions (0 to n-1)
                // If we find a valid one, go to DONE
                // Otherwise continue checking
                if (count == n_reg) begin // Already checked all
                    next_state = DONE;
                end else if (check_valid) begin
                    next_state = DONE;
                end else begin
                    next_state = CHECK_EXCLUSION;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Helper function to check validity
    reg check_valid;
    always @(*) begin
        // Check intersection validity: max_x1 <= min_x2 AND max_y1 <= min_y2
        // Using signed comparison for correctness with negative numbers
        if ($signed(temp_max_x1) <= $signed(temp_min_x2) && 
            $signed(temp_max_y1) <= $signed(temp_min_y2)) begin
            check_valid = 1'b1;
        end else begin
            check_valid = 1'b0;
        end
    end
    
    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_x <= 8'sd0;
            result_y <= 8'sd0;
            done <= 1'b0;
            valid <= 1'b0;
            count <= 3'd0;
            n_reg <= 3'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    count <= 3'd0;
                    if (start) begin
                        n_reg <= n;
                    end
                end
                
                LOAD_RECTS: begin
                    // Store current rectangle
                    rects[count] <= {x2_in, y2_in, x1_in, y1_in};
                    count <= count + 1'b1;
                end
                
                COMPUTE_PREFIX: begin
                    if (count == 0) begin
                        // First rectangle is the base
                        prefix[0] <= rects[0];
                    end else begin
                        // Intersect prefix[count-1] with rects[count]
                        // Extract values
                        // prefix[count-1]: {px2, py2, px1, py1}
                        // rects[count]: {cx2, cy2, cx1, cy1}
                        // Result: max(px1, cx1), max(py1, cy1), min(px2, cx2), min(py2, cy2)
                        prefix[count] <= {
                            ($signed(prefix[count-1][31:24]) < $signed(rects[count][31:24])) ? prefix[count-1][31:24] : rects[count][31:24], // min_x2
                            ($signed(prefix[count-1][23:16]) < $signed(rects[count][23:16])) ? prefix[count-1][23:16] : rects[count][23:16], // min_y2
                            ($signed(prefix[count-1][15:8]) > $signed(rects[count][15:8])) ? prefix[count-1][15:8] : rects[count][15:8],   // max_x1
                            ($signed(prefix[count-1][7:0]) > $signed(rects[count][7:0])) ? prefix[count-1][7:0] : rects[count][7:0]       // max_y1
                        };
                    end
                    count <= count + 1'b1;
                end
                
                COMPUTE_SUFFIX: begin
                    if (count == 0) begin
                        // Last rectangle is the base
                        suffix[n_reg - 1] <= rects[n_reg - 1];
                    end else begin
                        // Intersect suffix[n_reg - count] with rects[n_reg - 1 - count]
                        // We need to index backwards
                        // suffix[(n_reg-1) - (count-1)] = suffix[n_reg - count]
                        // rects[(n_reg-1) - count] = rects[n_reg - 1 - count]
                        // Actually, let's use a different approach:
                        // We process count from 1 to n-1
                        // Current index = n_reg - count - 1
                        // Previous suffix = n_reg - count
                        suffix[n_reg - count - 1] <= {
                            ($signed(suffix[n_reg - count][31:24]) < $signed(rects[n_reg - count - 1][31:24])) ? suffix[n_reg - count][31:24] : rects[n_reg - count - 1][31:24],
                            ($signed(suffix[n_reg - count][23:16]) < $signed(rects[n_reg - count - 1][23:16])) ? suffix[n_reg - count][23:16] : rects[n_reg - count - 1][23:16],
                            ($signed(suffix[n_reg - count][15:8]) > $signed(rects[n_reg - count - 1][15:8])) ? suffix[n_reg - count][15:8] : rects[n_reg - count - 1][15:8],
                            ($signed(suffix[n_reg - count][7:0]) > $signed(rects[n_reg - count - 1][7:0])) ? suffix[n_reg - count][7:0] : rects[n_reg - count - 1][7:0]
                        };
                    end
                    count <= count + 1'b1;
                end
                
                CHECK_EXCLUSION: begin
                    // Calculate intersection for excluding rectangle [count]
                    // prefix[count-1] x suffix[count+1]
                    // Handle boundary cases
                    if (count == 0) begin
                        // Excluding first rectangle, only suffix[1] matters (if n > 1)
                        // But algorithm says prefix[-1] which is invalid.
                        // For n=1, there's no solution (need >= n-1 = 0, any point works, but we need >= 1 rectangle)
                        // Actually requirement is "at least (n-1)". For n=1, need 0. But n is 2-8.
                        // For excluding 0, we need intersection of rect[1...n-1] which is suffix[1]
                        temp_max_x1 <= suffix[1][15:8];
                        temp_max_y1 <= suffix[1][7:0];
                        temp_min_x2 <= suffix[1][31:24];
                        temp_min_y2 <= suffix[1][23:16];
                        // Special handling for n=2: if we exclude 0, we have just rect[1]. 
                        // Intersection of [1, 1] is rect[1]. Valid if rect[1] is valid (which it is).
                        // Wait, suffix[1] is valid for n>=2. For n=2, suffix[1] is rect[1].
                    end else if (count == n_reg - 1) begin
                        // Excluding last rectangle, only prefix[n-2] matters
                        temp_max_x1 <= prefix[n_reg - 2][15:8];
                        temp_max_y1 <= prefix[n_reg - 2][7:0];
                        temp_min_x2 <= prefix[n_reg - 2][31:24];
                        temp_min_y2 <= prefix[n_reg - 2][23:16];
                    end else begin
                        // Excluding middle rectangle
                        // Intersection of prefix[count-1] and suffix[count+1]
                        // Take max of max_x1s, min of min_x2s, etc.
                        temp_max_x1 <= ($signed(prefix[count-1][15:8]) > $signed(suffix[count+1][15:8])) ? prefix[count-1][15:8] : suffix[count+1][15:8];
                        temp_max_y1 <= ($signed(prefix[count-1][7:0]) > $signed(suffix[count+1][7:0])) ? prefix[count-1][7:0] : suffix[count+1][7:0];
                        temp_min_x2 <= ($signed(prefix[count-1][31:24]) < $signed(suffix[count+1][31:24])) ? prefix[count-1][31:24] : suffix[count+1][31:24];
                        temp_min_y2 <= ($signed(prefix[count-1][23:16]) < $signed(suffix[count+1][23:16])) ? prefix[count-1][23:16] : suffix[count+1][23:16];
                    end
                    
                    // Check validity on the next cycle (combinatorial check logic uses these temps)
                    // We need to wait for check_valid to settle. 
                    // Actually, we can do this in the combinational block, but we need to update output.
                    // Let's output if check_valid is true in THIS state (pipeline one more cycle or use combo output)?
                    // Specs say "Result appears... with valid=1". Let's output if valid.
                    // However, check_valid depends on the values we just assigned.
                    // So we need a 1-cycle delay or make check_valid delayed.
                    // Let's add a 'check_result' register to latch the valid bit.
                    // But wait, the state logic uses 'check_valid' to decide next state.
                    // So we need to compute it immediately. The temp regs are already set from previous cycle logic?
                    // NO. In the always block, the RHS uses current values.
                    // The check_valid block uses temp_max_x1 etc. 
                    // When we enter CHECK_EXCLUSION, the temps are from the PREVIOUS iteration (or IDLE).
                    // So we need to set temps, then in the NEXT cycle check them.
                    // So the state machine needs to handle this.
                    // Let's restructure CHECK_EXCLUSION to be 2 phases per exclusion.
                    // Or better: Just increment count and compute temps immediately, then check.
                    // But we can't check and output in same cycle if temps update in that cycle.
                    // So we need to compute temps in cycle X, check in cycle X+1.
                    // Let's modify: CHECK_EXCLUSION state computes, DONE state checks output?
                    // Or add a 'CHECKING' sub-state.
                    // Let's make CHECK_EXCLUSION state handle incrementing count.
                    // We need to distinguish "compute step" vs "check step".
                    // Let's add a flag.
                    // Or simpler: Do the computation at the END of the state, latch result.
                    // Let's change: CHECK_EXCLUSION computes for 'count', sets 'result_latch', then increments count.
                    // Next cycle, we check 'result_latch' and output.
                end
                
                DONE: begin
                    done <= 1'b1;
                    // If we got here, it means check_valid was true in the previous cycle
                    // We need to output the coordinates computed in that cycle
                    result_x <= temp_max_x1;
                    result_y <= temp_max_y1;
                    valid <= 1'b1;
                end
            endcase
        end
    end

    // --- RE-DOING THE CHECK LOGIC FOR CORRECT TIMING ---
    // Let's separate the CHECK_EXCLUSION logic into a combinational part that sets outputs
    // and a sequential part that manages the count and state transitions.
    
    // We need to handle the computation of intersection inside CHECK_EXCLUSION state.
    // To avoid race conditions, we will compute the intersection for the CURRENT 'count'
    // inside the combinational block (or earlier sequential block) and use it.
    
    // Let's use a separate always block for state output/actions
    // This is the original 'always @(posedge clk)' block but with refined logic.
    
    // RESET of the specific block logic:
    // We need to handle the CHECK_EXCLUSION transition carefully.
    // We will perform the check inside the always block for the current count.
    
    // Let's refine the state machine execution:
    
    reg [2:0] check_idx;
    reg is_valid;
    
    // Combinational check logic for current 'check_idx'
    always @(*) begin
        if (check_idx < n_reg) begin
            // Compute intersection for excluding check_idx
            // Store to temp wires first
            reg [7:0] t_max_x1, t_max_y1, t_min_x2, t_min_y2;
            
            if (check_idx == 0) begin
                t_max_x1 = suffix[1][15:8];
                t_max_y1 = suffix[1][7:0];
                t_min_x2 = suffix[1][31:24];
                t_min_y2 = suffix[1][23:16];
            end else if (check_idx == n_reg - 1) begin
                t_max_x1 = prefix[n_reg-2][15:8];
                t_max_y1 = prefix[n_reg-2][7:0];
                t_min_x2 = prefix[n_reg-2][31:24];
                t_min_y2 = prefix[n_reg-2][23:16];
            end else begin
                t_max_x1 = ($signed(prefix[check_idx-1][15:8]) > $signed(suffix[check_idx+1][15:8])) ? prefix[check_idx-1][15:8] : suffix[check_idx+1][15:8];
                t_max_y1 = ($signed(prefix[check_idx-1][7:0]) > $signed(suffix[check_idx+1][7:0])) ? prefix[check_idx-1][7:0] : suffix[check_idx+1][7:0];
                t_min_x2 = ($signed(prefix[check_idx-1][31:24]) < $signed(suffix[check_idx+1][31:24])) ? prefix[check_idx-1][31:24] : suffix[check_idx+1][31:24];
                t_min_y2 = ($signed(prefix[check_idx-1][23:16]) < $signed(suffix[check_idx+1][23:16])) ? prefix[check_idx-1][23:16] : suffix[check_idx+1][23:16];
            end
            
            // Validity
            if ($signed(t_max_x1) <= $signed(t_min_x2) && $signed(t_max_y1) <= $signed(t_min_y2)) begin
                is_valid = 1'b1;
            end else begin
                is_valid = 1'b0;
            end
        end else begin
            is_valid = 1'b0;
        end
    end

    // Now the sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count <= 0;
            done <= 0;
            valid <= 0;
            check_idx <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    count <= 0;
                    check_idx <= 0;
                    if (start) begin
                        n_reg <= n;
                        current_state <= LOAD_RECTS;
                    end
                end

                LOAD_RECTS: begin
                    rects[count] <= {x2_in, y2_in, x1_in, y1_in};
                    if (count == n - 1) begin
                        count <= 0;
                        current_state <= COMPUTE_PREFIX;
                    end else begin
                        count <= count + 1;
                    end
                end

                COMPUTE_PREFIX: begin
                    if (count == 0) begin
                        prefix[0] <= rects[0];
                    end else begin
                        prefix[count] <= {
                            ($signed(prefix[count-1][31:24]) < $signed(rects[count][31:24])) ? prefix[count-1][31:24] : rects[count][31:24],
                            ($signed(prefix[count-1][23:16]) < $signed(rects[count][23:16])) ? prefix[count-1][23:16] : rects[count][23:16],
                            ($signed(prefix[count-1][15:8]) > $signed(rects[count][15:8])) ? prefix[count-1][15:8] : rects[count][15:8],
                            ($signed(prefix[count-1][7:0]) > $signed(rects[count][7:0])) ? prefix[count-1][7:0] : rects[count][7:0]
                        };
                    end
                    if (count == n_reg - 1) begin
                        count <= 0;
                        current_state <= COMPUTE_SUFFIX;
                    end else begin
                        count <= count + 1;
                    end
                end

                COMPUTE_SUFFIX: begin
                    // We iterate count from 0 to n-1. 
                    // To fill suffix backwards, we use index (n - 1 - count).
                    // However, we need suffix[i] where i goes 0..n-1.
                    // Let's just iterate count from 0..n-1 and calculate index.
                    // Actually, let's reverse the loop logic.
                    // If we iterate count from 0 to n-1:
                    // We want suffix[n-1-count].
                    // We need to fill suffix[n-1] first with rects[n-1].
                    // Then suffix[n-2] with intersect(rects[n-2], suffix[n-1]).
                    // So we can just increment count.
                    // idx = n - 1 - count.
                    
                    if (count == 0) begin
                        suffix[n_reg - 1] <= rects[n_reg - 1];
                    end else begin
                        suffix[n_reg - 1 - count] <= {
                            ($signed(suffix[n_reg - count][31:24]) < $signed(rects[n_reg - 1 - count][31:24])) ? suffix[n_reg - count][31:24] : rects[n_reg - 1 - count][31:24],
                            ($signed(suffix[n_reg - count][23:16]) < $signed(rects[n_reg - 1 - count][23:16])) ? suffix[n_reg - count][23:16] : rects[n_reg - 1 - count][23:16],
                            ($signed(suffix[n_reg - count][15:8]) > $signed(rects[n_reg - 1 - count][15:8])) ? suffix[n_reg - count][15:8] : rects[n_reg - 1 - count][15:8],
                            ($signed(suffix[n_reg - count][7:0]) > $signed(rects[n_reg - 1 - count][7:0])) ? suffix[n_reg - count][7:0] : rects[n_reg - 1 - count][7:0]
                        };
                    end
                    
                    if (count == n_reg - 1) begin
                        count <= 0;
                        check_idx <= 0;
                        current_state <= CHECK_EXCLUSION;
                    end else begin
                        count <= count + 1;
                    end
                end

                CHECK_EXCLUSION: begin
                    // We use 'check_idx' to know which rectangle we are excluding.
                    // The combinational block 'is_valid' already computed the result for 'check_idx'.
                    
                    if (is_valid) begin
                        // Found a solution
                        // We need to output the coordinates.
                        // They are calculated in the combo block.
                        // To get them to output regs, we might need a buffer or just latch them here.
                        // Since combo block calculates t_max_x1 etc, we can't access them easily.
                        // But we can recalculate in sequential logic or latch in a register.
                        // Let's recalculate in sequential logic to save registers.
                        if (check_idx == 0) begin
                            result_x <= suffix[1][15:8];
                            result_y <= suffix[1][7:0];
                        end else if (check_idx == n_reg - 1) begin
                            result_x <= prefix[n_reg-2][15:8];
                            result_y <= prefix[n_reg-2][7:0];
                        end else begin
                            result_x <= ($signed(prefix[check_idx-1][15:8]) > $signed(suffix[check_idx+1][15:8])) ? prefix[check_idx-1][15:8] : suffix[check_idx+1][15:8];
                            result_y <= ($signed(prefix[check_idx-1][7:0]) > $signed(suffix[check_idx+1][7:0])) ? prefix[check_idx-1][7:0] : suffix[check_idx+1][7:0];
                        end
                        valid <= 1'b1;
                        done <= 1'b1;
                        current_state <= DONE;
                    end else begin
                        // Not valid, try next
                        if (check_idx == n_reg) begin // Should be n_reg - 1 max, so check_idx < n_reg. 
                            // If we exhausted all (shouldn't happen if there is always a solution)
                            // But if no solution, we must signal done without valid.
                            done <= 1'b1;
                            valid <= 1'b0;
                            current_state <= DONE;
                        end else if (check_idx == n_reg - 1) begin
                            // Checked last one, no valid found
                            done <= 1'b1;
                            valid <= 1'b0;
                            current_state <= DONE;
                        end else begin
                            check_idx <= check_idx + 1;
                        end
                    end
                end

                DONE: begin
                    // Wait for reset or start
                    // Handled by IDLE transition
                    if (start) begin
                        // Restart implicitly handled by IDLE next cycle if we go back? 
                        // Usually done stays high until reset.
                        // We stay in DONE until reset.
                    end
                end
            endcase
        end
    end

endmodule
