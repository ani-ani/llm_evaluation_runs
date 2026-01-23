module tsp_solver(
    input clk,
    input rst_n,
    input start,
    input [2:0] city_distance_0_1, city_distance_0_2, city_distance_0_3,
    input [2:0] city_distance_1_2, city_distance_1_3,
    input [2:0] city_distance_2_3,
    output reg [15:0] min_cost,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK_PERMUTATION = 3'b010;
    localparam CALCULATE_COST = 3'b011;
    localparam UPDATE_MIN = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Permutation storage (4 cities, 3 bits each)
    reg [2:0] p [0:3];
    reg [2:0] p_temp [0:3];
    
    // Counter for permutation generation
    reg [3:0] counter;
    
    // Validity flag and cost calculation registers
    reg valid;
    reg [15:0] current_cost;
    reg [2:0] idx; // Index for loops
    reg [2:0] dist_idx_a, dist_idx_b;
    reg [2:0] dist_val;

    // Constraint Check Variables
    reg [2:0] k;
    reg [2:0] smaller_cities [0:2]; // Stores cities < K
    reg [1:0] smaller_count;
    reg [2:0] i_loop;
    reg [2:0] pos_check;
    reg is_smaller;
    reg all_before;
    reg all_after;
    reg check_fail;

    // Cost Calculation Variables
    reg [2:0] u, v;
    reg [2:0] c_u, c_v;
    reg [2:0] d_val;
    reg [15:0] temp_cost;

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = CHECK_PERMUTATION;
            CHECK_PERMUTATION: next_state = (counter == 4'd14) ? DONE : (valid ? CALCULATE_COST : CHECK_PERMUTATION);
            CALCULATE_COST: next_state = UPDATE_MIN;
            UPDATE_MIN: next_state = CHECK_PERMUTATION;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // State Register and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_cost <= 16'hFFFF;
            counter <= 4'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                INIT: begin
                    min_cost <= 16'hFFFF; // Max value
                    counter <= 4'd0;
                    // Initialize with first permutation (1,2,3,0) - standard binary count result is (0,1,2,3) but we treat 0..3 as cities
                    // Let's use (0,1,2,3) as the base
                    p[0] <= 3'd0;
                    p[1] <= 3'd1;
                    p[2] <= 3'd2;
                    p[3] <= 3'd3;
                end

                CHECK_PERMUTATION: begin
                    // If we are updating min cost, we just returned from UPDATE_MIN, so we need the NEXT permutation
                    // But if we just came from INIT, we need to check the CURRENT permutation (0,1,2,3)
                    // To handle this uniformly, we generate next perm at the END of UPDATE_MIN or at the start of this state if needed
                    // Let's generate next permutation if we are NOT just starting or updating
                    // Actually, simpler logic: 
                    // 1. Check current p.
                    // 2. If valid, transition to calc.
                    // 3. If not valid, increment to next p.
                    // 4. If we just incremented and it's the 14th valid attempt or something? 
                    
                    // Revised Logic for State Machine Flow:
                    // INIT sets p to 0,1,2,3. 
                    // CHECK_PERMUTATION: Check validity of current p.
                    // If valid: transition to CALCULATE.
                    // If not valid: generate next permutation, increment counter. If counter limit reached -> DONE, else stay in CHECK.
                    
                    // In this state, we performed the check in combinational logic before entering or using registered values.
                    // If !valid, we need to generate next perm.
                    if (!valid) begin
                        if (counter < 4'd24) begin
                            // Simple increment and Fisher-Yates shuffle simulation or just binary increment
                            // Since we need ALL permutations, binary increment on indices 0..23 (4! is 24) is easiest.
                            // Wait, binary increment gives duplicates if we just treat p as a 12-bit number.
                            // We need a permutation generator. 
                            // Efficient way: Counter 0 to 23 -> Decode to permutation via LUT or Logic.
                            // Let's use a Counter. 
                            
                            // Actually, let's use the standard permutation generation: next_permutation logic on p itself
                            // p is [0,1,2,3] currently.
                            // We will implement next_permutation in combinational block and use it here.
                            p <= p_temp; // p_temp is next permutation
                            counter <= counter + 1'b1;
                        end else begin
                            // Counter exceeded (should not happen if logic is correct, but safety)
                            // If we exhausted all, done.
                        end
                    end
                end

                CALCULATE_COST: begin
                    // cost is calculated in combinational logic, maybe registered here
                    current_cost <= temp_cost;
                end

                UPDATE_MIN: begin
                    if (temp_cost < min_cost) begin
                        min_cost <= temp_cost;
                    end
                    // Now generate next permutation for the next cycle
                    // We perform next_perm logic here to be ready for CHECK_PERMUTATION state
                    p <= p_temp;
                    counter <= counter + 1'b1;
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic for Validity Check
    always @(*) begin
        // Check constraint: For city K (1,2,3), all smaller cities must be on one side.
        valid = 1'b1;
        check_fail = 1'b0;
        
        // We check K=1,2,3 (Indices 1,2,3)
        for (k = 3'd1; k <= 3'd3; k = k + 3'd1) begin
            // Collect smaller cities indices 0..k-1
            smaller_count = 0;
            for (i_loop = 3'd0; i_loop < k; i_loop = i_loop + 3'd1) begin
                smaller_cities[smaller_count] = i_loop;
                smaller_count = smaller_count + 3'd1;
            end

            // Find position of K in permutation
            // This loop will be unrolled by synthesis
            // We assume p contains indices 0..3 (cities)
            // Wait, p contains the sequence of cities visited.
            // Example: p[0]=2, p[1]=0, p[2]=1, p[3]=3. This means visit 2, then 0, then 1, then 3.
            
            // Find positions of K and smaller cities
            // Optimization: Just scan the permutation once per K is inefficient in HW but fine for N=4.
            // Better: Find pos_K.
            
            // Find position of K
            reg [1:0] pos_k;
            pos_k = 2'b0;
            for (i_loop = 3'd0; i_loop < 3'd4; i_loop = i_loop + 3'd1) begin
                if (p[i_loop] == k) pos_k = i_loop[1:0];
            end
            
            // Check positions of smaller cities
            // Flags for side check
            all_before = 1'b1;
            all_after = 1'b1;
            
            for (i_loop = 3'd0; i_loop < smaller_count; i_loop = i_loop + 3'd1) begin
                // find position of smaller_cities[i_loop]
                reg [1:0] pos_s;
                pos_s = 2'b0;
                for (idx = 3'd0; idx < 3'd4; idx = idx + 3'd1) begin
                    if (p[idx] == smaller_cities[i_loop]) pos_s = idx[1:0];
                end
                
                if (pos_s < pos_k) all_after = 1'b0;
                else all_before = 1'b0;
            end
            
            if (!all_before && !all_after) check_fail = 1'b1;
        end
        
        if (check_fail) valid = 1'b0;
    end

    // Combinational Logic for Cost Calculation
    always @(*) begin
        temp_cost = 16'd0;
        // Sum of distances between consecutive cities in permutation
        // p[0]->p[1], p[1]->p[2], p[2]->p[3], p[3]->p[0] (TSP loop)
        
        // Use helper function or explicit lookup
        // We need to access the matrix. Matrix is upper triangular.
        // Distance(u, v) = distance_input[min(u,v)][max(u,v)]
        // Map [0,1] -> city_distance_0_1, etc.
        
        for (idx = 3'd0; idx < 3'd4; idx = idx + 3'd1) begin
            u = p[idx];
            v = p[(idx + 1'b1) & 3'b11]; // Next city, wrap around for last
            
            // Get distance
            d_val = get_dist(u, v);
            temp_cost = temp_cost + d_val;
        end
    end

    // Helper function to get distance (must be automatic or combinational logic)
    // Verilog function inside module
    function [2:0] get_dist;
        input [2:0] u;
        input [2:0] v;
        reg [2:0] min_city, max_city;
        begin
            min_city = (u < v) ? u : v;
            max_city = (u < v) ? v : u;
            case ({min_city, max_city})
                {3'd0, 3'd1}: get_dist = city_distance_0_1;
                {3'd0, 3'd2}: get_dist = city_distance_0_2;
                {3'd0, 3'd3}: get_dist = city_distance_0_3;
                {3'd1, 3'd2}: get_dist = city_distance_1_2;
                {3'd1, 3'd3}: get_dist = city_distance_1_3;
                {3'd2, 3'd3}: get_dist = city_distance_2_3;
                default: get_dist = 3'd0;
            endcase
        end
    endfunction

    // Combinational Logic for Next Permutation Generation (Studer's Algorithm)
    // p_temp will hold the next permutation of current p
    always @(*) begin
        // Default keep same
        for (idx = 0; idx < 4; idx = idx + 1) p_temp[idx] = p[idx];
        
        // Step 1: Find largest index k such that p[k] < p[k+1]. If no such index, it's the last permutation.
        // For N=4, we can unroll.
        // We need to find the NEXT permutation. 
        // If we are in INIT, p is 0,1,2,3. Next is 0,1,3,2.
        
        // Let's implement the standard algorithm logic.
        // Indices: 0, 1, 2, 3.
        
        // Find k
        reg signed [2:0] k_idx;
        k_idx = -1;
        if (p[2] < p[3]) k_idx = 2;
        else if (p[1] < p[2]) k_idx = 1;
        else if (p[0] < p[1]) k_idx = 0;
        
        if (k_idx != -1) begin
            // Find l such that p[l] > p[k]
            reg signed [2:0] l_idx;
            l_idx = -1;
            // Search from right
            if (p[3] > p[k_idx]) l_idx = 3;
            else if (p[2] > p[k_idx]) l_idx = 2;
            else if (p[1] > p[k_idx]) l_idx = 1;
            else if (p[0] > p[k_idx]) l_idx = 0;
            
            // Swap p[k] and p[l]
            p_temp[k_idx] = p[l_idx];
            p_temp[l_idx] = p[k_idx];
            
            // Reverse sequence from k+1 to end
            // Original: k+1 to 3.
            // p_temp currently has swapped values, need to reverse sub-segment.
            // k+1=0->1, 1->2, 2->3. 
            // Logic: swap p_temp[3] with p_temp[k+1], p_temp[2] with p_temp[k+2], etc.
            // Specifically, if k=2, reverse [3]. If k=1, swap 2 and 3. If k=0, swap 1,2 with 3,2? No, swap 1<->3, 2 remains?
            // Standard: Reverse p[k+1] to p[end].
            
            if (k_idx == 0) begin // k=0, swap [1,2,3] -> [3,2,1]
                p_temp[1] = p[3]; 
                p_temp[3] = p[1]; // Wait, p[3] was stored in p_temp[3] before swap? 
                // Let's re-evaluate. 
                // p = 0,1,2,3. k=0. l=3 (since p[3]>p[0]).
                // Swap p[0] and p[3]: p_temp = 3,1,2,0.
                // Reverse 1..3: 1,2,0 -> 0,2,1.
                // Result: 3,0,2,1.
                
                // Correct way: perform swap first on a copy, then reverse.
                // Let's use p_temp as the swap result then reverse.
                
                // Re-calculate l for safety inside the block or assume it's correct from above.
                // Actually, let's use simple logic for N=4.
                // It's easier to implement a simple counter for 0..23 and decode, avoiding complex next_perm logic.
                // Let's switch to Counter + Decode approach for reliability.
            end
        end
    end

    // CHANGED APPROACH: Instead of complex next_permutation combinational logic,
    // use a counter (0 to 23) and decode to permutation.
    // This is more hardware friendly for small N=4 and avoids valid state transitions.
    // The code below overrides the combinational logic above by using specific state logic.
    
    // Re-implementation of State Logic for Permutation Generation:
    // INIT: Set counter=0.
    // CHECK_PERMUTATION: Decode counter to permutation P.
    // Check Valid(P).
    // If valid -> CALCULATE.
    // If invalid -> Increment counter, if counter==24 -> DONE, else Check again (or in parallel).
    // UPDATE_MIN: Increment counter. If counter==24 -> DONE, else CHECK_PERMUTATION.
    
    // We will keep the top-level state machine but modify the specific actions.
    // The 'p' register will now store the decoded current permutation.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_cost <= 16'hFFFF;
            counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= INIT;
                    done <= 1'b0;
                end
                
                INIT: begin
                    min_cost <= 16'hFFFF;
                    counter <= 4'd0;
                    state <= CHECK_PERMUTATION;
                    // Decode 0 to p
                    {p[0], p[1], p[2], p[3]} <= 12'b001_010_011_000; // 0,1,2,3 (MSB first is 0? No, p[0] is index 0)
                    // Let's say p[0]=0, p[1]=1, p[2]=2, p[3]=3
                    p[0] <= 0; p[1] <= 1; p[2] <= 2; p[3] <= 3;
                end
                
                CHECK_PERMUTATION: begin
                    // Decode logic for next state is combinational. 
                    // In this state, 'p' holds the permutation for 'counter-1' (or 0 from INIT).
                    // Wait, if counter=0 from INIT, p is set to 0,1,2,3.
                    // We check that.
                    // If valid -> CALCULATE.
                    // If invalid -> increment counter, update p, if counter==24 -> DONE, stay in CHECK or go DONE.
                    
                    if (valid) begin
                        state <= CALCULATE_COST;
                    end else begin
                        // Skip invalid
                        if (counter < 5'd23) begin
                            counter <= counter + 1'b1;
                            // Update p for next iteration immediately to save a cycle
                            p <= p_temp;
                            state <= CHECK_PERMUTATION;
                        end else begin
                            // Counter is 23, and this one is invalid. We are done.
                            state <= DONE;
                        end
                    end
                end
                
                CALCULATE_COST: begin
                    // current_cost = calculate(p)
                    current_cost <= temp_cost;
                    state <= UPDATE_MIN;
                end
                
                UPDATE_MIN: begin
                    if (temp_cost < min_cost) min_cost <= temp_cost;
                    
                    // Move to next permutation
                    if (counter < 5'd23) begin
                        counter <= counter + 1'b1;
                        p <= p_temp;
                        state <= CHECK_PERMUTATION;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (start) state <= IDLE; // Reset on start press if needed, or wait for external reset
                end
            endcase
        end
    end

    // Combinational Logic for Decoding Counter to Permutation
    // p_temp = Permutation(counter)
    always @(*) begin
        // Standard method: treat counter as index into a precomputed table.
        // Or generate iteratively. 
        // Let's generate the "next" permutation of current p for UPDATE_MIN/CHECK transitions.
        // In CHECK_PERMUTATION, if we failed, we need p_next.
        // In UPDATE_MIN, we always need p_next.
        // p holds current permutation based on counter (or counter-1).
        
        // Actually, let's just decode 'counter + 1' directly to p_temp in CHECK and UPDATE.
        // But we need to update 'p' register. 
        // If we use 'counter + 1' logic, we need to handle the base case.
        
        // Let's implement a simple logic: 
        // If we are in CHECK_PERMUTATION and !valid, we increment counter and decode.
        // If we are in UPDATE_MIN, we increment counter and decode.
        
        // So, p_temp always corresponds to Permutation(counter + 1).
        // This works if we update 'p' with p_temp at the same time we increment 'counter'.
        
        // Decoding logic for index 'counter + 1':
        reg [3:0] idx_dec;
        idx_dec = counter + 1'b1;
        
        // Mapping 0..23 to permutations of [0,1,2,3]
        // We can use a simplified mapping or a generic next_perm logic on a generic base.
        // Let's use the logic: Base permutation B = sorted [0,1,2,3]. 
        // We want the idx_dec-th permutation of B.
        // Factorial number system (Lehmer code) is good here.
        
        // Factorial values: 0!0, 1!0, 2!2, 3!6.
        // d0 = idx / 6, d1 = (idx % 6) / 2, d2 = (idx % 6 % 2) / 1.
        // Let's use combinational logic for this.
        
        reg [1:0] d0, d1, d2;
        reg [2:0] list [0:3];
        
        // d0 = idx_dec / 6
        d0 = (idx_dec >= 12) ? 2'd2 : (idx_dec >= 6) ? 2'd1 : 2'd0;
        
        // Remainder for d1
        reg [3:0] rem1;
        if (idx_dec >= 12) rem1 = idx_dec - 12;
        else if (idx_dec >= 6) rem1 = idx_dec - 6;
        else rem1 = idx_dec;
        
        // d1 = rem1 / 2
        d1 = (rem1 >= 2) ? 2'd1 : 2'd0;
        
        // Remainder for d2
        reg [3:0] rem2;
        rem2 = rem1 - (d1 * 2);
        d2 = rem2[1:0]; // 0 or 1
        
        // Now construct list [0,1,2,3]
        list[0] = 0; list[1] = 1; list[2] = 2; list[3] = 3;
        
        // p_temp[0] = list[d0]; remove list[d0]
        // p_temp[1] = list[d1]; remove list[d1] (from remaining)
        // p_temp[2] = list[d2]; remove list[d2]
        // p_temp[3] = list[last]
        
        p_temp[0] = list[d0];
        // Remaining: Shift list logic or mux
        // We need to select from {0,1,2,3} excluding d0.
        // To keep logic simple for small N, we can just use a case statement for all 24 states? 
        // Or use the list removal logic.
        
        // Helper logic for removal:
        // We have list = {0,1,2,3}
        // Remove d0. Let's say d0=2. List becomes {0,1,3}.
        // d1 index applies to this reduced list.
        
        // Let's use the standard removal logic:
        // I will use a small generate block or just explicit muxes since N is tiny.
        
        // p_temp[1] selection:
        // If d1 >= d0, select d1+1 from original set, else d1.
        // Wait, original set is fixed {0,1,2,3}.
        // We need to map d1 (0..1) to the remaining 3 elements.
        // This is the "factorial number system to permutation" mapping.
        
        // Let's just use a LUT for simplicity and reliability, or the explicit algorithm.
        // Explicit algorithm for N=4 is hard to write in 20 lines of Verilog without bugs.
        // Let's use the LUT approach. 24 entries is small.
        // We need to generate p_temp[0], p_temp[1], p_temp[2], p_temp[3].
        
        // Since we can't define a 24x12 ROM easily in one line without generate, let's use logic.
        // We will implement the "next permutation" logic correctly this time, as it's generic.
        // The previous attempt failed because of variable scope/usage in the combinational block.
        // Let's implement it carefully.
        
        // Next Permutation Logic (given p, generate p_temp):
        // 1. Find largest k where p[k] < p[k+1].
        // 2. Find largest l > k where p[l] > p[k].
        // 3. Swap p[k], p[l].
        // 4. Reverse p[k+1]..p[end].
        
        // We implement this step-by-step in combinational always block.
        // We need temporary variables for index finding.
        
        // Reset p_temp to p (default)
        p_temp[0] = p[0];
        p_temp[1] = p[1];
        p_temp[2] = p[2];
        p_temp[3] = p[3];
        
        // Step 1: Find k
        // k = -1 initially
        reg signed [2:0] k_val;
        k_val = -1;
        if (p[2] < p[3]) k_val = 2;
        else if (p[1] < p[2]) k_val = 1;
        else if (p[0] < p[1]) k_val = 0;
        
        if (k_val != -1) begin
            // Step 2: Find l
            reg signed [2:0] l_val;
            l_val = -1;
            // Search from end
            if (p[3] > p[k_val]) l_val = 3;
            else if (p[2] > p[k_val]) l_val = 2;
            else if (p[1] > p[k_val]) l_val = 1;
            else if (p[0] > p[k_val]) l_val = 0;
            
            // Step 3: Swap
            p_temp[k_val] = p[l_val];
            p_temp[l_val] = p[k_val];
            
            // Step 4: Reverse k+1 to end
            // We need to reverse the subarray in p_temp.
            // Since p_temp has the swap, we can just swap symmetric elements around the center.
            // Indices: 0,1,2,3. k_val can be 0,1,2.
            // If k=0, swap 1<->3. (Indices 1 and 3). 2 stays.
            // If k=1, swap 2<->3. (Indices 2 and 3).
            // If k=2, no swap (length 1).
            
            if (k_val == 0) begin
                // swap p_temp[1] and p_temp[3]
                p_temp[1] = p_temp[3]; // Wait, p_temp[1] currently has p[1], p_temp[3] has p[0].
                // We need to be careful. 
                // Original p: 0,1,2,3. k=0 (0<1). l=3 (3>0).
                // Swap: p_temp = 3,1,2,0.
                // Reverse 1..3: sequence 1,2,0 -> 0,2,1.
                // Result: 3,0,2,1.
                
                // Let's perform swap first on p_temp.
                // p_temp is already p. 
                // Swap p_temp[0] and p_temp[3]: 
                // temp = p_temp[0]; p_temp[0] = p_temp[3]; p_temp[3] = temp;
                // Now p_temp = 3,1,2,0.
                // Now reverse indices 1 to 3.
                // Swap p_temp[1] and p_temp[3]: 3,0,2,1. Correct.
                
                // Let's rewrite this block cleanly.
                // First, swap k and l
                p_temp[k_val] = p[l_val];
                p_temp[l_val] = p[k_val];
                
                // Then reverse
                if (k_val == 0) begin
                    // swap 1 and 3
                    p_temp[1] = p_temp[3]; // Store p_temp[3] (which is p[0]) in temp? No, direct swap needs temp or simultaneous assignment.
                    // We can't do p_temp[1] = p_temp[3] then p_temp[3] = p_temp[1] (old).
                    // We need to use intermediate values or sequential logic.
                    // Since we are in combinational block, let's compute final values explicitly.
                end
            end
        end
    end

    // Corrected Combinational Next Permutation Logic
    // To avoid variable overwriting issues in the block above, we compute p_temp explicitly.
    // Let's assume the block above is problematic and replace it.
    // We will use the fact that we can compute p_temp based on 'p'.
    
    // Re-write the p_temp combinational block:
    always @(*) begin
        // Default: same as p
        p_temp[0] = p[0]; p_temp[1] = p[1]; p_temp[2] = p[2]; p_temp[3] = p[3];
        
        // Find k
        reg signed [2:0] k;
        k = -1;
        if (p[2] < p[3]) k = 2;
        else if (p[1] < p[2]) k = 1;
        else if (p[0] < p[1]) k = 0;
        
        if (k != -1) begin
            // Find l
            reg signed [2:0] l;
            l = -1;
            // Search from end (index 3 down to k+1)
            if (p[3] > p[k]) l = 3;
            else if (p[2] > p[k]) l = 2;
            else if (p[1] > p[k]) l = 1;
            else if (p[0] > p[k]) l = 0;
            
            // Perform Swap
            // We need temporary variables for the swap values to avoid overwriting
            reg [2:0] val_k, val_l;
            val_k = p[k];
            val_l = p[l];
            
            // Construct swapped version
            reg [2:0] p_swapped [0:3];
            p_swapped[0] = p[0]; p_swapped[1] = p[1]; p_swapped[2] = p[2]; p_swapped[3] = p[3];
            p_swapped[k] = val_l;
            p_swapped[l] = val_k;
            
            // Reverse k+1 to end
            // k=0 -> rev 1..3 (indices 1,2,3)
            // k=1 -> rev 2..3 (indices 2,3)
            // k=2 -> rev 3..3 (index 3)
            
            if (k == 0) begin
                p_temp[0] = p_swapped[0];
                p_temp[1] = p_swapped[3];
                p_temp[2] = p_swapped[2];
                p_temp[3] = p_swapped[1];
            end else if (k == 1) begin
                p_temp[0] = p_swapped[0];
                p_temp[1] = p_swapped[1];
                p_temp[2] = p_swapped[3];
                p_temp[3] = p_swapped[2];
            end else if (k == 2) begin
                p_temp[0] = p_swapped[0];
                p_temp[1] = p_swapped[1];
                p_temp[2] = p_swapped[2];
                p_temp[3] = p_swapped[3];
            end
        end
    end

endmodule
