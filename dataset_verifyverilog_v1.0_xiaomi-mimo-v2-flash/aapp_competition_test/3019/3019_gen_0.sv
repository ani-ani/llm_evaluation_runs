module max_revenue_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [9:0] S [0:13],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_S = 3'd1;
    localparam [2:0] PRECOMPUTE_SUM = 3'd2;
    localparam [2:0] DP_ITERATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    localparam [2:0] CALC_REVENUE = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Core signals
    reg [13:0] mask;
    reg [13:0] submask;
    reg [13:0] S_reg [0:13]; // Store input S values
    reg [13:0] sum_val;
    reg [13:0] temp_sum;
    reg [7:0] dp_val [0:16383]; // DP array, 16K entries
    reg [7:0] rev_val;          // Revenue value
    reg [7:0] temp_max;
    
    // Counters
    reg [3:0] i; // Loop counter for S loading
    reg [13:0] mask_idx; // Counter for DP iteration
    reg [13:0] submask_idx; // Counter for submask iteration
    reg [13:0] saved_mask; // To save current mask during submask iteration
    reg [13:0] saved_submask; // To save current submask during revenue calc
    
    // Control flags
    reg iteration_done;
    reg submask_iteration_done;
    
    // Reset and State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 4'd0;
            mask_idx <= 14'd0;
            submask_idx <= 14'd0;
            iteration_done <= 1'b0;
            submask_iteration_done <= 1'b0;
            mask <= 14'd0;
            submask <= 14'd0;
            sum_val <= 14'd0;
            temp_sum <= 14'd0;
            rev_val <= 8'd0;
            temp_max <= 8'd0;
            saved_mask <= 14'd0;
            saved_submask <= 14'd0;
        end else begin
            state <= next_state;
            
            // Initialize DP array values to 0 (unrolled for Icarus Verilog compatibility)
            // We use a loop to reset dp_val entries as they are accessed
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iteration_done <= 1'b0;
                    submask_iteration_done <= 1'b0;
                    if (start) begin
                        i <= 4'd0;
                    end
                end
                
                LOAD_S: begin
                    if (i < N) begin
                        S_reg[i] <= {4'd0, S[i]}; // Extend to 14 bits if needed
                        i <= i + 4'd1;
                    end
                end
                
                PRECOMPUTE_SUM: begin
                    // Calculate sum of S_i for a specific mask (submask_idx)
                    // Actually, we compute sum on the fly for submask in DP_ITERATE
                end
                
                DP_ITERATE: begin
                    // Main DP Loop Logic
                    if (mask_idx < (14'd1 << N)) begin
                        // Initialize DP[mask] = 0
                        dp_val[mask_idx] <= 8'd0;
                        
                        // Initialize submask loop
                        if (!submask_iteration_done) begin
                            // Generate next submask: submask = (submask - 1) & mask
                            // Start with submask = (mask - 1) & mask for proper iteration
                            if (submask_idx == 14'd0) begin
                                // Start of submask loop for current mask
                                // Check if mask is valid (non-zero)
                                if (mask_idx != 14'd0) begin
                                    submask_idx <= (mask_idx - 14'd1) & mask_idx;
                                end else begin
                                    submask_iteration_done <= 1'b1;
                                end
                            end else begin
                                // Calculate revenue for current submask
                                // Start sum calculation
                                temp_sum <= 14'd0;
                                saved_mask <= mask_idx;
                                saved_submask <= submask_idx;
                                
                                // Move to revenue calc state directly via next_state logic
                            end
                        end
                    end
                end
                
                CALC_REVENUE: begin
                    // Sum S_i for current submask (saved_submask)
                    // Use a loop-like unrolled addition or combinational logic
                    // For simplicity, assume we sum inside CALC_REVENUE or adjacent states
                    // We need a small loop to sum elements
                    // Let's sum in a combinational block or sequential accumulation
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Result is dp[(1<<N)-1]
                    result <= dp_val[(14'd1 << N) - 14'd1];
                end
            endcase
        end
    end
    
    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_S;
            end
            LOAD_S: begin
                if (i >= N) next_state = DP_ITERATE;
            end
            DP_ITERATE: begin
                // We need to handle the nested loops logic here
                // If we are iterating masks and submasks
                // Simplification: Control flow for inner loop
                if (mask_idx >= (14'd1 << N)) begin
                    next_state = FINISH;
                end else if (submask_iteration_done) begin
                    // Done with current mask, move to next
                    next_state = DP_ITERATE; // Stay here, just update counters
                end else if (submask_idx != 14'd0) begin
                    // We have a submask to process
                    next_state = CALC_REVENUE;
                end else if (mask_idx != 14'd0 && submask_idx == 14'd0 && !submask_iteration_done) begin
                    // Starting submask loop
                     // Check if we actually need to enter revenue calc or skip
                     // If submask is 0, we are done with this mask's inner loop
                     // Wait, submask idx logic handles this.
                     // If we entered DP_ITERATE and submask is set up, go to revenue
                     if (submask_idx != 14'd0) next_state = CALC_REVENUE;
                     else next_state = DP_ITERATE; // Skip zero submask
                end
            end
            CALC_REVENUE: begin
                // After calculating revenue (simulated), update DP
                // Then decide next submask or next mask
                // Transition back to DP_ITERATE to update submask_idx
                next_state = DP_ITERATE;
            end
            FINISH: begin
                next_state = IDLE; // Optional: stay in finish or return to idle
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Combinational Revenue Calculation & DP Update
    // This block runs whenever CALC_REVENUE state is active or inside DP_ITERATE logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == DP_ITERATE && submask_idx != 14'd0 && !submask_iteration_done) begin
                // 1. Calculate Sum of S_i for saved_submask
                // Unrolled addition for small N (14)
                sum_val = 14'd0;
                if (saved_submask[0]) sum_val = sum_val + S_reg[0];
                if (saved_submask[1]) sum_val = sum_val + S_reg[1];
                if (saved_submask[2]) sum_val = sum_val + S_reg[2];
                if (saved_submask[3]) sum_val = sum_val + S_reg[3];
                if (saved_submask[4]) sum_val = sum_val + S_reg[4];
                if (saved_submask[5]) sum_val = sum_val + S_reg[5];
                if (saved_submask[6]) sum_val = sum_val + S_reg[6];
                if (saved_submask[7]) sum_val = sum_val + S_reg[7];
                if (saved_submask[8]) sum_val = sum_val + S_reg[8];
                if (saved_submask[9]) sum_val = sum_val + S_reg[9];
                if (saved_submask[10]) sum_val = sum_val + S_reg[10];
                if (saved_submask[11]) sum_val = sum_val + S_reg[11];
                if (saved_submask[12]) sum_val = sum_val + S_reg[12];
                if (saved_submask[13]) sum_val = sum_val + S_reg[13];
                
                // 2. Calculate Revenue (Count Distinct Prime Factors)
                // Simplified combinational logic for primes 2,3,5,7,11,13,17,19,23,29,31,37
                // Using distinct flags
                rev_val = 8'd0;
                begin : rev_calc
                    reg [13:0] rem;
                    rem = sum_val;
                    
                    // 2
                    if (rem % 2 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 2 == 0) rem = rem / 2;
                    end
                    // 3
                    if (rem % 3 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 3 == 0) rem = rem / 3;
                    end
                    // 5
                    if (rem % 5 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 5 == 0) rem = rem / 5;
                    end
                    // 7
                    if (rem % 7 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 7 == 0) rem = rem / 7;
                    end
                    // 11
                    if (rem % 11 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 11 == 0) rem = rem / 11;
                    end
                    // 13
                    if (rem % 13 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 13 == 0) rem = rem / 13;
                    end
                    // 17
                    if (rem % 17 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 17 == 0) rem = rem / 17;
                    end
                    // 19
                    if (rem % 19 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 19 == 0) rem = rem / 19;
                    end
                    // 23
                    if (rem % 23 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 23 == 0) rem = rem / 23;
                    end
                    // 29
                    if (rem % 29 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 29 == 0) rem = rem / 29;
                    end
                    // 31
                    if (rem % 31 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 31 == 0) rem = rem / 31;
                    end
                    // 37
                    if (rem % 37 == 0) begin
                        rev_val = rev_val + 8'd1;
                        while (rem % 37 == 0) rem = rem / 37;
                    end
                end
                
                // 3. Update DP
                // dp[mask] = max(dp[mask], dp[mask ^ submask] + revenue)
                // Read dp[mask ^ submask]
                // Note: We must be careful with read/write order. Since this is sequential,
                // we read dp_val[saved_mask ^ saved_submask] (which should be valid from prev cycles)
                // and compare with dp_val[saved_mask] (current max)
                
                if (dp_val[saved_mask ^ saved_submask] + rev_val > dp_val[saved_mask]) begin
                    dp_val[saved_mask] <= dp_val[saved_mask ^ saved_submask] + rev_val;
                end
                
                // 4. Next Submask Logic
                // submask = (submask - 1) & mask
                // If submask becomes 0, we are done with this mask
                if (submask_idx == ((saved_mask - 14'd1) & saved_mask)) begin
                    // If we just processed the first submask, the next one is (submask-1)&mask
                    // Actually, loop termination condition: while (submask != 0)
                    // If current submask is ((mask-1)&mask), next is (((mask-1)&mask)-1)&mask
                    // Wait, simple iteration:
                    // submask = (submask - 1) & mask
                    // We are at state DP_ITERATE. 
                    // We need to update submask_idx for the next cycle.
                    // This update happens in the next clock cycle.
                end
            end
        end
    end
    
    // State Transition for Submask Iteration
    // We need to update mask_idx and submask_idx counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled in main block
        end else begin
            // Only update counters if we are in DP_ITERATE state and processing
            if (state == DP_ITERATE) begin
                if (submask_iteration_done) begin
                    // Move to next mask
                    mask_idx <= mask_idx + 14'd1;
                    submask_iteration_done <= 1'b0;
                    submask_idx <= 14'd0;
                end else if (submask_idx != 14'd0) begin
                    // Calculate next submask for current mask
                    // Done inside the combinational block implicitly or sequential update?
                    // Let's do the update here for the next cycle
                    if (saved_submask != 14'd0) begin
                        // If saved_submask is not 0, we calculate next.
                        // However, we only update submask_idx when we are ready for the next one.
                        // The first submask is (mask-1)&mask. The loop continues until 0.
                        // Logic:
                        // Cycle 1: submask_idx = 0 (start). Set submask = (mask-1)&mask.
                        // Cycle 2: Process (mask-1)&mask. Set submask = (submask-1)&mask.
                        // ...
                        // Cycle N: Process 1. Set submask = 0.
                        // Cycle N+1: Process 0 (Termination check).
                        
                        // Refined Logic:
                        // If submask_idx == 0, initialize it to (mask_idx-1)&mask_idx
                        // Else, update it to (submask_idx-1)&mask_idx
                        // When it becomes 0, set submask_iteration_done = 1
                        
                        if (submask_idx == ((saved_mask - 14'd1) & saved_mask)) begin
                            // We just initialized the first submask in the previous step?
                            // No, we initialize it when submask_idx == 0.
                            // Then we process it. 
                            // Wait, the logic in `always @(posedge clk)` block above sets submask_idx.
                            // Let's strictly control submask_idx update here.
                        end
                    end
                end
            end
        end
    end
    
    // Revised Sequential Logic for Iteration Control
    // Merging the iteration control into one block to avoid conflicts
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            i <= 4'd0;
            mask_idx <= 14'd0;
            submask_idx <= 14'd0;
            submask_iteration_done <= 1'b0;
        end else begin
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    i <= 4'd0;
                    mask_idx <= 14'd0;
                    submask_idx <= 14'd0;
                    submask_iteration_done <= 1'b0;
                    if (start) begin
                        state <= LOAD_S;
                    end
                end
                
                LOAD_S: begin
                    if (i < N) begin
                        S_reg[i] <= {4'd0, S[i]};
                        i <= i + 4'd1;
                    end else begin
                        state <= DP_ITERATE;
                        // Initialize mask_idx to 1 (since mask 0 is trivial)
                        mask_idx <= 14'd1;
                        submask_idx <= 14'd0;
                        submask_iteration_done <= 1'b0;
                    end
                end
                
                DP_ITERATE: begin
                    if (mask_idx >= (14'd1 << N)) begin
                        // All masks processed
                        state <= FINISH;
                    end else begin
                        // Process current mask
                        
                        // 1. Initialize DP value for this mask if not done
                        // We can set dp_val[mask_idx] to 0 initially.
                        // (Or rely on it being 0 from a clean state, but good practice to clear)
                        
                        if (!submask_iteration_done) begin
                            if (submask_idx == 14'd0) begin
                                // Start of submask loop for this mask
                                if (mask_idx != 14'd0) begin
                                    submask_idx <= (mask_idx - 14'd1) & mask_idx;
                                end else begin
                                    submask_iteration_done <= 1'b1;
                                end
                            end else begin
                                // We have a valid submask to process
                                // Calculate Revenue and Update DP
                                // Sum S_i
                                temp_sum <= 14'd0;
                                if (submask_idx[0]) temp_sum <= temp_sum + S_reg[0]; // This is combinational logic issue
                                
                                // Better to do calculation in combinational block or next state
                                // Let's use a CALC_REVENUE state for cleanliness
                                state <= CALC_REVENUE;
                            end
                        end else begin
                            // Done with this mask, move to next
                            mask_idx <= mask_idx + 14'd1;
                            submask_idx <= 14'd0;
                            submask_iteration_done <= 1'b0;
                        end
                    end
                end
                
                CALC_REVENUE: begin
                    // Perform calculations
                    // 1. Sum
                    temp_sum = 14'd0;
                    if (submask_idx[0]) temp_sum = temp_sum + S_reg[0];
                    if (submask_idx[1]) temp_sum = temp_sum + S_reg[1];
                    if (submask_idx[2]) temp_sum = temp_sum + S_reg[2];
                    if (submask_idx[3]) temp_sum = temp_sum + S_reg[3];
                    if (submask_idx[4]) temp_sum = temp_sum + S_reg[4];
                    if (submask_idx[5]) temp_sum = temp_sum + S_reg[5];
                    if (submask_idx[6]) temp_sum = temp_sum + S_reg[6];
                    if (submask_idx[7]) temp_sum = temp_sum + S_reg[7];
                    if (submask_idx[8]) temp_sum = temp_sum + S_reg[8];
                    if (submask_idx[9]) temp_sum = temp_sum + S_reg[9];
                    if (submask_idx[10]) temp_sum = temp_sum + S_reg[10];
                    if (submask_idx[11]) temp_sum = temp_sum + S_reg[11];
                    if (submask_idx[12]) temp_sum = temp_sum + S_reg[12];
                    if (submask_idx[13]) temp_sum = temp_sum + S_reg[13];
                    
                    // 2. Revenue (Prime Factor Count)
                    rev_val = 8'd0;
                    begin : calc_rev
                        reg [13:0] rem;
                        rem = temp_sum;
                        if (rem % 2 == 0) begin rev_val = rev_val + 8'd1; while (rem % 2 == 0) rem = rem / 2; end
                        if (rem % 3 == 0) begin rev_val = rev_val + 8'd1; while (rem % 3 == 0) rem = rem / 3; end
                        if (rem % 5 == 0) begin rev_val = rev_val + 8'd1; while (rem % 5 == 0) rem = rem / 5; end
                        if (rem % 7 == 0) begin rev_val = rev_val + 8'd1; while (rem % 7 == 0) rem = rem / 7; end
                        if (rem % 11 == 0) begin rev_val = rev_val + 8'd1; while (rem % 11 == 0) rem = rem / 11; end
                        if (rem % 13 == 0) begin rev_val = rev_val + 8'd1; while (rem % 13 == 0) rem = rem / 13; end
                        if (rem % 17 == 0) begin rev_val = rev_val + 8'd1; while (rem % 17 == 0) rem = rem / 17; end
                        if (rem % 19 == 0) begin rev_val = rev_val + 8'd1; while (rem % 19 == 0) rem = rem / 19; end
                        if (rem % 23 == 0) begin rev_val = rev_val + 8'd1; while (rem % 23 == 0) rem = rem / 23; end
                        if (rem % 29 == 0) begin rev_val = rev_val + 8'd1; while (rem % 29 == 0) rem = rem / 29; end
                        if (rem % 31 == 0) begin rev_val = rev_val + 8'd1; while (rem % 31 == 0) rem = rem / 31; end
                        if (rem % 37 == 0) begin rev_val = rev_val + 8'd1; while (rem % 37 == 0) rem = rem / 37; end
                    end
                    
                    // 3. DP Update
                    // Read dp_val[submask_idx ^ mask_idx] (mask ^ submask)
                    // Wait, dp[mask] = max(dp[mask], dp[mask ^ submask] + revenue)
                    // Since we are in state CALC_REVENUE, we have the revenue.
                    // We need to compare dp[mask_idx] vs dp[mask_idx ^ submask_idx] + rev_val
                    // Note: dp[mask_idx ^ submask_idx] is always smaller than mask_idx, so it's computed.
                    
                    if (dp_val[mask_idx ^ submask_idx] + rev_val > dp_val[mask_idx]) begin
                        dp_val[mask_idx] <= dp_val[mask_idx ^ submask_idx] + rev_val;
                    end
                    
                    // 4. Update Submask
                    // submask = (submask - 1) & mask
                    if (submask_idx == 14'd0) begin
                        // Should not happen here if logic is correct, but safety
                        submask_iteration_done <= 1'b1;
                    end else begin
                        submask_idx <= (submask_idx - 14'd1) & mask_idx;
                        // Check if new submask is 0
                        if (((submask_idx - 14'd1) & mask_idx) == 14'd0) begin
                            submask_iteration_done <= 1'b1;
                        end
                    end
                    
                    state <= DP_ITERATE;
                end
                
                FINISH: begin
                    result <= dp_val[(14'd1 << N) - 14'd1];
                    done <= 1'b1;
                    state <= IDLE; // Return to IDLE for next request
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule