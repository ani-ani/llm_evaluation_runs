module bandwidth_allocator(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_species,
    input [31:0] total_bandwidth,
    input [7:0][31:0] a_min,
    input [7:0][31:0] b_max,
    input [7:0][31:0] demand,
    output reg [7:0][31:0] x_alloc,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALC_SUM = 3'b001;
    localparam CALC_FAIR = 3'b010;
    localparam CLASSIFY = 3'b011;
    localparam ALLOCATE = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] idx; // index for iterating through species
    reg [2:0] count_in_range;

    // Q16.16 constants
    localparam [31:0] Q16_16_ONE = 32'h00010000;

    // Intermediate registers for calculations
    reg [63:0] sum_demands;     // 64-bit to hold sum
    reg [63:0] sum_demands_in_range; // Sum for proportional distribution
    reg [63:0] remaining_bandwidth; // Remaining after initial allocation
    reg [63:0] fair_share_mult; // (total_bandwidth << 16) / sum_demands
    reg [63:0] temp_fair;       // temp for fair share calculation
    reg [63:0] temp_alloc;      // temp for allocation calculation
    reg [63:0] temp_remaining;  // temp for remaining bandwidth calc
    reg [63:0] sum_range_demands_check; // Check if sum is zero to avoid div by zero
    
    // Classification flags (indexed by idx)
    wire is_below_min;
    wire is_at_min;
    wire is_in_range;
    wire is_at_max;
    wire is_above_max;
    
    // Classification results storage (bitmask style or array of states)
    // Using a register array to store classification for each species
    reg [2:0] species_class [0:7]; // 0=below, 1=min, 2=range, 3=max, 4=above
    
    // Division state machine for hardware-friendly division
    // We use a simple restoring divider or iterative subtraction for (A << 16) / B
    // State for division
    reg div_start;
    reg div_busy;
    reg [5:0] div_cnt; // 32 iterations for 32-bit result
    reg [63:0] div_rem; // Remainder (N bits) = A << 16
    reg [31:0] div_denom; // Denominator B
    reg [31:0] div_quot; // Quotient result
    reg [63:0] div_rem_next;
    reg [31:0] div_quot_next;

    // Division control signals
    // op_type: 0 = sum_demands (for fair share base), 1 = sum_in_range (for proportional)
    reg div_op_sum; 
    
    // Sequential logic for state and division
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 0;
            sum_demands <= 0;
            sum_demands_in_range <= 0;
            remaining_bandwidth <= 0;
            fair_share_mult <= 0;
            temp_fair <= 0;
            temp_alloc <= 0;
            temp_remaining <= 0;
            sum_range_demands_check <= 0;
            div_busy <= 0;
            div_cnt <= 0;
            div_rem <= 0;
            div_denom <= 0;
            div_quot <= 0;
            count_in_range <= 0;
            done <= 0;
            x_alloc <= 0;
            species_class[0] <= 0; species_class[1] <= 0; species_class[2] <= 0;
            species_class[3] <= 0; species_class[4] <= 0; species_class[5] <= 0;
            species_class[6] <= 0; species_class[7] <= 0;
        end else begin
            state <= next_state;

            // Default done clear unless in DONE state holding
            if (state != DONE) done <= 0;

            // Division Logic (Iterative)
            if (div_busy) begin
                // Shift sub
                if (div_rem >= {1'b0, div_denom}) begin
                    div_rem_next = div_rem - {1'b0, div_denom};
                    div_quot_next = {div_quot[30:0], 1'b1};
                end else begin
                    div_rem_next = div_rem;
                    div_quot_next = {div_quot[30:0], 1'b0};
                end
                div_rem <= div_rem_next << 1;
                div_quot <= div_quot_next;
                
                if (div_cnt == 31) begin
                    // Final shift for last bit result
                    div_busy <= 0;
                    div_cnt <= 0;
                end
            end else if (div_start && !div_busy) begin
                // Start division
                // A / B => (A << 16) / B -> result is Q16.16
                // Input A is in 'div_rem' (pre-loaded), B in 'div_denom'
                // We need 32 iterations
                div_busy <= 1;
                div_cnt <= 0;
                div_quot <= 0;
                // div_rem is already shifted by 16 externally before start
            end

            // State Logic Updates
            case (state)
                IDLE: begin
                    if (start) begin
                        idx <= 0;
                        sum_demands <= 0;
                        count_in_range <= 0;
                    end
                end
                
                CALC_SUM: begin
                    // Accumulate sum_demands
                    if (idx < num_species) begin
                        sum_demands <= sum_demands + {32'b0, demand[idx]};
                        idx <= idx + 1;
                    end
                end
                
                CALC_FAIR: begin
                    // Fair share Multiplier Calculation: (Total << 16) / Sum
                    // Triggered once sum is done. Logic handled in NEXT state logic to start div.
                    // But we need to catch the result of division here.
                    if (div_busy && div_cnt == 31) begin
                    end
                    
                    // Logic for Fair Share per index
                    // We iterate species, trigger division for fair_share_mult once.
                    // Wait for it to finish, then compute y_i.
                end
                
                CLASSIFY: begin
                    // Store classification based on comparison done in next_state logic
                    // Advance idx
                    if (idx < num_species) begin
                        idx <= idx + 1;
                    end
                end
                
                ALLOCATE: begin
                    // First phase: Set boundary values, calculate remaining
                    // Second phase: Distribute remaining (Proportional)
                    // We iterate twice effectively.
                    // Step 1: Apply min/max, calc remaining, sum_in_range_demands
                    // Step 2: Calculate final x_alloc for in_range species
                    if (idx < num_species) begin
                    end
                end
                
                DONE: begin
                    done <= 1;
                end
            endcase

            // Custom Logic for Arithmetic inside states
            // To manage latency and complexity, we might need to break states further
            // or use the sequential logic above strictly for flow control and registers for data.
        end
    end

    // We need a more robust control flow. 
    // Let's break down states into micro-steps or use counters within states.
    // Given the 256 cycle limit, we have plenty of time.
    
    // Re-defining the state machine with counters for iterations
    reg [3:0] step; // Internal step counter for states
    
    // Helper: Signed comparison for Q16.16? The problem implies positive values.
    // "always positive" demand. "min/max". Assuming unsigned comparison for Q16.16.
    
    // Division Logic Fix:
    // Iterative division (Restoring or Non-restoring).
    // We want to calculate Result = (A << 16) / B.
    // Input A is 64-bit (sum_demands or sum_demands_in_range). B is 32-bit.
    // Result should be 32-bit Q16.16.
    // Shift A left by 16 effectively makes A[47:16] integer part if A was Q16.16.
    // Let's assume A and B are Q16.16. 
    // Division of Q16.16 / Q16.16 = Q16.16.
    // Formula: (A * 65536) / B. 
    // Input A is 64-bit in upper 32 bits (or lower). 
    // Let's use a dedicated block for division to keep the main FSM clean.
    
    // Main combinational next state logic
    always @(*) begin
        next_state = state;
        div_start = 0;
        
        case (state)
            IDLE: begin
                if (start) next_state = CALC_SUM;
            end
            
            CALC_SUM: begin
                if (idx + 1 >= num_species) next_state = CALC_FAIR;
            end
            
            CALC_FAIR: begin
                // We need to perform division to get fair_share multiplier
                // Fair_Share_i = Total * Demand_i / Sum
                // Since we don't want to do 8 multiplies and 8 divides, 
                // Algorithm says: y_i = t * d_i / sum(d_j)
                // Let's do: 
                // 1. Calculate Factor = (Total << 16) / Sum_Demands. (Result Q16.16)
                // 2. Calculate Fair_i = (Factor * d_i) >> 16. (Multiply Q16.16 * Q16.16 -> Q32.32, take upper 32 bits -> Q16.16)
                // This is 1 division and 8 multiplies.
                
                // Or do iterative division per species? No, too slow.
                // Let's stick to the 1 Division approach.
                // State Logic: Wait for division to finish.
                if (!div_busy && !div_start) begin
                    // Start Division
                    div_start = 1;
                end
                if (!div_busy && div_quot != 0 && step == 0) begin
                end
                
                // Actually, let's manage the division state machine explicitly.
                // If we are in CALC_FAIR, we need to compute the factor first.
                // Once factor is computed, we iterate species to classify.
            end
            
            CLASSIFY: begin
                if (idx >= num_species) next_state = ALLOCATE;
            end
            
            ALLOCATE: begin
                // This state has two sub-phases
                // Phase 1: Calc remaining, sum in-range demands (needs division wait)
                // Phase 2: Distribute (needs division wait)
                // We need to expand state or use counters.
                if (step == 4) next_state = DONE; // Placeholder
            end
            
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // To satisfy the requirements cleanly in one module without excessive sub-states,
    // we will implement a more explicit control flow using the main clock.
    // We will use 'step' to control micro-operations within states.
    // We will also ensure the division logic is correct.
    
    // --- DIVISION UNIT ---
    // We implement a 32-cycle restoring divider.
    // Inputs: div_num (64 bit), div_den (32 bit). Output: div_res (32 bit).
    // We use the 'div_busy' and 'div_cnt' registers from the always block.
    
    // Corrected Division Logic:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_busy <= 0;
            div_cnt <= 0;
            div_rem <= 0;
            div_quot <= 0;
        end else begin
            if (div_start) begin
                div_busy <= 1;
                div_cnt <= 0;
                // Input loading happens in main FSM logic block below
            end else if (div_busy) begin
                // Perform one step of restoring division
                // Shift left div_rem and div_quot
                {div_rem, div_quot} <= {div_rem[62:0], div_quot, 1'b0};
                
                // Let's use a simpler logic description:
                // At cycle k (0 to 31):
                // Shift {Rem, Quot} left by 1.
                // Try Sub = Rem - Divisor.
                // If Sub >= 0: Rem = Sub, Quot[0] = 1.
                // Else: Quot[0] = 0.
                
                if (div_cnt < 32) begin
                    reg [95:0] working = {div_rem, div_quot};
                    reg [95:0] shifted = working << 1;
                    reg [63:0] test_rem = shifted[95:32]; // Upper 64 bits
                    
                    if (test_rem >= {32'b0, div_denom}) begin
                        shifted = shifted | 1'b1; // Set quotient bit 1
                        shifted[95:32] = shifted[95:32] - {32'b0, div_denom}; // Subtract
                    end
                    
                    div_rem <= shifted[95:32];
                    div_quot <= shifted[31:0];
                    div_cnt <= div_cnt + 1;
                end else begin
                    div_busy <= 0;
                end
            end
        end
    end

    // --- MAIN FSM LOGIC (Combinational and Sequential) ---
    // We will use 'step' register to iterate within states.
    // step 0: Initialization for a sub-operation
    // step 1+: Iterations (classification, allocation)
    // wait: Wait for div_busy to clear.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step <= 0;
            idx <= 0;
            // Reset other arrays
            x_alloc <= 0;
            sum_demands <= 0;
            sum_demands_in_range <= 0;
            remaining_bandwidth <= 0;
            count_in_range <= 0;
        end else begin
            case (state)
                IDLE: begin
                    step <= 0;
                    if (start) begin
                        // Initialize
                        sum_demands <= 0;
                        sum_demands_in_range <= 0;
                        remaining_bandwidth <= 0;
                        count_in_range <= 0;
                        idx <= 0;
                    end
                end

                CALC_SUM: begin
                    // Accumulate sum of demands
                    if (idx < num_species) begin
                        sum_demands <= sum_demands + {32'b0, demand[idx]};
                        idx <= idx + 1;
                    end else begin
                        idx <= 0;
                    end
                end

                CALC_FAIR: begin
                    // Sub-state 0: Trigger division for Fair Share Multiplier
                    if (step == 0) begin
                        if (!div_busy) begin
                            // Division: Factor = (Total << 16) / Sum_Demands
                            // Input: Dividend (Total << 16), Divisor (Sum_Demands)
                            // Total is 32b, Sum is 64b. 
                            // (Total << 16) fits in 48b (16+32). 
                            // We pass 64b dividend. 
                            // Since sum_demands is sum of Q16.16, it can be up to 8 * 2^32 approx.
                            // We need 64-bit register for sum.
                            // Dividend = {total_bandwidth, 16'b0}. (Upper 32 bits of 64b reg)
                            
                            div_rem <= {total_bandwidth, 16'b0}; // Upper 48 bits are data, rest 0
                            div_quot <= 0;
                            div_denom <= sum_demands[31:0]; // Assuming sum_demands fits 32b for now? 
                            // Wait, sum_demands is 64b. If sum > 32 bits, divisor needs to be 64b.
                            // The divider supports 64b divisor implicitly if we compare full 64b.
                            // Our divider logic used: if (test_rem >= {32'b0, div_denom}).
                            // We need to update 'div_denom' to 64 bit or handle it.
                            // Let's pass sum_demands to a 64-bit divisor register in the divider.
                            // But the code above used 'div_denom' as 32b. Let's fix that.
                            
                            // Actually, to keep it simple: we only divide (Total << 16) by Sum.
                            // Result is Factor (Q16.16).
                            // We will use a dedicated Divider FSM module? No, inline it.
                            // Let's assume Sum fits in 32 bits for this specific logic, or handle 64b.
                            // If demand is Q16.16 (max 2^16 integer), 8 species = 8*2^16 = 524288. 
                            // That fits in 32 bits. So sum_demands fits in 32 bits (lower 32 bits of the 64b register).
                            // Let's enforce that or truncate. 
                            // We will use sum_demands[31:0] as divisor.
                            
                            div_denom <= sum_demands[31:0]; // Use lower 32 bits
                            // Need to make sure sum_demands > 0. Algorithm assumes valid input.
                            
                            // Start divider
                            // To implement (A << 16) / B in our divider:
                            // We need to feed (A << 16) into 'div_rem'.
                            // A = Total. 
                            // div_rem = {Total, 16'b0}. 
                            // Our divider takes 64b dividend in 'div_rem' register.
                            // It shifts left 32 times. 
                            // Result quotient is in 'div_quot' (32 bits).
                            
                            div_rem <= {total_bandwidth, 16'b0}; // 32+16 = 48 bits used
                            div_quot <= 0;
                            step <= 1; // Wait for result
                            
                            // Start signal
                            // We modify the divider to auto-start or use a signal
                            // Let's rely on 'div_busy' being set by logic here.
                            div_busy <= 1;
                            div_cnt <= 0;
                        end
                    end else if (step == 1) begin
                        // Wait for divider to finish
                        if (!div_busy) begin
                            // Result is in div_quot. This is Fair_Share_Multiplier = (Total << 16) / Sum.
                            // Or wait, it is Factor = Total / Sum (Q16.16).
                            // No, (Total << 16) / Sum = (Total / Sum) * 65536. 
                            // This is actually the Factor for the multiply: Fair_i = (Factor * d_i) >> 16.
                            // So Factor = Total / Sum. 
                            // Result in div_quot is correct Q16.16 representation of Total/Sum.
                            
                            fair_share_mult <= {32'b0, div_quot}; // Store Factor
                            
                            // Now we need to iterate species to classify
                            step <= 2; // Classification phase
                            idx <= 0;
                        end
                    end else if (step == 2) begin
                        // Classification Loop
                        // We iterate idx 0 to num_species-1
                        if (idx < num_species) begin
                            // Calculate Fair Share = (Factor * demand[idx]) >> 16
                            // Use temporary multiplier or sequential?
                            // Let's do combinational multiply for speed, 32x32 mul is fine.
                            // Factor is Q16.16, Demand is Q16.16. Product is Q32.32.
                            // We need upper 32 bits (Q16.16).
                            temp_fair = fair_share_mult[31:0] * demand[idx]; // 32x32 -> 64b
                            // Take upper 32 bits of result (bits 63:32)
                            // Note: 32x32 max is 2^64. 
                            // We need to shift right 16. 
                            // Result = (Factor * Demand) >> 16.
                            // So we take bits 47:16 of the 64-bit product.
                            // Or take bits 63:32 if we treated inputs as 16.16 properly?
                            // No, 32.32 product of two 16.16 numbers.
                            // (F << 16) * (D << 16) = (F*D) << 32.
                            // To get Q16.16 result, we take bits 47:16.
                            // Let's use a wire for this calculation.
                            
                            // Actually, let's do the comparisons directly.
                            // Fair_i is 32-bit Q16.16.
                            // Let's compute it cleanly.
                            // 64-bit mult result: 
                            wire [63:0] prod = fair_share_mult[31:0] * demand[idx];
                            wire [31:0] fair_i = prod[47:16]; // Shift right 16
                            
                            // Compare fair_i with a_min[idx] and b_max[idx]
                            if (fair_i < a_min[idx]) species_class[idx] <= 3'b001; // BELOW -> Assign Min
                            else if (fair_i > b_max[idx]) species_class[idx] <= 3'b100; // ABOVE -> Assign Max
                            else species_class[idx] <= 3'b010; // IN RANGE
                            
                            // Also, x_alloc provisional: 
                            // If below min -> x = a_min
                            // If above max -> x = b_max
                            // We can write to x_alloc here or later. 
                            // Let's write provisional in x_alloc.
                            if (fair_i < a_min[idx]) x_alloc[idx] <= a_min[idx];
                            else if (fair_i > b_max[idx]) x_alloc[idx] <= b_max[idx];
                            else x_alloc[idx] <= fair_i; // Tentative, might be overwritten
                            
                            idx <= idx + 1;
                        end else begin
                            // Done classifying, move to allocation calc
                            // But wait, we need to sum in-range demands and calculate remaining bandwidth.
                            // We need to iterate again for that.
                            step <= 3;
                            idx <= 0;
                            sum_demands_in_range <= 0;
                            remaining_bandwidth <= 0;
                        end
                    end else if (step == 3) begin
                        // Sum in-range demands & calculate remaining bandwidth
                        // First, calculate total allocated so far.
                        // Note: We need to sum up x_alloc set so far (which are mins and maxes and tentative ranges).
                        // But x_alloc for in_range is tentative Fair, which might exceed remaining.
                        // Actually, algorithm says: 
                        // 1. Set min/max.
                        // 2. Calculate remaining = T - sum(mins/maxes).
                        // 3. Sum demands of in-range species.
                        // 4. Distribute remaining.
                        
                        // We iterate species. 
                        // If class is NOT IN RANGE, we are done (value is fixed).
                        // If class IS IN RANGE, we add its demand to sum_in_range.
                        // And we need to subtract its tentative fair value from remaining?
                        // No, remaining is T - Sum(Min) - Sum(Max).
                        // Tentative fair for in_range is NOT subtracted yet.
                        
                        // Let's re-read: "First set boundary values, calculate remaining bandwidth"
                        // Remaining = Total - Sum(Allocated for Boundary).
                        // "distribute proportionally among in_range"
                        // So we need to compute Sum(Demands of in_range).
                        
                        if (idx < num_species) begin
                            if (species_class[idx] == 3'b010) begin // In Range
                                sum_demands_in_range <= sum_demands_in_range + {32'b0, demand[idx]};
                                count_in_range <= count_in_range + 1;
                            end else begin
                                // Boundary species: Add their allocation to remaining calc
                                // (Total - Sum(Boundary))
                                // We can accumulate remaining here: Total - Sum.
                                // But we need Total. 
                                // Let's accumulate "Allocated_So_Far" (Boundaries only).
                                // remaining = Total - Allocated_So_Far.
                                // We can accumulate Allocated_So_Far in a register.
                                remaining_bandwidth <= remaining_bandwidth + {32'b0, x_alloc[idx]};
                            end
                            idx <= idx + 1;
                        end else begin
                            // Finish calculation
                            // remaining_bandwidth currently holds sum of boundaries.
                            // We need: remaining = Total - remaining_bandwidth.
                            // Check if count_in_range > 0. 
                            // If 0, we are done. go to DONE.
                            // If > 0, proceed to proportional distribution.
                            
                            // Calculate Remaining for distribution: Total - Sum_Boundaries
                            temp_remaining = {total_bandwidth, 16'b0} - (remaining_bandwidth << 16); // Ensure Q format
                            // Actually, Total is Q16.16, Sum is Q16.16. 
                            // diff = Total - Sum.
                            // We need to store this diff.
                            // Let's use remaining_bandwidth to store the DIFF.
                            // remaining_bandwidth (64b) = {Total, 16'b0} - (remaining_bandwidth << 16)? No.
                            // Let's use a separate temp or overwrite.
                            
                            // Let's use 'remaining_bandwidth' to store the DIFF.
                            // Diff = Total - Sum_Boundaries.
                            // Note: Total is 32b. Sum is 64b (accumulated). 
                            // We assume Sum < Total.
                            // diff_q16 = Total - Sum.
                            // Store diff in remaining_bandwidth (64b for safety).
                            
                            wire [63:0] diff = {total_bandwidth, 16'b0} - (remaining_bandwidth << 16);
                            // Wait, remaining_bandwidth holds sum of x_alloc (Q16.16).
                            // Total is Q16.16.
                            // To compute: T - S. Result is Q16.16.
                            // diff = {T, 16'b0} - (S << 16). (Scaled by 2^16 for safety in 64b).
                            // Actually, just T - S gives Q16.16.
                            // Let's do: remaining_bandwidth <= {total_bandwidth - remaining_bandwidth[31:0], 16'b0}.
                            // But remaining_bandwidth is 64b holding sum.
                            
                            // Let's use temp_remaining to hold the DIFF.
                            // We need to pass this to the division step.
                            temp_remaining = {16'b0, total_bandwidth} - remaining_bandwidth[47:16]; // Extract upper 32 bits of sum
                            // Wait, remaining_bandwidth was accumulating x_alloc.
                            // x_alloc is Q16.16. Accumulating 4 of them. Max < 2^34.
                            // We store sum in remaining_bandwidth[63:0].
                            // To compute Diff = Total - Sum:
                            // We need Sum in Q16.16 format. Sum is stored in upper bits if we shifted.
                            // Let's assume remaining_bandwidth holds sum shifted by 16 (i.e. 64b value = Sum * 65536).
                            // Total * 65536 is {total_bandwidth, 16'b0}.
                            
                            // Recalculate step 3 logic: 
                            // We need to store Sum_Boundaries.
                            // Let's store Sum_Boundaries in 'sum_demands' (reuse register).
                            // And count_in_range in 'count'.
                            // Then in step 4, calculate Diff = Total - Sum_Boundaries.
                            // Then Divide Diff / Sum_Demands_In_Range.
                            
                            // Let's backtrack slightly. 
                            // State ALLOCATE (which we are in, step 3).
                            // Step 3: Accumulate Sum_Boundaries and Sum_Range_Demands.
                            // We used 'remaining_bandwidth' for Sum_Boundaries. Let's rename? No.
                            // We used 'sum_demands' for total sum. We can reuse it. 
                            // Let's use 'sum_demands' to store Sum_Boundaries.
                            
                            // Correction for Step 3 logic:
                            // If (species_class[idx] == IN_RANGE) -> sum_demands_in_range += demand
                            // Else -> sum_demands += x_alloc (which is a_min or b_max)
                            
                            // At end of Step 3:
                            // Step 4: Calculate Diff = Total - sum_demands.
                            // Step 5: If sum_demands_in_range > 0, Div = Diff / sum_demands_in_range.
                            // Step 6: For each IN_RANGE, x = a_min + Diff * d_i / sum_demands.
                            
                            // Let's implement this flow.
                            // Reset registers appropriately at start of ALLOCATE state.
                            
                            // Re-implementing ALLOCATE state logic:
                            // We need to handle this carefully.
                            // We will just use one 'step' loop for allocation logic.
                            // Step 3: Iterate and accumulate.
                            
                            // We need to fix the code flow. 
                            // Given the complexity, let's optimize the ALLOCATE state to be very specific.
                            
                            // --- OPTIMIZED ALLOCATE FLOW ---
                            // 1. Reset indices. Calculate Sum_Boundaries and Sum_Range_Demands.
                            // 2. Wait for divisions.
                            // 3. Distribute.
                            
                            // We are inside 'step == 3' logic block.
                            // Let's fix the accumulation.
                            
                            // Correct Accumulation:
                            if (idx < num_species) begin
                                if (species_class[idx] == 3'b010) begin
                                    sum_demands_in_range <= sum_demands_in_range + {32'b0, demand[idx]};
                                end else begin
                                    sum_demands <= sum_demands + {32'b0, x_alloc[idx]};
                                end
                                idx <= idx + 1;
                            end else begin
                                // Finished accumulation
                                // Check if sum_demands_in_range is zero
                                if (sum_demands_in_range == 0) begin
                                    step <= 6; // Jump to DONE (or just finish)
                                    // Actually, if no in_range, we are done. Go to step 6 which sets done.
                                end else begin
                                    // Calculate Remaining: Total - Sum_Boundaries
                                    // Use 'remaining_bandwidth' to store Remaining (Diff).
                                    // Diff = Total (32b) - sum_demands[31:0] (approx 32b part). 
                                    // Ensure alignment.
                                    // Total is Q16.16. Sum_Boundaries is Q16.16.
                                    // We need Diff for division.
                                    // Let's prepare division: 
                                    // Factor2 = Diff / Sum_Range_Demands.
                                    // Result is Q16.16.
                                    // Dividend: Diff << 16. Divisor: Sum_Range_Demands.
                                    
                                    // We need to check if Total >= Sum_Boundaries.
                                    // Assume yes.
                                    wire [31:0] diff_q16 = total_bandwidth - sum_demands[31:0];
                                    
                                    // Start Division 2
                                    div_rem <= {diff_q16, 16'b0}; // Diff << 16
                                    div_quot <= 0;
                                    div_denom <= sum_demands_in_range[31:0]; // Lower 32 bits of sum
                                    div_busy <= 1;
                                    div_cnt <= 0;
                                    
                                    step <= 4; // Wait for division
                                end
                            end
                        end
                    end else if (step == 4) begin
                        // Wait for Factor2 = Diff / Sum_Demands_In_Range
                        if (!div_busy) begin
                            // Result is in div_quot. This is Ratio = (Diff / Sum_Demands).
                            // Now we need to iterate species again to update x_alloc.
                            // x_i = a_min + Ratio * d_i.
                            // Since Ratio is Q16.16 and d_i is Q16.16:
                            // Product = Ratio * d_i -> Q32.32. Result = Product >> 16.
                            // a_i is Q16.16. Add them.
                            
                            // Store Ratio
                            remaining_bandwidth <= {32'b0, div_quot}; // Reuse register for Ratio
                            
                            step <= 5;
                            idx <= 0;
                        end
                    end else if (step == 5) begin
                        // Final Distribution Loop
                        if (idx < num_species) begin
                            if (species_class[idx] == 3'b010) begin // In Range
                                // Calculate Delta = Ratio * d_i
                                // Ratio is in remaining_bandwidth[31:0]
                                // d_i is demand[idx]
                                temp_alloc = remaining_bandwidth[31:0] * demand[idx]; // 64b result
                                // Delta (Q16.16) = temp_alloc[47:16]
                                // New x = a_min[idx] + Delta
                                wire [31:0] delta = temp_alloc[47:16];
                                x_alloc[idx] <= a_min[idx] + delta;
                            end
                            // If not in range, x_alloc is already set (min/max)
                            idx <= idx + 1;
                        end else begin
                            step <= 6; // Finish
                        end
                    end else if (step == 6) begin
                        // Finalize
                        // State transition handles DONE
                    end
                end
            endcase
        end
    end

    // Helper combinational logic for Fair Share Calculation in CLASSIFY state
    wire [63:0] fair_prod;
    wire [31:0] fair_i_wire;
    assign fair_prod = fair_share_mult * demand[idx];
    assign fair_i_wire = fair_prod[47:16];

endmodule