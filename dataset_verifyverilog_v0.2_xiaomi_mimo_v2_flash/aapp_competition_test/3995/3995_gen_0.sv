module minimal_unique_substring_gen (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] k,
    output reg out_bit,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam GENERATING = 2'b01;
    localparam FINISHED = 2'b10;

    reg [1:0] state;
    reg [15:0] count;       // Counts generated bits (0 to n-1)
    reg [15:0] spacing;     // Calculated spacing
    reg [15:0] mod_count;   // Counter for repeating pattern
    
    // Edge detection for start to ensure single pulse processing if needed,
    // but behavior implies start triggers generation state.
    reg start_reg;
    wire start_pulse;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_reg <= 1'b0;
        else start_reg <= start;
    end
    assign start_pulse = start & ~start_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_bit <= 1'b0;
            done <= 1'b0;
            count <= 16'd0;
            spacing <= 16'd0;
            mod_count <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Calculate spacing immediately when start is asserted
                        // Assumption: (n - k) is non-negative and even based on problem statement
                        spacing <= (n - k) >> 1;
                        count <= 16'd0;
                        mod_count <= 16'd0;
                        
                        // Special case: n == k
                        if (n == k) begin
                            out_bit <= 1'b1;
                        end else begin
                            // If spacing > 0, start with '0' for index 0? 
                            // Rule: Repeating pattern '0' * (spacing-1) + '1'.
                            // This implies length of pattern is spacing.
                            // If spacing > 0, indices 0 to spacing-2 are '0', index spacing-1 is '1'.
                            if (spacing > 0) begin
                                if (spacing == 1) begin
                                    // Pattern "1", index 0 is '1'? No, rule is '0'*0 + '1' = '1'. So index 0 is '1'.
                                    // Wait, check logic below. For spacing=1, pattern length 1.
                                    // Index 0 is the '1'.
                                    // Let's handle the output generation for the first bit in GENERATING state.
                                    // We will output the bit for count=0 here if we transition.
                                    out_bit <= 1'b1; 
                                end else begin
                                    // spacing >= 2. Pattern: 00...01 (spacing-1 zeros, 1 one). Length spacing.
                                    // Index 0 is '0'.
                                    out_bit <= 1'b0;
                                end
                            end else begin
                                // spacing == 0. n = k. Handled above. 
                                // Should not reach here if n == k handled, but if n != k and spacing = 0, 
                                // it means n < k or mismatch. Assuming inputs valid, spacing >= 0.
                                // If spacing = 0 and n != k, behavior undefined. We output 0.
                                out_bit <= 1'b0;
                            end
                        end
                        
                        // Update mod_count for next bit
                        if (n == k) begin
                            mod_count <= 16'd0; // Irrelevant
                        end else begin
                            if (spacing > 0) begin
                                if (1 < spacing) mod_count <= 16'd1; // Next index 1 is '0' (if spacing>1)
                                else mod_count <= 16'd0; // Wrap
                            end
                        end
                        
                        state <= GENERATING;
                    end
                end

                GENERATING: begin
                    // We just generated the bit for 'count'. Now we prepare for 'count + 1'.
                    if (count == n - 1) begin
                        done <= 1'b1;
                        state <= FINISHED;
                    end else begin
                        count <= count + 1;
                        
                        // Determine next bit for count + 1
                        if (n == k) begin
                            out_bit <= 1'b1;
                        end else begin
                            // Pattern logic
                            if (spacing > 0) begin
                                if (mod_count == spacing - 1) begin
                                    // We were at the last index of pattern (the '1'), wrap to 0 ('0')
                                    // Actually, if we just output the bit for 'count', and mod_count was the index for that bit.
                                    // Wait, in IDLE we set mod_count for the NEXT bit (count 0). 
                                    // Let's re-verify state machine flow for bit generation.
                                    // 1. Update mod_count (index for current output generation, stored in out_bit)
                                    // 2. Output bit based on mod_count
                                    // 3. Increment count
                                    // 4. Prepare next mod_count
                                    
                                    // Let's stick to: out_bit is set based on 'count' (or internal state associated with count).
                                    // In IDLE: set out_bit for count 0, prepare mod_count for count 1.
                                    // In GENERATING: update count, update mod_count, set out_bit for new count.
                                    
                                    // Current loop iteration: we need to produce bit for 'count' (which was just updated or initialized).
                                    // So we need to compute bit based on current mod_count (which is index for 'count').
                                    
                                    // Revising flow inside GENERATING block to be clearer:
                                    // We calculate next bit based on current mod_count, then update state.
                                    
                                    // Current logic in IDLE sets out_bit for count=0.
                                    // Here in GENERATING, we need to update state for count++.
                                    
                                    if (mod_count == spacing - 1) begin
                                        out_bit <= 1'b0; // Next bit (index 0 of new pattern)
                                        mod_count <= 16'd0;
                                    end else begin
                                        mod_count <= mod_count + 1;
                                        if (mod_count == spacing - 2) out_bit <= 1'b1; // Next bit is '1' (index spacing-1)
                                        else out_bit <= 1'b0; // Next bit is '0'
                                    end
                                end else begin
                                    // Increment mod_count
                                    mod_count <= mod_count + 1;
                                    if (mod_count == spacing - 2) out_bit <= 1'b1;
                                    else out_bit <= 1'b0;
                                end
                                
                                // Compact logic:
                                // if (mod_count == spacing - 1) -> next mod_count = 0, next bit = 0
                                // else -> next mod_count = mod_count + 1, next bit = (next mod_count == spacing-1) ? 1 : 0
                                // Wait, bit is determined by the position.
                                // If we are generating bit for index 'i', bit = (i % spacing == spacing - 1) ? 1 : 0
                                // We track 'mod_count' which is 'count % spacing'.
                                
                                // Let's simplify:
                                // Update mod_count first:
                                if (mod_count == spacing - 1) mod_count <= 0;
                                else mod_count <= mod_count + 1;
                                
                                // Determine bit for the NEW count (count + 1):
                                if (mod_count == spacing - 2) out_bit <= 1'b1; // New count's mod will be spacing-1
                                else if (mod_count == spacing - 1) out_bit <= 1'b0; // New count's mod will be 0
                                else out_bit <= 1'b0; // New count's mod is < spacing-1
                            end else begin
                                // spacing == 0 (and n != k, handled in else). 
                                // Should not happen if n mod 2 == k mod 2 and n >= k > 0? 
                                // If k=n, we are in IDLE special case. 
                                // If k=n+2, spacing = -1. Problem statement says valid inputs.
                                out_bit <= 1'b0;
                            end
                        end
                    end
                end

                FINISHED: begin
                    // Stay here until reset or new start
                    if (start) begin
                        // Restart logic handled in IDLE transition if we go back, but usually we stay finished.
                        // To allow restart, we might need to clear done.
                        // Let's just hold done high.
                        done <= 1'b1;
                    end else begin
                        // Optional: clear done if reset not asserted? 
                        // Requirement: done high when n bits generated.
                    end
                end
            endcase
        end
    end

    // Fix for the output generation logic to be robust:
    // The logic above in GENERATING is slightly complex with off-by-one risks.
    // Let's use a single always block approach that is cleaner.
    
    // Redesign for synthesis robustness:
    // State machine triggers on posedge clk.
    
    // Re-written block:
    /*
    // This part replaces the previous always block. I will combine them conceptually in the final output.
    // The previous code has a logic flow that might be error prone with the 'count' update order.
    // Let's ensure 'out_bit' corresponds exactly to 'count'.
    // IDLE: count=0. Calculate bit0. Output bit0. Prepare count=1.
    // GENERATING: count=1. Calculate bit1. Output bit1. Prepare count=2.
    // So in GENERATING, we process the current 'count' to output bit.
    */

    // Revised Logic Implementation in the code block:
    // I will rewrite the combinational logic for output to ensure correctness.
    // Using the existing always block but ensuring 'out_bit' matches 'count'.
    
    // Actually, let's just provide the cleanest possible code based on the initial draft but with corrected flow.
    
    // The initial code provided in the thought trace has a potential synchronization issue:
    // In IDLE, it sets out_bit for count=0. Then transitions to GENERATING.
    // In GENERATING, it checks if (count == n-1). Since count was 0, if n=1, it works. 
    // If n>1, it increments count to 1. Then it calculates next out_bit (for count=1).
    // This seems correct for n>1.
    // However, for n=1, IDLE sets out_bit=1, count=0. State -> GENERATING. 
    // GENERATING: count=0, n-1=0. Condition true. State -> FINISHED. done=1.
    // This results in out_bit valid for 1 cycle, done valid next cycle. Correct.
    
    // What about the bit calculation?
    // In IDLE: count=0. mod_count initialized. out_bit set.
    // In GENERATING: we update mod_count for the NEXT bit (count+1) and set out_bit for that next bit.
    // This assumes out_bit is registered. IDLE sets out_bit[0]. GENERATING cycle 1 sets out_bit[1].
    // Correct.
    
    // One edge case: n=0? Logic handles count=0, n-1= -1 (unsigned wrap). If n=0, count reaches 0, n-1 is 65535. 
    // It will loop 65536 times. Inputs should be n > 0. Assume n >= 1.
    
    // Let's refine the combinational part for clarity in the final code to avoid nested ifs.
    // I will use the logic:
    // if (n==k) -> 1
    // else -> (mod_count == spacing - 1) ? 1 : 0
    // But careful: mod_count is the index of the bit being GENERATED (or just generated).
    // In GENERATING block, we calculate the bit for the NEXT count.
    // The 'mod_count' update logic should happen before the bit assignment to be correct for the new state.
    
    // Final Logic Check:
    // IDLE: 
    //   count=0. 
    //   mod_count = 0. 
    //   out_bit = (n==k) ? 1 : (spacing>0 ? (0==spacing-1 ? 1 : 0) : 0) -> for spacing=1, 0==0 -> 1. 
    //   Update mod_count for next: if (n!=k) mod_count = (mod_count == spacing-1) ? 0 : mod_count+1.
    // GENERATING:
    //   count increments.
    //   out_bit calculated from CURRENT mod_count (which is index for this new count).
    //   Update mod_count for next.
    
    // Wait, in IDLE I calculated out_bit for count=0. 
    // Then I calculated mod_count for count=1.
    // In GENERATING:
    //   count becomes 1.
    //   out_bit needs to be for count=1. 
    //   If I use the 'mod_count' calculated in IDLE (which is for count=1), then out_bit is correct.
    //   So, modify GENERATING to use the pre-calculated mod_count for the CURRENT count's output.
    //   Then update mod_count for the NEXT cycle.
    
    // Let's adjust the code slightly to be clearer.
    
    // 1. In IDLE:
    //    out_bit = get_bit(0);
    //    mod_count = get_next_mod(0);
    // 2. In GENERATING:
    //    count++;
    //    out_bit = get_bit_from_mod(mod_count);
    //    mod_count = get_next_mod(mod_count);
    
    // The previous code already did this logic structure but with mixed ordering.
    // To be safe and synthesizable, I will stick to a simple, explicit flow.
    
    // Let's refine the code within the always block to be strictly sequential.
    // I will replace the GENERATING block logic with a cleaner version.

