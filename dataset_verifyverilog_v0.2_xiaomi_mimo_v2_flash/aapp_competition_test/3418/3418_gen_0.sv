module lucky_numbers_supply (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] supply,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam COUNTING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] curr_pos;
    reg [3:0] next_pos;
    reg [31:0] supply_reg; // Accumulated sum of valid sequences
    reg [31:0] next_supply;
    
    // Current DP state: array of 8 counters (max remainder 7)
    // dp_counts[i] holds count for remainder i at current position
    reg [31:0] curr_counts [0:7];
    reg [31:0] next_counts [0:7];
    
    // Intermediate computation wires
    integer i, d;
    reg [7:0] valid_digits; // Bitmask for valid starting digits (1-9)
    
    // Temporary storage for partial sums to handle accumulation in one cycle
    reg [31:0] term_sum; 
    reg [31:0] temp_sum;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            curr_pos <= 4'd0;
            supply <= 32'd0;
            done <= 1'b0;
            // Reset counts
            for (i = 0; i < 8; i = i + 1) begin
                curr_counts[i] <= 32'd0;
            end
            supply_reg <= 32'd0;
        end else begin
            state <= next_state;
            curr_pos <= next_pos;
            supply <= next_supply;
            
            // Update current counts from next_counts logic
            for (i = 0; i < 8; i = i + 1) begin
                curr_counts[i] <= next_counts[i];
            end
            
            supply_reg <= next_supply;
            
            // Done flag logic
            if (next_state == DONE) done <= 1'b1;
            else done <= 1'b0;
        end
    end

    // Combinational Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_pos = curr_pos;
        next_supply = supply_reg;
        
        // Default next counts to 0
        for (i = 0; i < 8; i = i + 1) begin
            next_counts[i] = 32'd0;
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COUNTING;
                    next_pos = 4'd1; // Start at position 1
                    next_supply = 32'd0;
                    
                    // Initialize counts for Position 1
                    // Digits 1-9. Remainder = digit % 1 = 0 for all.
                    // So we start with 9 valid sequences at remainder 0.
                    for (i = 0; i < 8; i = i + 1) begin
                        next_counts[i] = 32'd0;
                    end
                    next_counts[0] = 32'd9;
                end else begin
                    next_supply = supply_reg; // Keep output stable
                    for (i = 0; i < 8; i = i + 1) begin
                        next_counts[i] = curr_counts[i];
                    end
                end
            end

            COUNTING: begin
                // Perform DP transition for current position: curr_pos -> curr_pos + 1
                // Transition logic: next_counts[new_rem] += curr_counts[old_rem] (for each valid digit)
                
                // Optimization: Calculate full transition table in a loop
                // Position P means we are checking divisibility by P
                // Current counts correspond to sequences of length (P-1)
                // We append digits to form length P.
                
                // Since we need to sum multiple contributions to the same next_counts index,
                // we use a combinational block.
                
                // Determine valid digits for the current step
                // If curr_pos == 1, digits are 1-9. Else 0-9.
                if (curr_pos == 4'd1) valid_digits = 8'b111111110; // 1..9 (indices 1..9)
                else valid_digits = 8'b1111111111; // 0..9 (indices 0..9)

                // Compute next_counts
                // We manually unroll/loop over remainders and digits to satisfy "one cycle" latency
                // Max remainder at position P is P-1.
                
                for (i = 0; i < 8; i = i + 1) begin : loop_rems
                    // Only process valid remainders for current position range
                    if (i < curr_pos) begin
                        if (curr_counts[i] != 0) begin
                            for (d = 0; d <= 9; d = d + 1) begin : loop_digits
                                if (valid_digits >> d) begin
                                    // Check if digit d is valid for next position
                                    // Condition: (current_val * 10 + d) % (curr_pos + 1) == 0
                                    // current_val % (curr_pos + 1) is not necessarily i
                                    // But current_val = i (mod curr_pos)
                                    // We need to compute new_val % (curr_pos + 1)
                                    // Formula: new_val % (curr_pos + 1) = (i * 10 + d) % (curr_pos + 1)
                                    
                                    // To check validity: (i * 10 + d) % (curr_pos + 1) == 0
                                    // Since curr_pos is small, we can precalculate this condition
                                    // using a case statement for efficiency or let synthesis handle the math.
                                    
                                    // Let's calculate mod manually for specific P to be safe and fast.
                                    // We need to add curr_counts[i] to the remainder index
                                    // corresponding_indexb target = indices
 +(curr next);
                                    dp input ( check index next's param                                                            curr)].
                                    remain't remainder // if
                                        to
 next valid curr
;) = case /* 
                                    // Counter).
                                    curr_pos + )
                                    index
 addedition4 
                                    _next_{ else
 
                                    if (((i * 10 + d) % (curr_pos + 1)) == 0) begin
                                        next_counts[(i * 10 + d) % (curr_pos + 1)] = next_counts[(i * 10 + d) % (curr_pos + 1)] + curr_counts[i];
                                    end
                                end
                            end
                        end
                    end
                end

                // Update position and state
                if (curr_pos < n) begin
                    next_pos = curr_pos + 1;
                    
                    // Accumulate supply if we just finished a position
                    // Specification: "Output the sum of counts after position n"
                    // If we are moving to n, we are not done yet. We are done when we move to n+1 (or handle at n).
                    // Actually, the loop goes 1 -> n.
                    // At start of cycle (pos P), we are calculating P+1.
                    // Wait, let's trace:
                    // Start (IDLE) -> pos 1 (counts of 1-digit numbers). 
                    // Cycle 1: Compute 2-digit numbers. Update pos to 2. 
                    // Cycle k: Compute (k+1)-digit numbers. Update pos to k+1.
                    // We want result after n digits.
                    // So when we finish computing n digits, we are done.
                    // If n=1, we should be done immediately after IDLE or after 1 cycle?
                    // The problem says counts sequences of n digits.
                    // IDLE sets counts for 1 digit. 
                    // If n=1, the answer is sum of counts at position 1 (which is 9).
                    // If we transition to COUNTING with pos=1, we haven't computed anything yet.
                    // Logic:
                    // State: IDLE -> COUNTING. pos=1. counts=(9,0,...). 
                    // If n=1, we should go to DONE immediately? 
                    // "Result valid approx 64 cycles" implies a sequential process. 
                    // Let's assume we perform the iteration loop n-1 times.
                    // Iteration 1: pos=1 -> pos=2. 
                    // Iteration n-1: pos=n-1 -> pos=n.
                    // At the end of iteration n-1, we have counts for length n.
                    // We sum them up and go to DONE.
                    
                    if (curr_pos == n - 1) begin
                        next_state = DONE;
                        // Sum up next_counts (which now hold valid sequences of length n)
                        temp_sum = 0;
                        for (int j = 0; j < 8; j = j + 1) begin
                            if (j < n) temp_sum = temp_sum + next_counts[j];
                        end
                        next_supply = temp_sum;
                    end else begin
                        next_state = COUNTING;
                        // Accumulate supply? 
                        // "Output the sum of counts after position n" usually implies final sum.
                        // But let's accumulate if required? "Sum of counts after position n". 
                        // Wait, example: n=2, answer 45. n=3, answer 150.
                        // n=1: 9.
                        // Let's check accumulation logic.
                        // If we need sum of counts at every step? "Sum of counts after position n".
                        // This sounds like final sum. But let's look at example.
                        // n=2. 1-digit: 9. 2-digit: 45.
                        // Total sum of valid numbers of length 1 and 2? 
                        // Example says 45 for n=2. That's just 2-digit lucky numbers.
                        // So "sum of counts after position n" means sum of counts for length n.
                        // No accumulation across n. Just final result.
                    end
                end 
                else begin
                    // Should not happen if n <= 8 and logic is correct, 
                    // but if n=1, we enter with pos=1, and we need to be done.
                    // The condition `curr_pos < n` handles n>1.
                    // If n=1:
                    // IDLE -> COUNTING (pos=1). 
                    // In COUNTING block: curr_pos=1. n=1. Condition `curr_pos < n` is false.
                    // So we go to else.
                    next_state = DONE;
                    // Sum counts for pos=1 (length 1)
                    temp_sum = 0;
                    for (int j = 0; j < 8; j = j + 1) begin
                        if (j < n) temp_sum = temp_sum + curr_counts[j];
                    end
                    next_supply = temp_sum;
                end
            end

            DONE: begin
                // Hold state
                next_state = DONE;
                next_supply = supply_reg; // Keep result stable
                // Keep counts if needed, or don't care
                for (i = 0; i < 8; i = i + 1) begin
                    next_counts[i] = curr_counts[i];
                end
                
                // If start is low, maybe return to IDLE? 
                // Standard design usually requires reset or a specific handshake.
                // Let's implement a simple handshake: stay DONE until reset.
                // Or wait for start to go low? "start computation" suggests pulse.
                // Let's stay DONE.
            end

            default: begin
                next_state = IDLE;
                next_supply = 32'd0;
            end
        endcase
    end

endmodule