module pillar_collapse (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [3:0] b_addr,
    input wire [23:0] b_data_in,
    input wire b_wr,
    output reg [4:0] max_damage,
    output reg [3:0] best_idx,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOADING = 3'd1;
    localparam [2:0] SCENARIO_LOOP = 3'd2;
    localparam [2:0] SIMULATE_COLLAPSE = 3'd3;
    localparam [2:0] UPDATE_MAX = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [23:0] b_reg [0:15]; // Internal storage for pillar strengths
    reg [15:0] status;        // Current intact/collapsed status (1=intact)
    reg [4:0] current_load [0:15]; // Current load on each pillar
    reg [3:0] current_pillar; // Which pillar we are destroying
    reg [3:0] pass_count;     // Iteration count for collapse simulation
    reg [3:0] scan_idx;       // Index for scanning pillars in a pass
    reg collapse_flag;        // Flag if any pillar collapsed in current pass
    reg [4:0] damage_count;   // Count of destroyed pillars for current scenario
    reg [2:0] pass_sub_state; // Sub-states for simulation pipeline
    
    // Load lookup table (1000 / distance, 0-15)
    // Values: 1000, 500, 333, 250, 200, 166, 142, 125, 111, 100, 90, 83, 76, 71, 66, 62
    wire [9:0] load_table [0:15];
    assign load_table[0] = 10'd0; // Should not be used (distance 0)
    assign load_table[1] = 10'd1000;
    assign load_table[2] = 10'd500;
    assign load_table[3] = 10'd333;
    assign load_table[4] = 10'd250;
    assign load_table[5] = 10'd200;
    assign load_table[6] = 10'd166;
    assign load_table[7] = 10'd142;
    assign load_table[8] = 10'd125;
    assign load_table[9] = 10'd111;
    assign load_table[10] = 10'd100;
    assign load_table[11] = 10'd90;
    assign load_table[12] = 10'd83;
    assign load_table[13] = 10'd76;
    assign load_table[14] = 10'd71;
    assign load_table[15] = 10'd66;

    // Integer used for loops
    integer i;

    // Block RAM write logic
    always @(posedge clk) begin
        if (b_wr) begin
            b_reg[b_addr] <= b_data_in;
        end
    end

    // State Machine Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_damage <= 5'd0;
            best_idx <= 4'd0;
            done <= 1'b0;
            current_pillar <= 4'd0;
            pass_count <= 4'd0;
            scan_idx <= 4'd0;
            collapse_flag <= 1'b0;
            damage_count <= 5'd0;
            pass_sub_state <= 3'd0;
            for (i = 0; i < 16; i = i + 1) begin
                status[i] <= 1'b0;
                current_load[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize max to 0 (minimum possible damage is 1 if n>0)
                        max_damage <= 5'd0;
                        best_idx <= 4'd0;
                    end
                end

                LOADING: begin
                    // Setup for scenario loop
                    current_pillar <= 4'd0;
                end

                SCENARIO_LOOP: begin
                    // Setup next scenario
                    // Reset status to all intact (using bit mask based on n would be cleaner but loop is ok)
                    // Actually, strictly status[15:n] should be ignored or forced intact, 
                    // but problem implies pillars 0 to n-1 are active.
                    // Let's initialize status to all 1s, then we only care about 0..n-1.
                    // However, we must ensure invalid pillars don't count.
                    // We will just initialize to all 1s.
                    for (i = 0; i < 16; i = i + 1) begin
                        status[i] <= 1'b1;
                        current_load[i] <= 5'd0;
                    end
                    pass_count <= 4'd0;
                    pass_sub_state <= 3'd0;
                end

                SIMULATE_COLLAPSE: begin
                    // Pipeline state logic
                    // Sub-state 0: Calculate Load for current_scan_idx
                    // Sub-state 1: Check Failure Condition
                    // Sub-state 2: Update Status (if failed)
                    
                    case (pass_sub_state)
                        3'd0: begin
                            // Calculate load contribution from current_pillar to scan_idx
                            if (scan_idx != current_pillar) begin
                                // Calculate distance
                                // Since we can't use abs() easily in synthesis without signed logic,
                                // we calculate distance manually.
                                // Simple logic: if scan > cur, dist = scan - cur. Else dist = cur - scan.
                                // Since unsigned, we can just compare and subtract.
                                if (scan_idx > current_pillar) begin
                                    // Dist = scan_idx - current_pillar
                                    // Cap distance at 15 for LUT access
                                    if (scan_idx - current_pillar < 15) begin
                                        current_load[scan_idx] <= current_load[scan_idx] + load_table[scan_idx - current_pillar];
                                    end else begin
                                        current_load[scan_idx] <= current_load[scan_idx] + load_table[15];
                                    end
                                end else begin
                                    // Dist = current_pillar - scan_idx
                                    if (current_pillar - scan_idx < 15) begin
                                        current_load[scan_idx] <= current_load[scan_idx] + load_table[current_pillar - scan_idx];
                                    end else begin
                                        current_load[scan_idx] <= current_load[scan_idx] + load_table[15];
                                    end
                                end
                            end
                            pass_sub_state <= 3'd1;
                        end

                        3'd1: begin
                            // Check if current pillar (scan_idx) fails
                            // Only if it is currently intact AND within valid range (0 to n-1)
                            if (status[scan_idx] && scan_idx < n) begin
                                if (current_load[scan_idx] > b_reg[scan_idx]) begin
                                    // It collapses
                                    collapse_flag <= 1'b1;
                                end
                            end
                            pass_sub_state <= 3'd2;
                        end

                        3'd2: begin
                            // Update status if it failed (delayed update logic)
                            // Note: We need to look at the check from previous cycle (Sub_state 1)
                            // However, since load was just added in Sub_state 0, and checked in 1,
                            // we need to check if it exceeded now.
                            // Logic adjustment: check condition directly in Sub_state 1 or 2 using the updated load.
                            // To avoid race conditions in simulation, we calculate load in stage 0,
                            // check in stage 1, update in stage 2.
                            // But stage 1 needs the load value calculated in stage 0. 
                            // Since it's combinational or sequential, let's rely on the updated register.
                            // Actually, standard sequential update: 
                            // Cycle N: Calc Load -> Cycle N+1: Check -> Cycle N+2: Update.
                            // Let's do everything in one pass if possible or tighter.
                            
                            // Re-evaluating stage 1 logic for sequential timing:
                            // In stage 2, we look at the result of stage 1 logic (registered or comb).
                            // Let's make stage 1 comb check on the load updated in stage 0.
                            // However, stage 0 updated load this cycle, so stage 2 reads it.
                            // Let's simplify:
                            // 0: Add Load (if intact)
                            // 1: Check Threshold (if intact) -> set flag
                            // 2: Update Status (if flag set)
                            
                            // Correct logic for Stage 2 (Update):
                            // We need to know if scan_idx failed this cycle.
                            // Let's use a temporary flag `failed_this_cycle` computed in stage 1.
                            // To minimize registers, we can fuse Check and Update.
                            // But let's stick to the sub_state structure.
                            
                            // Let's recalc the check logic here for update:
                            // It failed if status was 1, scan_idx < n, and load > b.
                            // We need to re-read the condition or have stored the result.
                            // Let's store `failed_this_cycle` register in Stage 1.
                            // (Added `failed_this_cycle` reg below in sequential block)
                            
                            if (failed_this_cycle) begin
                                status[scan_idx] <= 1'b0;
                            end
                            pass_sub_state <= 3'd3;
                        end

                        3'd3: begin
                            // Move to next scan_idx
                            scan_idx <= scan_idx + 4'd1;
                            if (scan_idx == 4'd15) begin
                                // Finished pass
                                scan_idx <= 4'd0;
                                pass_sub_state <= 3'd4; // Go to pass evaluation
                            end else begin
                                pass_sub_state <= 3'd0; // Start next scan
                            end
                        end

                        3'd4: begin
                            // Check if collapse_flag was set
                            if (collapse_flag) begin
                                collapse_flag <= 1'b0;
                                pass_count <= pass_count + 4'd1;
                                if (pass_count < 4'd15) begin
                                    // Start next pass
                                    pass_sub_state <= 3'd0;
                                end else begin
                                    // Max passes reached, force stop
                                    pass_sub_state <= 3'd5;
                                end
                            end else begin
                                // No collapses, simulation done
                                pass_sub_state <= 3'd5;
                            end
                        end

                        3'd5: begin
                            // Calculate Damage (Popcount)
                            // We can do this sequentially in UPDATE_MAX state
                            // Just trigger transition here
                        end
                    endcase
                end

                UPDATE_MAX: begin
                    // Count destroyed pillars in current scenario
                    // (Logic moved here to simplify SIMULATE_COLLAPSE)
                    // Actually, better to count while simulating or in a separate counter.
                    // Let's do it here: 
                    // We need to count 0s in status[0:n-1]
                    // We can use `scan_idx` again.
                    
                    // Reset count for this scenario calculation
                    // Wait, we need `damage_count` to be calculated based on `status`.
                    // Let's iterate scan_idx.
                    if (scan_idx == 4'd0) damage_count <= 5'd0;
                    
                    if (scan_idx < n) begin
                        if (!status[scan_idx]) begin
                            damage_count <= damage_count + 5'd1;
                        end
                        scan_idx <= scan_idx + 4'd1;
                        // Stay in UPDATE_MAX until done
                        next_state <= UPDATE_MAX;
                    end else begin
                        // Comparison
                        // Check if current damage > max_damage
                        // If so, update max_damage and best_idx
                        if (damage_count > max_damage) begin
                            max_damage <= damage_count;
                            best_idx <= current_pillar;
                        end
                        // Move to next scenario
                        current_pillar <= current_pillar + 4'd1;
                        scan_idx <= 4'd0;
                        // Check if finished all scenarios
                        // Scenarios: 0 to n-1. Total n scenarios.
                        // We can check current_pillar >= n - 1 (since we just incremented)
                        // Or check next_state logic.
                        if (current_pillar >= n - 1) begin
                            // Actually, if n=1, current_pillar goes 0->0. 
                            // We need to handle n=0 case? n is 1-16.
                            // If current_pillar was n-1, we just finished.
                            next_state <= DONE;
                        end else begin
                            next_state <= SCENARIO_LOOP;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational logic for next state and helper registers
    reg failed_this_cycle;
    
    always @(*) begin
        next_state = state; // Default
        failed_this_cycle = 1'b0;
        
        case (state)
            IDLE: if (start) next_state = LOADING;
            
            LOADING: next_state = SCENARIO_LOOP;
            
            SCENARIO_LOOP: next_state = SIMULATE_COLLAPSE;
            
            SIMULATE_COLLAPSE: begin
                if (pass_sub_state == 3'd1) begin
                    // Check logic (Combinational for stage 1)
                    // Note: current_load is updated in sub_state 0 of the SAME cycle.
                    // So this check reads the load that was just updated by scan_idx.
                    // This is a timing critical path but necessary for sequential density.
                    // To be safe, we might need an extra cycle, but let's try this.
                    if (status[scan_idx] && (scan_idx < n) && (scan_idx != current_pillar)) begin
                        if (current_load[scan_idx] > b_reg[scan_idx]) begin
                            failed_this_cycle = 1'b1;
                        end
                    end
                end
                
                if (pass_sub_state == 3'd5) begin
                    next_state = UPDATE_MAX;
                end
            end

            UPDATE_MAX: begin
                // Handled in sequential logic for iteration
                // But we need to check if we are done looping to update next_state in seq logic
                // Actually, the sequential logic sets next_state to UPDATE_MAX or others.
                // If scan_idx >= n, we decide next state in seq block.
                if (scan_idx >= n) begin
                    // Done counting, check seq logic for state transition
                    // The seq block sets next_state based on current_pillar
                end
            end
            
            DONE: next_state = IDLE; // Or stay DONE until acknowledged? Requirement says 1-cycle pulse. 
                                     // Actually, output valid until next start. 
                                     // Pulse usually means single cycle high. 
                                     // We'll stay high until reset/start. Usually okay.
                                     // Or go back to IDLE. Let's go to IDLE to allow restart.
            default: next_state = IDLE;
        endcase
    end

endmodule