endmodule

// Helper logic explanation (not in code):
// Bit generation function:
// if (n == k) return 1
// else return ( (i % spacing) == (spacing - 1) ) ? 1 : 0

module minimal_unique_substring_gen (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] k,
    output reg out_bit,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam GENERATING = 2'b01;
    localparam FINISHED = 2'b10;

    reg [1:0] state;
    reg [15:0] count;
    reg [15:0] spacing;
    reg [15:0] mod_val; // Stores (count % spacing) for the bit to be output in the next cycle

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_bit <= 1'b0;
            done <= 1'b0;
            count <= 16'd0;
            spacing <= 16'd0;
            mod_val <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        count <= 16'd0;
                        if (n == k) begin
                            out_bit <= 1'b1;
                            spacing <= 16'd0; // Not used, but clean
                            mod_val <= 16'd0;
                        end else begin
                            spacing <= (n - k) >> 1;
                            // Calculate output for bit 0
                            if (spacing == 1) out_bit <= 1'b1;
                            else out_bit <= 1'b0;
                            // Calculate mod_val for bit 1
                            if (spacing > 1) mod_val <= 16'd1;
                            else mod_val <= 16'd0;
                        end
                        state <= (n > 1) ? GENERATING : FINISHED;
                        if (n == 1) done <= 1'b1;
                    end
                end

                GENERATING: begin
                    count <= count + 1;
                    
                    if (count == n - 2) begin
                        state <= FINISHED;
                        done <= 1'b1;
                    end

                    // Determine output bit for current value of 'count' (which is now index 'count+1' logic-wise due to update)
                    // Actually, here we are preparing the bit for the NEXT cycle.
                    // The 'mod_val' stored from previous cycle corresponds to the index 'count + 1'.
                    
                    if (n == k) begin
                        out_bit <= 1'b1;
                    end else begin
                        // Output bit based on pre-calculated mod_val
                        if (mod_val == spacing - 1) out_bit <= 1'b1;
                        else out_bit <= 1'b0;

                        // Update mod_val for the NEXT bit
                        if (mod_val == spacing - 1) mod_val <= 16'd0;
                        else mod_val <= mod_val + 1;
                    end
                end

                FINISHED: begin
                    // Stay here
                    // To handle restart properly, we might need to clear done when start goes low? 
                    // Or just rely on start edge. For simplicity, we stay in FINISHED.
                    if (!start) done <= 1'b0; // Reset done when start is released
                    else done <= 1'b1;
                    
                    if (start) begin
                         // Restart logic if start is held high? 
                         // Usually we wait for start to go low then high.
                         // But here we stay in FINISHED until reset or start handled by IDLE logic.
                         // If start is still high, we stay here. 
                         // We need to exit FINISHED if start goes low.
                         // Let's add transition to IDLE when start is low.
                         if (!start) state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule