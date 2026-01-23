module antique_shopping (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [3:0] antique_orig_shop [3:0],
    input [23:0] antique_orig_price [3:0],
    input [3:0] antique_knock_shop [3:0],
    input [23:0] antique_knock_price [3:0],
    output reg [23:0] min_cost,
    output reg valid,
    output reg done
);

    // Parameters
    parameter N = 4;
    parameter M = 8;
    parameter MAX_K = 3;
    parameter INF = 24'hFFFFFF;

    // States
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        CHECK_COMBINATION = 3'b001,
        VALIDATE = 3'b010,
        COMPUTE_COST = 3'b011,
        UPDATE_MIN = 3'b100,
        DONE = 3'b101
    } state_t;

    state_t current_state, next_state;

    // Registers for iteration control
    reg [2:0] current_k;
    reg [7:0] subset_mask; // Bitmask representing the subset of shops (M=8)
    reg [2:0] subset_size_idx; // Index for subset_size loop (1 to k)
    reg [7:0] shop_idx; // Index for iterating shops in subset
    reg [2:0] antique_idx; // Index for iterating antiques
    
    // Registers for cost computation
    reg [23:0] current_total_cost;
    reg [23:0] current_min_price;
    reg is_available;
    
    // Combinational helper signals
    reg valid_subset;
    reg [23:0] computed_cost;
    reg [23:0] min_cost_next;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = CHECK_COMBINATION;
            end
            
            CHECK_COMBINATION: begin
                // Check if current subset_mask has correct popcount (size)
                // For M=8 and MAX_K=3, simple comparison is efficient
                if (popcount(subset_mask) == subset_size_idx) begin
                    next_state = VALIDATE;
                end else begin
                    // Keep searching for valid mask
                    next_state = CHECK_COMBINATION;
                end
            end
            
            VALIDATE: begin
                if (valid_subset) begin
                    next_state = COMPUTE_COST;
                end else begin
                    next_state = UPDATE_MIN; // Skip cost calc, just move to next combo
                end
            end
            
            COMPUTE_COST: begin
                if (antique_idx < N) begin
                    next_state = COMPUTE_COST; // Continue loop
                end else begin
                    next_state = UPDATE_MIN;
                end
            end
            
            UPDATE_MIN: begin
                // Logic to move to next combination or next subset size or done
                // This is handled in the sequential block to ensure correct transition
                if (subset_size_idx > k) begin
                    next_state = DONE;
                end else if (subset_size_idx == k && subset_mask == 0) begin
                    next_state = DONE; // All combinations exhausted
                end else begin
                    next_state = CHECK_COMBINATION;
                end
            end
            
            DONE: begin
                // Stay in done until reset or start
                if (start) next_state = IDLE; // Or restart if needed, but typically stay until reset
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output Logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_cost <= INF;
            valid <= 1'b0;
            done <= 1'b0;
            subset_mask <= 8'b00000001; // Start with shop 0 (LSB)
            subset_size_idx <= 3'd1;
            current_k <= 3'd0;
            antique_idx <= 3'd0;
            current_total_cost <= 0;
            current_min_price <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        min_cost <= INF;
                        done <= 1'b0;
                        valid <= 1'b0;
                        current_k <= k;
                        subset_size_idx <= 3'd1;
                        subset_mask <= 8'b00000001; // Start with shop 0
                        // If k=0 immediately done, but constraints say 1-3
                    end
                end

                CHECK_COMBINATION: begin
                    // Generate next valid combination mask if current doesn't match size
                    if (popcount(subset_mask) != subset_size_idx) begin
                        subset_mask <= next_combination(subset_mask);
                    end
                    // Reset antique iterator for validation/computation
                    antique_idx <= 3'd0;
                    current_total_cost <= 0;
                end

                VALIDATE: begin
                    // Validation logic is combinational (valid_subset)
                    // If valid, we move to compute, else we need to get next combination immediately
                    if (!valid_subset) begin
                        // Need to advance to next combination for the next CHECK_COMBINATION state
                        // We do this here to pipeline the "skip invalid" logic
                        if (popcount(subset_mask) != subset_size_idx) begin
                            // This condition shouldn't be met if we entered VALIDATE, but safety check
                            subset_mask <= next_combination(subset_mask);
                        end else begin
                            subset_mask <= next_combination(subset_mask);
                        end
                    end
                    // If valid, we stay in flow, antique_idx is 0
                end

                COMPUTE_COST: begin
                    if (antique_idx < N) begin
                        // Accumulate cost logic (combinational helper used here for update)
                        if (is_available) begin
                            current_total_cost <= current_total_cost + current_min_price;
                        end
                        antique_idx <= antique_idx + 1;
                    end
                end

                UPDATE_MIN: begin
                    // Update min_cost if the subset was valid and computed
                    // We need to know if it was valid. valid_subset is combo, but we need to know result of check.
                    // Use is_available (set in compute) or valid_subset.
                    // If we came from VALIDATE->UPDATE_MIN (invalid), we skip.
                    // If we came from COMPUTE->UPDATE_MIN (valid), we update.
                    // To distinguish, let's check if antique_idx == N (valid subset completion)
                    if (valid_subset && antique_idx == N) begin
                        if (current_total_cost < min_cost) begin
                            min_cost <= current_total_cost;
                        end
                    end

                    // Advance iteration
                    // If subset_mask becomes 0, it means we overflowed (ran out of combinations)
                    if (subset_mask == 8'b0) begin
                        // Finished all combinations for current size
                        subset_size_idx <= subset_size_idx + 1;
                        if (subset_size_idx + 1 > current_k) begin
                            // Done, do nothing, next state is DONE
                        end else begin
                            subset_mask <= 8'b00000001; // Reset for next size
                        end
                    end else begin
                        // Still combinations left for this size
                        // subset_mask was already updated in VALIDATE or here if valid
                        // If we didn't update it in VALIDATE (because it was valid), we must do it now
                        if (valid_subset) begin
                             subset_mask <= next_combination(subset_mask);
                        end
                        // If invalid, it was already updated in VALIDATE state
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    if (min_cost == INF) begin
                        min_cost <= 24'hFFFFFF; // Return -1 (0xFFFFFF)
                    end
                end
            endcase
        end
    end

    // Combinational Logic for Validation and Cost calculation
    always @(*) begin
        // Default values
        valid_subset = 1'b1;
        is_available = 1'b0;
        current_min_price = INF;
        
        // 1. Validation Logic (Check if all antiques are covered by subset_mask)
        // Only relevant in VALIDATE state, but calculate continuously
        for (int i = 0; i < N; i++) begin
            logic orig_in_subset = 1'b0;
            logic knock_in_subset = 1'b0;
            
            if (antique_orig_shop[i] < M) begin
                if (subset_mask[antique_orig_shop[i]]) orig_in_subset = 1'b1;
            end
            if (antique_knock_shop[i] < M) begin
                if (subset_mask[antique_knock_shop[i]]) knock_in_subset = 1'b1;
            end
            
            if (!orig_in_subset && !knock_in_subset) begin
                valid_subset = 1'b0;
            end
        end

        // 2. Cost Calculation Logic (Used in COMPUTE_COST state)
        // We calculate for 'antique_idx'
        if (current_state == COMPUTE_COST || current_state == UPDATE_MIN) begin
            if (antique_idx < N) begin
                logic orig_in = 1'b0;
                logic knock_in = 1'b0;
                logic [23:0] p_orig = INF;
                logic [23:0] p_knock = INF;
                
                if (antique_orig_shop[antique_idx] < M && subset_mask[antique_orig_shop[antique_idx]]) begin
                    orig_in = 1'b1;
                    p_orig = antique_orig_price[antique_idx];
                end
                
                if (antique_knock_shop[antique_idx] < M && subset_mask[antique_knock_shop[antique_idx]]) begin
                    knock_in = 1'b1;
                    p_knock = antique_knock_price[antique_idx];
                end
                
                if (orig_in || knock_in) begin
                    is_available = 1'b1;
                    current_min_price = (p_orig < p_knock) ? p_orig : p_knock;
                end else begin
                    is_available = 1'b0;
                    current_min_price = INF;
                end
            end
        end
    end

    // Helper functions for subset generation
    // Count set bits in 8-bit mask
    function automatic logic [2:0] popcount(input logic [7:0] val);
        logic [2:0] count = 0;
        for (int i = 0; i < 8; i++) begin
            if (val[i]) count = count + 1;
        end
        return count;
    endfunction

    // Generate next combination (Gosper's hack is efficient, but for M=8 simple shifting is fine)
    // Or use a simple loop to find next integer with same popcount
    function automatic logic [7:0] next_combination(input logic [7:0] current);
        logic [7:0] next;
        logic found = 0;
        logic [2:0] target_pop;
        target_pop = popcount(current);
        
        // Start from next bit pattern
        next = current + 1;
        // Search for next number with same popcount
        // Unroll loop for synthesis efficiency or let synthesizer handle
        // Since M is small (8), we can iterate quickly or use property:
        // Find lowest set bit, clear it, set next higher bit, move remaining lower bits to LSB
        
        // Use standard algorithm for next lexicographic permutation of bits
        // Gosper's hack or similar
        logic [7:0] v = current;
        logic [7:0] w;
        logic [7:0] t;
        
        // Gosper's hack for 8 bits
        // t = v | (v - 1); // t gets 00..0111 if v=000..001 etc
        // w = (t + 1) | (((~t & -~t) - 1) >> (trailing_zeros(v) + 1));
        // Simplified for M=8:
        
        if (v == 0) return 0;
        
        logic [2:0] r;
        logic [2:0] c;
        logic [7:0] u;
        logic [7:0] v_plus_1;
        
        v_plus_1 = v + 1;
        r = 0;
        
        // This is a simple brute force lookup or simpler iteration since 8 is small.
        // However, standard comb logic functions must be pure.
        // Let's use the bit manipulation approach.
        
        // t = v | (v - 1);
        // w = (t + 1) | (((~t & -~t) - 1) >> (c + 1));
        
        // Since this is for simulation/synthesis of small M, let's use a simpler approach:
        // Just find the next integer of the same population count.
        // We can do this by checking bits.
        
        // 1. Find the rightmost 1 that has a 0 to its left.
        // 2. Shift that 1 left.
        // 3. Move all 1s to its right to the far right.
        
        logic [7:0] lo, lz;
        lo = v ^ (v - 1); // Isolate lowest set bit and trailing zeros: ...01111
        // Actually lo = v & -v is lowest set bit.
        // Let's stick to the known "next combination of same weight" logic.
        
        // c = v;
        // c = c - ((c >> 1) & 32'h55555555);
        // ... standard bit count to get popcount c.
        // For 8 bits, let's just unroll the search for synthesis simplicity if allowed, 
        // but synthesized logic usually dislikes while loops.
        
        // Algorithm:
        // 1. Smallest = v & -v
        // 2. Ripple = v + smallest
        // 3. Ones = v ^ ripple
        // 4. Ones = (Ones >> 2) / smallest
        // 5. Result = ripple | Ones
        
        logic [7:0] smallest = v & -v;
        logic [7:0] ripple = v + smallest;
        logic [7:0] ones = v ^ ripple;
        ones = ones >> 2;
        // Divide by smallest (power of 2). Shifting.
        // Smallest is 2^N. shift right by N.
        // Find trailing zeros of smallest.
        logic [2:0] shift_amt;
        shift_amt = 0;
        if (smallest[0]) shift_amt = 1;
        else if (smallest[1]) shift_amt = 2;
        else if (smallest[2]) shift_amt = 3;
        else if (smallest[3]) shift_amt = 4;
        else if (smallest[4]) shift_amt = 5;
        else if (smallest[5]) shift_amt = 6;
        else if (smallest[6]) shift_amt = 7;
        else shift_amt = 0;
        
        // The division by smallest (2^N) requires shift right by N. 
        // But for 8 bits, if smallest is 1, shift 0. If 2, shift 1 etc.
        // Actually the formula is: result = ripple | (ones >> (2 + trailing_zeros(v)))
        // Let's just use the loop version for correctness in function, synthesizer will optimize.
        
        // To avoid complex bit manipulation errors, let's use a small loop for the function.
        // Note: Synthesizers usually unroll fixed-bound loops.
        logic [7:0] t_v = v;
        logic [7:0] t_w;
        logic [2:0] lsb_idx = 0;
        logic [2:0] first_zero_idx = 0;
        
        // Simple generator: iterate from current+1 to 255 and check popcount
        // Since M is 8, this is 256 max checks. In hardware this might be slow, 
        // but we are state-driven. The state machine waits for "CHECK_COMBINATION".
        // However, 256 cycle delay per step is too much (5000 total cycles budget).
        // So we need the bit-hack.
        
        // Verified Bit Hack (Gosper's Hack)
        logic [7:0] c_val = v;
        logic [7:0] r_val;
        
        // t = (c | (c - 1)) + 1;
        // w = t | ((((t & -t) / (c & -c)) >> 1) - 1);
        // Let's try another formulation: 
        // unsigned int t = v | (v - 1);
        // w = (t + 1) | (((~t & -~t) - 1) >> (__builtin_ctz(v) + 1));
        
        logic [7:0] t = v | (v - 1);
        logic [7:0] n = ~t;
        logic [7:0] n_lsb = n & -n; // Isolate LSB of n
        logic [7:0] n_lsb_minus_1 = n_lsb - 1;
        logic [2:0] v_ctz = 0;
        if (v[0]) v_ctz = 0;
        else if (v[1]) v_ctz = 1;
        else if (v[2]) v_ctz = 2;
        else if (v[3]) v_ctz = 3;
        else if (v[4]) v_ctz = 4;
        else if (v[5]) v_ctz = 5;
        else if (v[6]) v_ctz = 6;
        else if (v[7]) v_ctz = 7;
        
        // (t + 1) | ((n_lsb - 1) >> (v_ctz + 1))
        logic [7:0] res;
        res = (t + 1) | (n_lsb_minus_1 >> (v_ctz + 1));
        
        // Boundary check: if res has more bits than M or size exceeds k (handled by state machine)
        // Or if we generate all zeros (overflow).
        if (res == 0 || popcount(res) > MAX_K) begin
             // In real hardware, if we overflow, we return 0. State machine handles > k check.
             return 8'b0;
        end
        
        return res;
    endfunction

endmodule

module TopModule (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [3:0] antique_orig_shop [3:0],
    input [23:0] antique_orig_price [3:0],
    input [3:0] antique_knock_shop [3:0],
    input [23:0] antique_knock_price [3:0],
    output [23:0] min_cost,
    output valid,
    output done
);

    antique_shopping #(.N(4), .M(8), .MAX_K(3)) u_anti (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .k(k),
        .antique_orig_shop(antique_orig_shop),
        .antique_orig_price(antique_orig_price),
        .antique_knock_shop(antique_knock_shop),
        .antique_knock_price(antique_knock_price),
        .min_cost(min_cost),
        .valid(valid),
        .done(done)
    );

endmodule