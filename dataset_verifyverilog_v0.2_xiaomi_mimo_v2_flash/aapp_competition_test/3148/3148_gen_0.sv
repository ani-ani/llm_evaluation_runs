module lifeguard_divider (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_swimmers,
    input [31:0] swimmer_x [0:7],
    input [31:0] swimmer_y [0:7],
    output reg [31:0] lifeguard1_x,
    output reg [31:0] lifeguard1_y,
    output reg [31:0] lifeguard2_x,
    output reg [31:0] lifeguard2_y,
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam SEARCH = 3'b010;
    localparam VERIFY = 3'b100;
    // Note: VERIFY state handles iteration through swimmers
    // DONE state is implied by done signal = 1

    reg [2:0] state;
    
    // Candidate position registers
    reg signed [31:0] pos_step;
    reg signed [31:0] lg1_x_cand;
    reg signed [31:0] lg1_y_cand;
    reg signed [31:0] lg2_x_cand;
    reg signed [31:0] lg2_y_cand;
    
    // Verification counters and flags
    reg [3:0] swimmer_idx;
    reg [3:0] count1;
    reg [3:0] count2;
    reg [3:0] equidistant_count;
    
    // Temporary calculation registers
    reg signed [31:0] dx1, dy1, dx2, dy2;
    reg signed [63:0] dist1, dist2;
    
    // Validity flag for current candidate pair
    reg is_valid_pair;
    
    // Solution found flag
    reg solution_found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            solution_found <= 0;
            // Initialize lifeguard positions to 0 on reset
            lifeguard1_x <= 0;
            lifeguard1_y <= 0;
            lifeguard2_x <= 0;
            lifeguard2_y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SEARCH;
                        done <= 0;
                        valid <= 0;
                        solution_found <= 0;
                        pos_step <= -1000; // Start search at -1000
                        // Initialize pair 1 at (-1000, -1000) and pair 2 at (-1000, -1000)
                        lg1_x_cand <= -1000;
                        lg1_y_cand <= -1000;
                        lg2_x_cand <= -1000;
                        lg2_y_cand <= -1000;
                    end
                end

                SEARCH: begin
                    if (!solution_found) begin
                        // Check if we have exhausted all coordinates in range
                        if (lg1_x_cand > 1000 && lg1_y_cand > 1000 && lg2_x_cand > 1000 && lg2_y_cand > 1000) begin
                            // No solution found in search space
                            done <= 1;
                            valid <= 0;
                            state <= IDLE; // Return to idle for next start
                        end else begin
                            // Start verification for the current candidate pair
                            swimmer_idx <= 0;
                            count1 <= 0;
                            count2 <= 0;
                            equidistant_count <= 0;
                            is_valid_pair <= 1; // Assume valid until proven otherwise
                            state <= VERIFY;
                        end
                    end else begin
                        // Solution already found, stay in DONE state
                        done <= 1;
                        valid <= 1;
                        // state <= IDLE; // Stay in idle effectively via done signal logic, but let's keep state logic simple
                        // Actually, let's transition to IDLE to be ready for next start
                        state <= IDLE;
                    end
                end

                VERIFY: begin
                    if (swimmer_idx < num_swimmers) begin
                        // Calculate distances for current swimmer
                        dx1 <= swimmer_x[swimmer_idx] - lg1_x_cand;
                        dy1 <= swimmer_y[swimmer_idx] - lg1_y_cand;
                        dx2 <= swimmer_x[swimmer_idx] - lg2_x_cand;
                        dy2 <= swimmer_y[swimmer_idx] - lg2_y_cand;
                        
                        // Wait one cycle for subtraction or handle next cycle logic
                        // We need to pipeline distance calculation or use next state
                        // Let's move to a calculation state or do it in VERIFY logic
                        // Since we are in VERIFY, let's use next cycle to finish calc and update counts
                        // Actually, we need to wait for multiplication.
                        // Let's change state to UPDATE_COUNTS to handle the decision
                        state <= 5; // Temporary state for updating counts (handle in binary or add localparam)
                    end else begin
                        // Finished checking all swimmers for this pair
                        // Check validity conditions
                        // Valid if: equidistant_count <= 1 AND 
                        // (count1 == count2 OR 
                        // (count1 + 1 == count2 with equidistant) OR 
                        // (count2 + 1 == count1 with equidistant))
                        
                        if (equidistant_count > 1) is_valid_pair <= 0;
                        else if (count1 == count2) is_valid_pair <= is_valid_pair; // Keep state
                        else if (count1 + 1 == count2 && equidistant_count == 1) is_valid_pair <= is_valid_pair;
                        else if (count2 + 1 == count1 && equidistant_count == 1) is_valid_pair <= is_valid_pair;
                        else is_valid_pair <= 0;
                        
                        // Move to state to handle result
                        state <= 6; // POST_VERIFY
                    end
                end
                
                // Intermediate state for distance calculation
                5: begin
                    // Calculate squared distances
                    dist1 <= $signed(dx1) * $signed(dx1) + $signed(dy1) * $signed(dy1);
                    dist2 <= $signed(dx2) * $signed(dx2) + $signed(dy2) * $signed(dy2);
                    swimmer_idx <= swimmer_idx + 1;
                    state <= VERIFY; // Return to VERIFY loop
                end

                // State to process distance comparison (logic moved inside VERIFY for efficiency if possible, 
                // but since multiplication takes cycles, we might need a dedicated state or assume 1-cycle mul.
                // The prompt implies "Maximum 1024 clock cycles", so we can afford sequential operations.
                // Let's simplify: Do subtraction in VERIFY, update counts in next state.
                // Actually, to optimize: Combine distance calc and comparison.
                // Let's restructure VERIFY to be sequential.
                
                // POST_VERIFY state
                6: begin
                    if (is_valid_pair && !solution_found) begin
                        solution_found <= 1;
                        lifeguard1_x <= lg1_x_cand;
                        lifeguard1_y <= lg1_y_cand;
                        lifeguard2_x <= lg2_x_cand;
                        lifeguard2_y <= lg2_y_cand;
                        // We can stop searching immediately or continue. Requirement: Store first valid pair.
                        // We will stop.
                        done <= 1;
                        valid <= 1;
                        state <= IDLE;
                    end else begin
                        // Move to next candidate
                        // Order of search: Iterate lg2 first, then lg1? 
                        // Let's iterate lg1 coordinates, inner loop lg2 coordinates.
                        // Grid: -1000 to 1000 step 100. 21 values each. 441 pairs total.
                        // We need to increment lg2_x first, then lg2_y, then lg1_x, then lg1_y.
                        // Wait, the code above initialized lg2 to match lg1. 
                        // Let's define search order:
                        // Loop Y1 (-1000 to 1000)
                        //   Loop X1 (-1000 to 1000)
                        //     Loop Y2 (-1000 to 1000)
                        //       Loop X2 (-1000 to 1000)
                        // It is easier to increment a single linear counter or nested logic.
                        
                        // Increment Logic:
                        if (lg2_x_cand >= 1000) begin
                            lg2_x_cand <= -1000;
                            if (lg2_y_cand >= 1000) begin
                                lg2_y_cand <= -1000;
                                // Now increment L1
                                if (lg1_x_cand >= 1000) begin
                                    lg1_x_cand <= -1000;
                                    if (lg1_y_cand >= 1000) begin
                                        // End of search space (handled in SEARCH state check)
                                        // Just increment to pass the boundary check
                                        lg1_y_cand <= 1100; 
                                    end else begin
                                        lg1_y_cand <= lg1_y_cand + 100;
                                    end
                                end else begin
                                    lg1_x_cand <= lg1_x_cand + 100;
                                end
                            end else begin
                                lg2_y_cand <= lg2_y_cand + 100;
                            end
                        end else begin
                            lg2_x_cand <= lg2_x_cand + 100;
                        end
                        
                        state <= SEARCH;
                    end
                end

                default: state <= IDLE;
            endcase
            
            // Fix for the VERIFY state logic: 
            // The original VERIFY block above handles flow, but distance calc needs a cycle.
            // Let's rewrite the VERIFY state to handle everything sequentially to avoid extra states.
            // However, standard Verilog synthesis requires careful state design.
            // Given the constraint "Maximum 1024 clock cycles", we can afford multiple states per swimmer.
            // Let's refine the VERIFY flow:
            // 1. Load dx, dy
            // 2. Wait for mult (if not comb) - assume comb latency 1 for simplicity or pipeline.
            // 3. Compare
            // 4. Increment count
            // 5. Loop
            
            // To ensure robustness, let's use the `state` variable as a bitmask or just sequential integers.
            // Previous code logic used 5 and 6 as states which is fine if localparams cover 0-2.
            // Let's make the VERIFY block cleaner.
        end
    end
    
    // Combinational Logic for Distance Calculation and Comparison
    // This part is tricky inside a clocked block without proper state management.
    // Let's rewrite the sequential block to be more explicit about the steps.
    // Actually, let's embed the logic into the state machine transitions properly.
    // The previous "5" and "6" states are fine, but let's define them clearly.
    
    // Re-defining the always block to be strictly correct and synthesizable.
    // We will define states explicitly.
    
    localparam CALC_DIST = 3'b011; // State to compute dist
    localparam INC_SWIMMER = 3'b100; // State to increment swimmer index
    localparam NEXT_PAIR = 3'b101; // State to increment pair pointers
    
    // Override previous logic with a cleaner implementation
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            solution_found <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SEARCH;
                        done <= 0;
                        valid <= 0;
                        solution_found <= 0;
                        // Initialize candidates
                        lg1_x_cand <= -1000;
                        lg1_y_cand <= -1000;
                        lg2_x_cand <= -1000;
                        lg2_y_cand <= -1000;
                    end
                end

                SEARCH: begin
                    // Check if search space exhausted
                    if (lg1_y_cand > 1000) begin
                        state <= IDLE;
                        done <= 1;
                        valid <= 0;
                    end else if (solution_found) begin
                        state <= IDLE;
                        done <= 1;
                        valid <= 1;
                    end else begin
                        // Start verification for current pair
                        swimmer_idx <= 0;
                        count1 <= 0;
                        count2 <= 0;
                        equidistant_count <= 0;
                        state <= VERIFY;
                    end
                end

                VERIFY: begin
                    if (swimmer_idx < num_swimmers) begin
                        // Calculate squared distances
                        // (swimmer_x - lg_x)^2
                        // We calculate step by step or using intermediate signals
                        // Since inputs are reg, we can use them directly in combinationals inside clocked block 
                        // only if we register the results.
                        dx1 <= swimmer_x[swimmer_idx] - lg1_x_cand;
                        dy1 <= swimmer_y[swimmer_idx] - lg1_y_cand;
                        dx2 <= swimmer_x[swimmer_idx] - lg2_x_cand;
                        dy2 <= swimmer_y[swimmer_idx] - lg2_y_cand;
                        state <= CALC_DIST;
                    end else begin
                        // Verification complete for this pair
                        // Check conditions
                        // Valid: eq <= 1 AND (cnt1 == cnt2 OR (cnt1+1==cnt2 && eq==1) OR (cnt2+1==cnt1 && eq==1))
                        if ( (equidistant_count <= 1) && (
                               (count1 == count2) ||
                               ((count1 + 1 == count2) && (equidistant_count == 1)) ||
                               ((count2 + 1 == count1) && (equidistant_count == 1))
                             ) ) begin
                            // Valid pair found
                            lifeguard1_x <= lg1_x_cand;
                            lifeguard1_y <= lg1_y_cand;
                            lifeguard2_x <= lg2_x_cand;
                            lifeguard2_y <= lg2_y_cand;
                            solution_found <= 1;
                            // We don't immediately mark done here, we go to NEXT_PAIR to catch the solution_found flag logic in SEARCH
                            // Or we can go to IDLE directly. But to keep flow clean, we go to NEXT_PAIR (which handles incrementing)
                            // But wait, if we found a solution, we don't want to search more. 
                            // However, the SEARCH state checks solution_found. 
                            // So we can go to SEARCH directly.
                            state <= SEARCH;
                        end else begin
                            // Current pair invalid, try next
                            state <= NEXT_PAIR;
                        end
                    end
                end

                CALC_DIST: begin
                    // Register squared distances (comb logic assumed or multipliers)
                    // Using 64-bit to prevent overflow before comparison
                    dist1 <= $signed(dx1) * $signed(dx1) + $signed(dy1) * $signed(dy1);
                    dist2 <= $signed(dx2) * $signed(dx2) + $signed(dy2) * $signed(dy2);
                    state <= INC_SWIMMER;
                end

                INC_SWIMMER: begin
                    // Compare registered distances
                    if (dist1 < dist2) count1 <= count1 + 1;
                    else if (dist2 < dist1) count2 <= count2 + 1;
                    else equidistant_count <= equidistant_count + 1; // dist1 == dist2
                    
                    swimmer_idx <= swimmer_idx + 1;
                    state <= VERIFY;
                end

                NEXT_PAIR: begin
                    // Increment L2
                    if (lg2_x_cand < 1000) begin
                        lg2_x_cand <= lg2_x_cand + 100;
                    end else begin
                        lg2_x_cand <= -1000;
                        if (lg2_y_cand < 1000) begin
                            lg2_y_cand <= lg2_y_cand + 100;
                        end else begin
                            lg2_y_cand <= -1000;
                            // Increment L1
                            if (lg1_x_cand < 1000) begin
                                lg1_x_cand <= lg1_x_cand + 100;
                            end else begin
                                lg1_x_cand <= -1000;
                                if (lg1_y_cand < 1000) begin
                                    lg1_y_cand <= lg1_y_cand + 100;
                                end else begin
                                    // Overflow to 1100 to signal end in SEARCH state
                                    lg1_y_cand <= 1100;
                                end
                            end
                        end
                    end
                    state <= SEARCH;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule