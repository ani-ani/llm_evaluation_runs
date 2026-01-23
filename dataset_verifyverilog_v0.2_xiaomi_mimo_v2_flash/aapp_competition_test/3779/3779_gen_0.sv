module martian_tax_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [4:0] k,
    input [29:0] a,
    output reg [4:0] result_d,
    output reg [2:0] result_index,
    output reg valid,
    output reg done
);

    // State encoding
    localparam S_IDLE = 3'b000;
    localparam S_GCD_FETCH = 3'b001;
    localparam S_GCD_LOOP = 3'b010;
    localparam S_GCD_WAIT = 3'b011;
    localparam S_FINAL_GCD = 3'b100;
    localparam S_RESULT_GEN = 3'b101;
    localparam S_DONE = 3'b110;

    reg [2:0] state, next_state;
    
    // Variables for GCD calculation
    reg [4:0] a_val;          // Extracted denominator from input vector
    reg [4:0] gcd_g;          // Accumulated gcd value
    reg [4:0] x, y, next_x, next_y;
    reg gcd_step_valid;       // Flag to indicate current gcd pair is valid for calculation
    reg [2:0] idx;            // Index for iterating denominations
    
    // Variables for result generation
    reg [4:0] m;              // Multiplier for generating d = (m * G) mod k
    reg [4:0] d_temp;         // Current result d
    reg [2:0] res_cnt;        // Count of results generated

    // GCD Computation Block (Combinational Logic)
    always @(*) begin
        if (x > y) begin
            next_x = y;
            next_y = x % y; // Modulo operation for GCD
        end else begin
            next_x = x;
            next_y = y % x;
        end
    end

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Control Path & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Outputs
            result_d <= 5'b0;
            result_index <= 3'b0;
            valid <= 1'b0;
            done <= 1'b0;
            
            // Reset Internal Registers
            idx <= 3'b0;
            gcd_g <= 5'b0;
            x <= 5'b0;
            y <= 5'b0;
            m <= 5'b0;
            d_temp <= 5'b0;
            res_cnt <= 3'b0;
            gcd_step_valid <= 1'b0;
        end else begin
            // Default assignments
            valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    if (start) begin
                        idx <= 3'b0;
                        gcd_g <= 5'b0;
                        gcd_step_valid <= 1'b0;
                        // We immediately start fetching the first denomination
                        // Extract first 5 bits (assuming little-endian packing or sequential access)
                        // Using modulo to extract a_i from packed vector 'a'
                        // a_i = a[idx*5 +: 5]
                    end
                end

                S_GCD_FETCH: begin
                    if (idx < n) begin
                        // Extract a_i. We use a dedicated wire or calculate here.
                        // Since 'a' is a 30-bit input, we slice it.
                        // We assume a[4:0] is a_0, a[9:5] is a_1, etc.
                        a_val <= a[idx*5 +: 5];
                        gcd_step_valid <= 1'b1;
                    end else begin
                        // All denominations processed, move to final GCD with k
                        // If no denominations, gcd starts at k (checked in next state)
                        gcd_step_valid <= 1'b0;
                    end
                end

                S_GCD_LOOP: begin
                    // Setup GCD inputs (x, y) and handle updates
                    if (gcd_step_valid) begin
                        // Current operation: update gcd_g = gcd(gcd_g, a_val)
                        // Initial value of gcd_g is 0, gcd(0, v) = v
                        if (idx == 0 && gcd_g == 5'b0) begin
                             gcd_g <= a_val;
                        end else begin
                             // Perform GCD step on (gcd_g, a_val)
                             // We use a temporary register to handle the sequential logic
                             // Or we can use the combinational next_x/next_y logic by setting x,y here
                             x <= gcd_g;
                             y <= a_val;
                        end
                    end else begin
                        // Transition to include k
                        // Case: If we had no denominations (n=0), gcd_g is 0. gcd(0, k) = k.
                        if (gcd_g == 5'b0) gcd_g <= k;
                        else begin
                            // Calculate gcd(gcd_g, k)
                            x <= gcd_g;
                            y <= k;
                        end
                    end
                end
                
                S_GCD_WAIT: begin
                    // One cycle delay for GCD logic to update result in S_GCD_LOOP
                    // Actually, the logic updates immediately in combinational block.
                    // We need to latch the result from x, y updates.
                    // The sequence is: Set x,y -> Wait/Next Cycle -> Read Result
                    // However, our logic is: State S_GCD_LOOP sets x,y. 
                    // We need to interpret the result.
                    // Let's simplify: 
                    // S_GCD_FETCH sets a_val.
                    // S_GCD_LOOP updates gcd_g based on previous x,y. Sets new x,y.
                    // We need a state to wait for the combinational math.
                    // Actually, let's restructure slightly for the iterative GCD.
                    
                    // Re-evaluating the GCD flow for single cycle update:
                    // 1. Set x = gcd_g, y = a_val (or next denominator or k).
                    // 2. Wait 1 cycle (or use comb logic directly).
                    // The code below updates gcd_g in S_GCD_LOOP based on 'x' and 'y' from previous cycle.
                    
                    // Wait state effectively does nothing or handles the latch.
                    // Let's use S_GCD_WAIT to latch the result of the combinational GCD block.
                end

                S_FINAL_GCD: begin
                    // Latch the final G value into gcd_g
                    // The inputs x and y were set in S_GCD_LOOP or S_IDLE (for the final k step)
                    // We need to ensure the GCD calculation loop finishes.
                    // Since we need to compute G = gcd(gcd(g...), k), we might need multiple cycles if we did it sequentially.
                    // But we can compute G = gcd(a_0, ... a_n) then G = gcd(G, k).
                    // The provided architecture seems to expect iterative GCD updates.
                    // Let's assume the GCD calc happens in S_GCD_LOOP/S_GCD_WAIT.
                    
                    // Logic fix: 
                    // In S_GCD_FETCH, we set a_val.
                    // In S_GCD_LOOP, we set x=gcd_g, y=a_val. 
                    // But we need to wait for the result.
                    // Let's make S_GCD_LOOP the 'calculate' state and S_GCD_WAIT the 'update' state.
                end

                S_RESULT_GEN: begin
                    // Output current result
                    // d = (m * gcd_g) % k
                    // We calculate this using modulo logic.
                    // Since k <= 30, we can compute (m * gcd_g) % k directly if m*gcd_g fits in reg.
                    // m goes up to k/gcd_g. 
                    // Let's compute d_temp = (m * gcd_g) % k.
                    // d_temp <= (m * gcd_g) % k; // Syntax error in verilog for variable multiplication in comb block?
                    // We need a combinational block for the modulo, or use sequential multiplier.
                    // Since area is small, let's use a combinational calculation or simple logic.
                    // Actually, let's just update m and d_temp in sequence.
                    
                    // Result generation:
                    // 1. Output current d.
                    // 2. Update m and d for next cycle.
                    // d = (d + G) % k.
                    // Start with d = 0. (m=0). Then d = G, 2G, ...
                    
                    if (res_cnt == 0) begin
                        result_d <= 5'b0;
                        result_index <= 3'b0;
                        valid <= 1'b1;
                        res_cnt <= res_cnt + 1;
                        d_temp <= gcd_g % k; // Next d
                    end else if (res_cnt < (k / gcd_g)) begin
                        result_d <= d_temp;
                        result_index <= res_cnt;
                        valid <= 1'b1;
                        res_cnt <= res_cnt + 1;
                        // Update d_temp for next cycle
                        // d_next = (d_temp + gcd_g) % k
                        // We need to handle the modulo wrap around.
                        // If (d_temp + gcd_g) >= k, subtract k.
                        if (d_temp + gcd_g >= k) d_temp <= d_temp + gcd_g - k;
                        else d_temp <= d_temp + gcd_g;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    // stay here until reset or start goes low
                    // Typically, we wait for start to go low to allow re-triggering, 
                    // or just wait for next start. Let's stay here.
                end
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start) next_state = S_GCD_FETCH;
            end

            S_GCD_FETCH: begin
                if (idx < n) next_state = S_GCD_LOOP;
                else if (idx >= n && gcd_step_valid == 1'b0) next_state = S_DONE; // No denominations case? 
                else next_state = S_FINAL_GCD; // Finished denominations, go to final GCD calc
            end

            S_GCD_LOOP: begin
                // We need to wait for GCD operation or loop.
                // Since GCD is iterative, we need to check if (x==0 or y==0) to stop.
                // But our GCD is computed in one cycle combinational logic.
                // So we can update gcd_g immediately and decide next step.
                // However, we are in sequential block.
                // Let's rely on S_GCD_WAIT to latch the GCD result.
                next_state = S_GCD_WAIT;
            end

            S_GCD_WAIT: begin
                // Determine if we need another iteration for current pair
                // Or move to next denomination
                // Latch result here.
                // If (y == 0) then gcd is x. 
                // Actually, we did: if(x>y) next_y = x%y. 
                // If y becomes 0, x is the GCD.
                // But we are latching in S_GCD_WAIT based on previous cycle's x,y.
                // Wait, the logic is:
                // Cycle N: Set x, y. 
                // Cycle N+1: Combinational logic calculates next_x, next_y. We latch x <= next_x, y <= next_y in S_GCD_WAIT.
                // But we need to loop until one is 0.
                // Let's use a counter or simply handle the state transitions.
                
                // Revised GCD Loop: 
                // We need to repeat S_GCD_WAIT until gcd is found. 
                // Condition: if (x == 0 || y == 0) then gcd found.
                // The combinational block calculates next values.
                // If y becomes 0, next_y = 0, next_x = x. gcd is x.
                // If x becomes 0, next_x = 0, next_y = y. gcd is y. 
                // Actually, if y=0, gcd is x. 
                // So we check: if (y == 0) then done with this pair.
                
                // Wait, what if we are calculating gcd(gcd_g, k)?
                // We need a way to distinguish which iteration we are on.
                // Let's use a flag: 
                // 'processing_denominations' flag.
                // If processing_denominations: 
                //   If y != 0: stay in S_GCD_WAIT. 
                //   Else: gcd_g = x. idx++. Go to S_GCD_FETCH.
                // Else (processing k):
                //   If y != 0: stay in S_GCD_WAIT.
                //   Else: gcd_g = x. Go to S_RESULT_GEN.
                
                // But we don't have a flag stored in the state.
                // Let's use 'gcd_step_valid' to indicate we are processing denominations.
                // And 'idx' to indicate where we are.
                
                // Check if GCD is found for the current pair (x, y).
                // If y == 0, GCD is x.
                // If x == 0, GCD is y.
                // Actually, the loop structure:
                // while (y != 0) { t = y; y = x % y; x = t; }
                // So check y == 0.
                
                if (y == 0) begin
                    // GCD found. 
                    if (gcd_step_valid) begin
                        // We were processing a denomination.
                        // Update gcd_g to x.
                        // Increment idx.
                        // Go to S_GCD_FETCH to get next.
                        next_state = S_GCD_FETCH;
                    end else begin
                        // We were processing k.
                        // Update gcd_g to x.
                        // Go to S_RESULT_GEN.
                        next_state = S_RESULT_GEN;
                    end
                end else begin
                    // Continue GCD iteration (update x, y in S_GCD_LOOP, wait here effectively)
                    // We need to cycle back to S_GCD_LOOP to update x/y using combinational next_x/next_y.
                    // So: S_GCD_LOOP (sets x,y for next calc) -> S_GCD_WAIT (waits for calc, checks y==0)
                    // Actually, S_GCD_WAIT should latch next_x, next_y into x, y.
                    // Then check y. If 0 -> Done. Else -> Go back to S_GCD_LOOP (which does nothing but flow control) -> S_GCD_WAIT.
                    // To save states, we can combine S_GCD_WAIT update logic.
                    // Let's move the update logic for x,y into S_GCD_WAIT state block.
                    // And transition to S_GCD_LOOP only if we need to fetch new data.
                    
                    next_state = S_GCD_WAIT; // Stay here for another iteration
                    // Wait, we need to trigger the update. 
                    // Let's go to S_GCD_LOOP which just sets up the next state transition back to S_GCD_WAIT.
                    next_state = S_GCD_LOOP;
                end
            end

            S_FINAL_GCD: begin
                // This state is used to trigger the GCD calculation with k.
                // We set gcd_step_valid = 0 to indicate we are done with denominations.
                // Then go to S_GCD_LOOP to start the GCD process.
                next_state = S_GCD_LOOP;
            end

            S_RESULT_GEN: begin
                // Generate results.
                // Total count = k / gcd_g.
                // We start with m=0 (result 0). 
                // Loop: if res_cnt < total, output.
                // If res_cnt == total, go to DONE.
                // But we need to output sequentially.
                // Cycle 1: Output 0. Increment res_cnt. 
                // Cycle 2: Output G. Increment res_cnt.
                // ...
                // If res_cnt >= k/gcd_g, we are done.
                
                // We need to compare with total results. 
                // total = k / gcd_g.
                // Note: If gcd_g is 0 (impossible if k>0) or handle k=0.
                // If gcd_g is 0, division by zero. But k is input, should be > 0.
                
                if (res_cnt >= k / gcd_g) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_RESULT_GEN;
                end
            end

            S_DONE: begin
                if (!start) next_state = S_IDLE;
            end
        endcase
    end

    // Datapath Update Logic (Separating the updates from next_state logic)
    // We need to handle the GCD iterative updates.
    // The structure: 
    // S_GCD_WAIT updates x <= next_x, y <= next_y if y != 0.
    // If y==0, it branches to S_GCD_FETCH or S_FINAL_GCD.
    
    // However, the 'always @(posedge clk)' block above handles the registers.
    // We need to make sure x/y are updated in S_GCD_WAIT when we loop.
    // The 'if (state == S_GCD_WAIT)' block in the FSM above didn't explicitly update x/y.
    // It branched. 
    // Let's add the x/y update logic inside the S_GCD_WAIT block.
    
    // Also, we need to handle the case where 'a_val' is set in S_GCD_FETCH.
    // Then S_GCD_LOOP sets x,y. 
    // But we need to set x,y before the calculation.
    // Sequence:
    // 1. S_IDLE.
    // 2. S_GCD_FETCH: sets a_val. 
    // 3. S_GCD_LOOP: sets x=gcd_g, y=a_val. Transitions to S_GCD_WAIT.
    // 4. S_GCD_WAIT: Combinational block calculates next_x, next_y.
    //    If y!=0, update x,y. Transition back to S_GCD_LOOP.
    //    If y==0, result is x. Update gcd_g = x. 
    //       If denominations left: idx++. Transition to S_GCD_FETCH.
    //       If denominations done: Transition to S_FINAL_GCD (which triggers k calc).
    
    // We need to track if we are calculating 'first step' or 'loop'.
    // First step: x=0, y=a_val. gcd(0, y)=y. next_x = y, next_y = 0. 
    // Wait, logic: 
    // x=0, y=a_val. x > y? No. x % y = 0 % y = 0. next_y = 0.
    // next_x = x = 0. 
    // So next_x=0, next_y=0.
    // But gcd(0, a_val) = a_val.
    // My combinational logic is slightly off for the initialization case if we strictly follow %.
    // Usually GCD(0, v) is v. 
    // Let's force the logic: 
    // In S_GCD_LOOP, we set x, y.
    // If gcd_g is 0 (first step), we can just set gcd_g <= a_val directly and skip the GCD loop.
    // Or fix the GCD logic.
    // Let's fix the GCD logic in S_GCD_WAIT:
    // If x == 0, next_y = 0? 
    // If x == 0, we want next_y to be 0, and next_x to be y (the gcd).
    // Let's adjust the combinational block:
    // if (x == 0) begin next_x = y; next_y = 0; end
    // else if (y == 0) begin next_x = x; next_y = 0; end
    // else if (x > y) begin ... end
    // else begin ... end

endmodule

module martian_tax_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [4:0] k,
    input [29:0] a,
    output reg [4:0] result_d,
    output reg [2:0] result_index,
    output reg valid,
    output reg done
);

    // State encoding
    localparam S_IDLE = 3'b000;
    localparam S_GCD_FETCH = 3'b001;
    localparam S_GCD_LOOP = 3'b010;
    localparam S_GCD_WAIT = 3'b011;
    localparam S_FINAL_GCD = 3'b100;
    localparam S_RESULT_GEN = 3'b101;
    localparam S_DONE = 3'b110;

    reg [2:0] state, next_state;
    
    // Registers
    reg [4:0] a_val;          // Extracted denominator
    reg [4:0] gcd_g;          // Accumulated gcd
    reg [4:0] x, y;           // Inputs for GCD calculation
    reg [4:0] next_x, next_y; // Computed next values
    reg [2:0] idx;            // Denomination index
    reg [2:0] res_cnt;        // Result counter
    reg [4:0] d_temp;         // Next result to output
    
    // Combinational GCD Logic
    always @(*) begin
        if (x == 0) begin
            next_x = y;
            next_y = 0;
        end else if (y == 0) begin
            next_x = x;
            next_y = 0;
        end else if (x > y) begin
            next_x = y;
            next_y = x % y;
        end else begin
            next_x = x;
            next_y = y % x;
        end
    end

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else state <= next_state;
    end

    // Datapath and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_d <= 5'b0;
            result_index <= 3'b0;
            valid <= 1'b0;
            done <= 1'b0;
            idx <= 3'b0;
            gcd_g <= 5'b0;
            x <= 5'b0;
            y <= 5'b0;
            res_cnt <= 3'b0;
            d_temp <= 5'b0;
        end else begin
            valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    if (start) begin
                        idx <= 3'b0;
                        gcd_g <= 5'b0;
                        res_cnt <= 3'b0;
                    end
                end

                S_GCD_FETCH: begin
                    if (idx < n) begin
                        a_val <= a[idx*5 +: 5];
                    end
                    // If idx >= n, we transition to FINAL_GCD. Logic handled in next_state.
                end

                S_GCD_LOOP: begin
                    // Determine inputs for GCD block
                    if (idx == 0 && gcd_g == 5'b0 && idx < n) begin
                        // First step with a denomination: gcd(0, a_val) = a_val
                        // We can shortcut this to avoid waiting for GCD calc
                        gcd_g <= a_val;
                        // Signal to move to next fetch or done (handled in next_state)
                    end else if (idx < n) begin
                        // Loop case: gcd(gcd_g, a_val)
                        x <= gcd_g;
                        y <= a_val;
                    end else begin
                        // Final case: gcd(gcd_g, k) triggered by S_FINAL_GCD
                        x <= gcd_g;
                        y <= k;
                    end
                end

                S_GCD_WAIT: begin
                    // Update registers with combinational results
                    // If y == 0, GCD is found (next_y will be 0 in logic above, or handled by check)
                    // Actually, if y == 0, GCD is x.
                    if (y != 0) begin
                        x <= next_x;
                        y <= next_y;
                    end else begin
                        // GCD Complete
                        // Update gcd_g to x (which holds the result)
                        gcd_g <= x;
                        
                        if (idx < n) begin
                            // Processed a denomination, increment idx
                            // Note: We only increment if we actually performed a calc or shortcut.
                            // In S_GCD_LOOP we handled shortcut. 
                            // If we are here, we performed a calc. 
                            // But wait, if we shortcut (first step), we don't go to S_GCD_WAIT?
                            // Let's unify.
                            // If shortcut: gcd_g updated in S_GCD_LOOP. Next state S_GCD_FETCH (or FINAL).
                            // So if we are in S_GCD_WAIT, it means we ran the iterative loop.
                            // So we increment index.
                            idx <= idx + 1;
                        end
                    end
                end

                S_FINAL_GCD: begin
                    // Nothing to update here, just a transition state to setup S_GCD_LOOP for 'k'
                end

                S_RESULT_GEN: begin
                    if (res_cnt == 0) begin
                        // Output 0 first
                        result_d <= 5'b0;
                        result_index <= 3'b0;
                        valid <= 1'b1;
                        res_cnt <= 1;
                        // Prepare next d: gcd_g % k
                        d_temp <= gcd_g % k;
                    end else begin
                        // Output current d_temp
                        result_d <= d_temp;
                        result_index <= res_cnt;
                        valid <= 1'b1;
                        res_cnt <= res_cnt + 1;
                        // Update d_temp for next cycle
                        if (d_temp + gcd_g >= k)
                            d_temp <= d_temp + gcd_g - k;
                        else
                            d_temp <= d_temp + gcd_g;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: if (start) next_state = S_GCD_FETCH;

            S_GCD_FETCH: begin
                if (idx < n) next_state = S_GCD_LOOP;
                else next_state = S_FINAL_GCD;
            end

            S_GCD_LOOP: begin
                // Check if we need to do GCD calculation or just a shortcut
                if (idx < n) begin
                    // Processing a denomination
                    if (idx == 0 && gcd_g == 5'b0) begin
                        // Shortcut: gcd(0, a_val) = a_val. No calc needed.
                        // We can go directly to fetch next or finalize if last.
                        // But we need to increment idx. 
                        // Let's use S_GCD_WAIT to handle the increment and flow control even for shortcut?
                        // Or handle increment here. 
                        // Let's go to S_GCD_WAIT which handles increment if idx < n.
                        // But if we shortcut, we didn't set x,y. 
                        // Let's modify S_GCD_WAIT logic: 
                        // If shortcut, we need to know not to check x,y.
                        // Better: 
                        // If shortcut, update gcd_g, go to S_GCD_FETCH (which increments idx).
                        // Wait, S_GCD_FETCH sets a_val. It doesn't increment idx.
                        // We need a state to increment idx.
                        
                        // Let's do this: S_GCD_LOOP -> S_GCD_FETCH.
                        // In S_GCD_LOOP (shortcut): update gcd_g <= a_val. 
                        // In S_GCD_FETCH: idx <= idx + 1. (Need to add this logic to S_GCD_FETCH).
                        // Logic in S_GCD_FETCH: if (start) or if (from GCD) then idx++?
                        // No, usually increment happens when we are done with current.
                        
                        // Revised Flow:
                        // S_GCD_FETCH (read a_val) -> S_GCD_LOOP.
                        // S_GCD_LOOP checks: if shortcut -> gcd_g <= a_val; next_state = S_GCD_FETCH. (Here idx must increment? No, let's add increment in S_GCD_FETCH if coming from loop)
                        // S_GCD_LOOP checks: else -> set x,y; next_state = S_GCD_WAIT.
                        // S_GCD_WAIT (if y!=0) -> update x,y; next_state = S_GCD_LOOP. (Repeats calc)
                        // S_GCD_WAIT (if y==0) -> gcd_g <= x; next_state = S_GCD_FETCH. (Here idx increments).
                        
                        // So we need to distinguish who calls S_GCD_FETCH.
                        // Let's add a 'do_increment' flag or handle increment in S_GCD_LOOP (shortcut) and S_GCD_WAIT (calc done).
                        next_state = S_GCD_FETCH;
                    end else begin
                        // Standard calc
                        next_state = S_GCD_WAIT;
                    end
                end else begin
                    // Denominations done. 
                    // If we just finished the last one, we need to do final GCD.
                    // But S_GCD_LOOP is entered from S_GCD_FETCH.
                    // If idx >= n, S_GCD_FETCH goes to S_FINAL_GCD.
                    // So we shouldn't be in S_GCD_LOOP with idx >= n unless we are iterating.
                    // So this case (idx < n) covers it.
                    next_state = S_GCD_WAIT;
                end
            end

            S_GCD_WAIT: begin
                if (y != 0) begin
                    // Loop back to calc
                    next_state = S_GCD_LOOP;
                end else begin
                    // GCD done. 
                    // Go to fetch next. 
                    // But we need to increment idx here if we were processing denominations.
                    // Actually, let's modify S_GCD_FETCH to increment when it sees the 'done' signal.
                    // Or we can have S_GCD_WAIT go to a state that increments idx.
                    // Let's just assume S_GCD_WAIT increments idx if processing denominations.
                    // But S_GCD_WAIT is also used for final GCD (k).
                    // So if (idx < n) -> idx++. Go to S_GCD_FETCH.
                    // If (idx >= n) -> Go to S_FINAL_GCD.
                    
                    if (idx < n) next_state = S_GCD_FETCH;
                    else next_state = S_FINAL_GCD;
                end
            end

            S_FINAL_GCD: begin
                // Trigger the loop for k
                next_state = S_GCD_LOOP;
            end

            S_RESULT_GEN: begin
                // Check if done.
                // Total results = k / gcd_g.
                // We output res_cnt=0,1,2,...N-1. Total N.
                // When res_cnt reaches N, we go to done.
                // N = k / gcd_g.
                // So if res_cnt >= k / gcd_g, done.
                // Note: res_cnt starts 0. 
                // Cycle 0: res_cnt=0, output 0, res_cnt becomes 1.
                // Cycle N: res_cnt=N, output last? No.
                // If N=1 (k/gcd_g=1), res_cnt starts 0. We output 0. res_cnt becomes 1.
                // Check: 1 >= 1 -> Done. Correct.
                if (res_cnt >= (k / gcd_g)) next_state = S_DONE;
                else next_state = S_RESULT_GEN;
            end

            S_DONE: begin
                if (!start) next_state = S_IDLE;
            end
        endcase
    end

    // Fix for index increment and shortcut handling:
    // The sequential block above updates registers.
    // Let's add logic for idx increment in S_GCD_WAIT (for calc) and handle shortcut result.
    // Actually, the shortcut case in S_GCD_LOOP:
    // We set gcd_g <= a_val. Then next_state = S_GCD_FETCH.
    // But idx is not incremented.
    // If we go to S_GCD_FETCH again, we will read same a_val (if idx doesn't change).
    // So we MUST increment idx.
    
    // Let's put the increment logic in S_GCD_FETCH entry? 
    // No, S_GCD_FETCH reads a[idx]. So idx must point to the correct value.
    // So increment must happen BEFORE or DURING S_GCD_FETCH.
    
    // Let's change the flow:
    // S_IDLE -> S_GCD_FETCH (idx=0).
    // S_GCD_FETCH reads a[0]. Sets a_val.
    // S_GCD_LOOP: 
    //   If shortcut: gcd_g <= a_val; idx <= idx + 1; next_state = S_GCD_FETCH.
    //   Else: set x,y; next_state = S_GCD_WAIT.
    // S_GCD_WAIT:
    //   If y!=0: update x,y; next_state = S_GCD_LOOP.
    //   If y==0: gcd_g <= x; idx <= idx + 1; next_state = S_GCD_FETCH.
    
    // We need to put 'idx <= idx + 1' in the sequential block.
    // Add these conditions to the sequential block.

endmodule

// Final Cleaned up Version
module martian_tax_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [4:0] k,
    input [29:0] a,
    output reg [4:0] result_d,
    output reg [2:0] result_index,
    output reg valid,
    output reg done
);

    localparam S_IDLE = 3'b000;
    localparam S_GCD_FETCH = 3'b001;
    localparam S_GCD_LOOP = 3'b010;
    localparam S_GCD_WAIT = 3'b011;
    localparam S_FINAL_GCD = 3'b100;
    localparam S_RESULT_GEN = 3'b101;
    localparam S_DONE = 3'b110;

    reg [2:0] state, next_state;
    reg [4:0] a_val;
    reg [4:0] gcd_g;
    reg [4:0] x, y;
    reg [2:0] idx;
    reg [2:0] res_cnt;
    reg [4:0] d_temp;

    // Combinational GCD
    always @(*) begin
        if (x == 0) begin
            x = y; y = 0; // Assign to local net variables or use separate outputs
        end else if (y == 0) begin
            x = x; y = 0;
        end else if (x > y) begin
            x = y; y = x % y;
        end else begin
            y = y % x;
        end
    end
    // Note: We need to be careful with the blocking assignment in combinational block.
    // Let's use next_x, next_y to avoid confusion.
    reg [4:0] next_x_calc, next_y_calc;
    always @(*) begin
        if (x == 0) begin
            next_x_calc = y;
            next_y_calc = 0;
        end else if (y == 0) begin
            next_x_calc = x;
            next_y_calc = 0;
        end else if (x > y) begin
            next_x_calc = y;
            next_y_calc = x % y;
        end else begin
            next_x_calc = x;
            next_y_calc = y % x;
        end
    end

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else state <= next_state;
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_d <= 0; result_index <= 0; valid <= 0; done <= 0;
            idx <= 0; gcd_g <= 0; x <= 0; y <= 0; res_cnt <= 0; d_temp <= 0;
        end else begin
            valid <= 0; done <= 0;
            case (state)
                S_IDLE: begin
                    if (start) begin idx <= 0; gcd_g <= 0; res_cnt <= 0; end
                end
                S_GCD_FETCH: begin
                    if (idx < n) a_val <= a[idx*5 +: 5];
                    // Increment index logic: handled by transition condition or here
                    // We rely on S_GCD_LOOP or S_GCD_WAIT to increment idx
                end
                S_GCD_LOOP: begin
                    if (idx < n) begin
                        if (idx == 0 && gcd_g == 0) begin
                            gcd_g <= a_val;
                            idx <= idx + 1; // Shortcut, next fetch
                        end else begin
                            x <= gcd_g;
                            y <= a_val;
                        end
                    end
                    // For final k, x and y are set in transition logic or here?
                    // The transition to S_FINAL_GCD sets idx=n, so idx < n is false.
                    // We need to handle the k calculation.
                end
                S_GCD_WAIT: begin
                    if (y != 0) begin
                        x <= next_x_calc;
                        y <= next_y_calc;
                    end else begin
                        // GCD result in x
                        gcd_g <= x;
                        if (idx < n) idx <= idx + 1;
                    end
                end
                S_FINAL_GCD: begin
                    x <= gcd_g;
                    y <= k;
                    // We need to set x,y here to start the GCD loop for k
                    // Actually, S_FINAL_GCD is a one-cycle state to setup inputs, then goes to S_GCD_LOOP.
                end
                S_RESULT_GEN: begin
                    if (res_cnt == 0) begin
                        result_d <= 0;
                        result_index <= 0;
                        valid <= 1'b1;
                        res_cnt <= 1;
                        d_temp <= gcd_g % k;
                    end else begin
                        result_d <= d_temp;
                        result_index <= res_cnt;
                        valid <= 1'b1;
                        res_cnt <= res_cnt + 1;
                        if (d_temp + gcd_g >= k) d_temp <= d_temp + gcd_g - k;
                        else d_temp <= d_temp + gcd_g;
                    end
                end
                S_DONE: done <= 1'b1;
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: if (start) next_state = S_GCD_FETCH;
            
            S_GCD_FETCH: begin
                if (idx < n) next_state = S_GCD_LOOP;
                else next_state = S_FINAL_GCD; // idx == n means we processed all 'a' values
            end

            S_GCD_LOOP: begin
                if (idx < n) begin
                    // Processing denominations
                    if (idx == 0 && gcd_g == 0) begin
                        // Shortcut: we updated gcd_g, next cycle fetch next
                        next_state = S_GCD_FETCH;
                    end else begin
                        // Standard calc
                        next_state = S_GCD_WAIT;
                    end
                end else begin
                    // Processing k (triggered by S_FINAL_GCD flow)
                    // We are in S_GCD_LOOP from S_FINAL_GCD
                    // S_FINAL_GCD sets x,y. So we go to WAIT.
                    next_state = S_GCD_WAIT;
                end
            end

            S_GCD_WAIT: begin
                if (y != 0) begin
                    next_state = S_GCD_LOOP; // Iterate
                end else begin
                    // GCD Done
                    if (idx < n) next_state = S_GCD_FETCH;
                    else next_state = S_RESULT_GEN; // Done with k calculation
                end
            end

            S_FINAL_GCD: begin
                next_state = S_GCD_LOOP;
            end

            S_RESULT_GEN: begin
                if (res_cnt >= (k / gcd_g)) next_state = S_DONE;
                else next_state = S_RESULT_GEN;
            end

            S_DONE: if (!start) next_state = S_IDLE;
        endcase
    end
endmodule
