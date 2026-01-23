module sweet_diet(
    input clk,
    input rst_n,
    input start,
    input [2:0] m,
    input [15:0] a [0:7],
    input [15:0] s [0:7],
    input [15:0] n,
    output reg [15:0] additional_count,
    output reg forever_flag,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALC_SUM = 3'b001;
    localparam CHECK_BALANCE = 3'b010;
    localparam UPDATE_COUNT = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // Internal registers
    reg [15:0] sum_a_reg;
    reg [15:0] sum_a_next;
    reg [15:0] n_reg;
    reg [15:0] n_next;
    reg [15:0] s_reg [0:7];
    reg [15:0] s_next [0:7];
    reg [15:0] additional_count_reg;
    reg [15:0] additional_count_next;
    reg forever_flag_reg;
    reg forever_flag_next;
    reg done_reg;
    reg done_next;

    // Iterator indices
    reg [2:0] idx_calc;
    reg [2:0] idx_check;
    reg [2:0] type_idx; // used for checking which type to buy

    // Balance check registers
    reg [31:0] n_star_f_j; // n * f_j (Q32.32 but we only need high 16 bits for integer part)
    reg [31:0] s_j_plus_1_ext; // (s_j + 1) extended
    reg [31:0] n_star_f_j_ext; // n * f_j extended
    reg [31:0] diff_low;
    reg [31:0] diff_high;
    reg balance_ok; // flag for current type check
    reg any_type_valid; // flag if any type found valid in current step
    reg [2:0] valid_type_idx; // stores the index of a valid type to buy

    // Temporary storage for fractions f_i (Q16.16)
    reg [31:0] f_i [0:7];
    reg [31:0] f_i_next [0:7];

    // Counter for steps (max 256)
    reg [8:0] step_counter; // 0 to 256 (extra bit for overflow check)
    reg step_counter_reset;

    integer i;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic & Datapath
    always @(*) begin
        next_state = current_state;
        sum_a_next = sum_a_reg;
        n_next = n_reg;
        for (i = 0; i < 8; i = i + 1) begin
            s_next[i] = s_reg[i];
            f_i_next[i] = f_i[i];
        end
        additional_count_next = additional_count_reg;
        forever_flag_next = forever_flag_reg;
        done_next = done_reg;
        sum_a_next = sum_a_reg;
        
        step_counter_reset = 1'b0;

        case (current_state)
            IDLE: begin
                done_next = 1'b0;
                forever_flag_next = 1'b0;
                additional_count_next = 16'b0;
                if (start) begin
                    // Initialize internal registers from inputs
                    n_next = n;
                    for (i = 0; i < 8; i = i + 1) begin
                        s_next[i] = s[i];
                    end
                    step_counter_reset = 1'b1;
                    next_state = CALC_SUM;
                end
            end

            CALC_SUM: begin
                // Sum up a[0] to a[m-1]
                sum_a_next = 16'b0;
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < m) begin
                        sum_a_next = sum_a_next + a[i];
                    end
                end
                next_state = CHECK_BALANCE;
            end

            CHECK_BALANCE: begin
                // We need to calculate f_i for all types (if sum_a != 0)
                // This state performs the check for the current type_idx
                // If type_idx == 0, we might need to compute f_i logic or just use previously computed values.
                // Since we need to check if *any* type can be bought, we iterate type_idx.
                
                // However, f_i calculation requires division. 
                // (a_i * 65536) / sum_a. 
                // This is a sequential divider or combinational.
                // Given requirements "approx 256*8 cycles", we can use a state to compute f_i one by one or all.
                // Let's assume we compute f_i on the fly or precompute.
                // To save logic, let's compute f_i inside the CHECK_BALANCE state loop.
                
                // Since we don't have a divider module, we'll implement a restoring division or iterative logic.
                // But wait, Verilog ` / ` is synthesizable for constants but not good for area.
                // Given the constraints, we will use a combinational calculation for f_i (a_i * 65536 / sum_a).
                // We must handle sum_a = 0.
                
                // Logic: Check if type_idx < m.
                // Calculate f = (a[type_idx] << 16) / sum_a.
                // Check balance: 
                // n' = n + 1
                // s' = s + 1 (for current type)
                // Condition: |(n' * f) - s'| < 1
                
                // We iterate type_idx 0 to 7.
                // If valid, we go to UPDATE_COUNT.
                // If checked all and none valid, go to DONE.
                // If steps > 256, go to DONE (with forever_flag).
                
                // Optimization: We can combine checking loop.
                // Let's add a state ITERATE_TYPES to loop through 0 to m-1.
                // If valid found, update. 
            end
            
            UPDATE_COUNT: begin
                // Increment count
                additional_count_next = additional_count_reg + 1;
                // Update n and s
                n_next = n_reg + 1;
                // We only update the specific type we bought
                // We need to know which type was bought. 
                // We can store valid_type_idx in a register during check.
                // Since valid_type_idx is determined in CHECK_BALANCE, we use it here.
                s_next[valid_type_idx] = s_reg[valid_type_idx] + 1;
                
                // Check if steps reached 256
                // step_counter is incremented here or in next state?
                // Let's increment step_counter here.
                
                if (additional_count_reg == 16'h00FF) begin // 255, next is 256
                     // Next increment makes it 256 (0x100). 
                     // Requirements: "If count reaches 256, set forever_flag high"
                     // We check count before incrementing? Or after?
                     // "If count reaches 256" usually means >= 256.
                end
                
                // Loop back to CHECK_BALANCE (which will reset type_idx logic or handle it)
                // We need to manage the loop. 
                // Let's introduce a state ITERATE_CHECK that manages idx.
            end

            DONE: begin
                // Stay here
            end
        endcase
    end

    // Specific Loop Logic Implementation
    // We need a robust state machine for the iteration.
    // Let's refine states: IDLE, PRE_CHECK (calc sums/fractions), CHECK_LOOP, UPDATE, DONE.
    
    // Revised Logic:
    // 1. IDLE: Wait for start. Initialize. -> PRE_CHECK
    // 2. PRE_CHECK: Calculate sum_a (if not done). -> CHECK_LOOP
    // 3. CHECK_LOOP: Iterate type_idx 0 to m-1.
    //    a. Calculate f = (a[idx] << 16) / sum_a.
    //    b. Check balance.
    //    c. If valid, -> UPDATE.
    //    d. If end of list, -> DONE.
    // 4. UPDATE: Update regs. -> CHECK_LOOP (next iteration)
    //    Also check if step count >= 256. If so, set forever_flag -> DONE.
    // 5. DONE: Set done.

    // Redefine States
    localparam S_IDLE = 3'b000;
    localparam S_PRE_CHECK = 3'b001; // Calc sum_a
    localparam S_CHECK_ITER = 3'b010; // Loop through types
    localparam S_UPDATE = 3'b011;
    localparam S_DONE = 3'b100;
    localparam S_CALC_F = 3'b101; // State to handle division if sequential

    reg [2:0] state, next_state_v2;
    reg [7:0] type_counter; // 0 to 7
    reg [31:0] numerator; // a_i * 65536
    reg [31:0] denominator; // sum_a
    reg [31:0] division_result;
    reg div_start;
    reg div_done;
    
    // Divider (Sequential Restoring Division for Area)
    // Inputs: num, den. Output: quotient.
    // Since we are in one module, we can implement a simple FSM for division.
    reg [4:0] div_cnt;
    reg [31:0] rem;
    reg [31:0] quot;
    reg div_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_active <= 1'b0;
            div_done <= 1'b0;
            division_result <= 32'b0;
        end else begin
            if (div_start && !div_active) begin
                div_active <= 1'b1;
                div_cnt <= 5'd31;
                rem <= numerator; // dividend
                quot <= 32'b0;
                div_done <= 1'b0;
            end else if (div_active) begin
                if (div_cnt != 5'd32) begin // Wait one cycle for shift? No, do in cycle
                    // Shift left rem and quotient
                    {rem, quot} <= {rem[30:0], quot, 1'b0};
                    
                    if (rem[31:31] >= denominator[15:0]) begin // Comparison with 16-bit denom extended? 
                        // Standard restoring division:
                        // We treat denominator as 32-bit for comparison (den << 16)
                        // Wait, numerator is a_i * 65536. denominator is sum_a.
                        // We want (a_i * 65536) / sum_a.
                        // This implies denominator needs to be shifted.
                        // Actually, let's just implement a standard subtractive divider.
                        // Let's assume 32-bit operations.
                        
                        if (rem >= {denominator[15:0], 16'b0}) begin
                            rem <= rem - {denominator[15:0], 16'b0};
                            quot <= quot | 1'b1;
                        end
                        
                        if (div_cnt == 5'd0) begin
                            div_active <= 1'b0;
                            div_done <= 1'b1;
                            division_result <= quot; // Quotient is the result
                        end else begin
                            div_cnt <= div_cnt - 1;
                        end
                    end else begin
                        // Shift already done in concatenation. 
                        // Just check completion
                         if (div_cnt == 5'd0) begin
                            div_active <= 1'b0;
                            div_done <= 1'b1;
                            division_result <= quot;
                        end else begin
                            div_cnt <= div_cnt - 1;
                        end
                    end
                end else begin
                    div_active <= 1'b0;
                    div_done <= 1'b1;
                end
            end else begin
                div_done <= 1'b0;
            end
        end
    end

    // Main FSM v2
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            additional_count <= 16'b0;
            forever_flag <= 1'b0;
            done <= 1'b0;
            n_reg <= 16'b0;
            sum_a_reg <= 16'b0;
            type_counter <= 8'b0;
            for (i=0; i<8; i=i+1) s_reg[i] <= 16'b0;
            for (i=0; i<8; i=i+1) f_i[i] <= 32'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        for (i=0; i<8; i=i+1) s_reg[i] <= s[i];
                        additional_count <= 16'b0;
                        forever_flag <= 1'b0;
                        type_counter <= 8'b0;
                        state <= S_PRE_CHECK;
                    end
                end

                S_PRE_CHECK: begin
                    // Calculate Sum A
                    sum_a_reg <= 16'b0;
                    // We can do this combinational or sequential. Let's do sequential for large M or iterative.
                    // Since M <= 8, combinational is fine, but to fit state:
                    // Just do it in one cycle using an adder tree logic in combinational block or here.
                    // Let's rely on combinational block to compute sum_a_next and latch it.
                    sum_a_reg <= sum_a_next; // sum_a_next computed below
                    state <= S_CHECK_ITER;
                end

                S_CHECK_ITER: begin
                    // Check if we are done with all types
                    if (type_counter >= m) begin
                        // End of list, no valid type found
                        state <= S_DONE;
                    end else begin
                        // Check if f_i for this type is computed. If not, start computation.
                        // We can compute f_i on the fly using the divider.
                        // f_i = (a[type_counter] * 65536) / sum_a_reg
                        
                        if (sum_a_reg == 16'b0) begin
                            // If sum is 0, balance is impossible or trivial. 
                            // Assume no valid moves.
                            type_counter <= type_counter + 1;
                        end else if (f_i[type_counter] == 32'b0) begin
                            // Not computed yet, start division
                            numerator <= {a[type_counter], 16'b0}; // a_i * 65536
                            denominator <= {16'b0, sum_a_reg};
                            div_start <= 1'b1;
                            // stay in this state, wait for div
                        end else begin
                            // f_i is computed (or already valid). Now perform balance check.
                            // Check: n' = n_reg + 1. s' = s_reg[type_counter] + 1 (if we buy this type)
                            // Condition: |(n' * f_i) - s'| < 1
                            // In fixed point, f_i is Q16.16. n' is integer. s' is integer.
                            // n' * f_i = (n' << 16) * f_i >> 16 = n' * f_i(high 16 bits)
                            // Actually, f_i is already scaled.
                            // Let's stick to: product = (n_reg + 1) * f_i[type_counter]
                            // product is Q16.16? No, n is 16 bit, f is Q16.16 -> result is Q32.16.
                            // We compare integer part of product with s_reg[type_counter] + 1.
                            
                            // Let's do the check in combinational logic or here.
                            // To save state space, we do the check logic in combinational block triggered by state.
                            // We need to latch the result of check.
                            
                            // Let's use a sub-state or just rely on combinational logic to set a flag.
                            // We will move to UPDATE if valid, else increment type_counter.
                            
                            // Note: The check logic is combinational below.
                            // If balance_ok is high, we move to UPDATE.
                            if (balance_ok) begin
                                state <= S_UPDATE;
                            end else begin
                                type_counter <= type_counter + 1;
                            end
                        end
                    end
                    
                    // Handling Divider Handshake
                    if (div_start) div_start <= 1'b0;
                    if (div_done) begin
                        // Store computed f_i
                        f_i[type_counter] <= division_result;
                        // Remain in S_CHECK_ITER to perform the balance check in next cycle
                    end
                end

                S_UPDATE: begin
                    // Update n
                    n_reg <= n_reg + 1;
                    // Update s for the specific type
                    // We need to know which type. It is 'type_counter'.
                    // Since s_reg is an array, we need to update the specific index.
                    // Verilog always blocks handle arrays element-wise.
                    s_reg[type_counter] <= s_reg[type_counter] + 1;
                    
                    // Increment total count
                    additional_count <= additional_count + 1;
                    
                    // Check for forever flag (256 steps)
                    if (additional_count == 16'd255) begin // We are about to increment to 256
                         forever_flag <= 1'b1;
                         state <= S_DONE;
                    end else begin
                        // Reset type_counter to 0 to check all types again
                        type_counter <= 8'b0;
                        // Optimization: We don't need to recalculate f_i if sum_a doesn't change.
                        // However, we might want to clear f_i to recompute? No, keep them.
                        // But wait, we need to check again. We loop back to CHECK_ITER.
                        state <= S_CHECK_ITER;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    if (!start) state <= S_IDLE; // Wait for start to go low to reset? Or stay done.
                end
            endcase
        end
    end

    // Combinational Logic for Sum, Balance Check, and Next State
    always @(*) begin
        // Default assignments
        sum_a_next = sum_a_reg;
        
        // Calculate Sum A (Combinational for PRE_CHECK state)
        sum_a_next = 16'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < m) begin
                sum_a_next = sum_a_next + a[i];
            end
        end

        // Balance Check Logic
        // We need to calculate: | (n_reg + 1) * f_i[type_counter] - (s_reg[type_counter] + 1) | < 1
        // In Q16.16, "< 1" means the integer part difference is 0 and fractional part difference magnitude < 1.0
        // Actually, strict math: | real_value - integer | < 1. 
        // Since we are in fixed point, let's compute:
        // Target = (n_reg + 1) * f_i[type_counter]  -> result is Q16.16 (if we scale f_i correctly? No).
        // f_i = (a_i * 65536) / sum_a. This is (value * 65536).
        // So (n_reg + 1) * f_i = (n_reg + 1) * (a_i * 65536 / sum_a).
        // This is Q(n_bits, 16).
        // s_reg is integer.
        
        // Let's use the 32-bit temporary registers.
        // n_reg is 16 bit. f_i is 32 bit (Q16.16). 
        // Multiplication: 16 bit * 32 bit -> 48 bit. We take upper 32 or 16 bits?
        // f_i is already (a_i * 65536) / sum_a.
        // So f_i / 65536 is the actual fraction.
        // We want: | (n_reg+1) * (f_i / 65536) - (s_reg+1) | < 1
        // Multiply by 65536: | (n_reg+1) * f_i - (s_reg+1)*65536 | < 65536
        
        // Let's stick to simpler fixed point math.
        // P = (n_reg + 1) * f_i. 
        // S = (s_reg[type_counter] + 1) * 65536.
        // Check |P - S| < 65536.
        
        // Let's define P and S.
        // P = (n_reg + 1) * f_i[type_counter]. Result is 48 bit (16+32). 
        // We only care about 32 most significant bits (or 33).
        // Let's truncate to 32-bit (high 32 bits of result).
        // P_full = (n_reg + 1) * f_i.
        // P_approx = P_full >> 16.
        
        // S = (s_reg[type_counter] + 1) << 16.
        
        // Difference = P_approx - S.
        // Check if -65536 < Diff < 65536.
        // Since Diff is 32 bit signed, this is equivalent to Diff[31:16] == 0 (if unsigned, but signed wrap around)
        // Or Diff[31:16] == 0 or -1 (if two's complement allows wrap).
        // Actually, check MSBs.
        
        // Optimized Check:
        // (n_reg + 1) * f_i = (n_reg + 1) * (a_i * 65536 / sum_a).
        // Let's combine: 
        // Prod = (n_reg + 1) * a_i * 65536 / sum_a.
        // We want | Prod - (s_reg + 1) * 65536 | < 65536.
        // Divide everything by 65536: | (n_reg+1)*a_i/sum_a - (s_reg+1) | < 1.
        
        // Let's compute: 
        // Term1 = (n_reg + 1) * a_i.
        // Term1 is 16+16 = 32 bits max.
        // Term2 = (s_reg + 1) * sum_a.
        // Term2 is 16+16 = 32 bits max.
        // Check | Term1 - Term2 | < sum_a.
        
        // Wait, 
        // | (n+1)*a_i/sum_a - (s+1) | < 1
        // => | (n+1)*a_i - (s+1)*sum_a | < sum_a
        // This is an integer check! No floating point needed for the final comparison!
        // But we need to ensure we aren't losing precision. 
        // Since a_i, sum_a, s, n are integers, this is exact.
        // However, the problem requires Q16.16 conversion in step 1. 
        // We must perform the conversion as stated, but we can use the integer check for the logic.
        
        // To meet requirements: "Compute balance check using Q16.16 arithmetic"
        // 1. f_i = (a_i * 65536) / sum_a. (This is already calculated in f_i register).
        // 2. New n' = n + 1.
        // 3. New s' = s + 1.
        // 4. Check: n' * f_j - 1 < s_j' < n' * f_j + 1.
        //    => | n' * f_j - s_j' | < 1.
        
        // Using Q16.16 f_j:
        // n' * f_j -> This is (n' * f_j) >> 16 in fixed point arithmetic.
        // Let P = (n_reg + 1) * f_i[type_counter].
        // P is in format Q(16+n_bits, 16). 
        // We need to compare P (scaled) with (s_reg + 1) (integer).
        
        // Let's convert s_reg + 1 to Q16.16: S_fix = (s_reg + 1) << 16.
        // Check: | P - S_fix | < 1.0 (i.e., 1 << 16).
        
        // Calculation of P:
        // P_full = (n_reg + 1) * f_i[type_counter] -> 16 * 32 -> 48 bits.
        // P_fix = P_full >> 16 -> 32 bits.
        
        // Calculation of S_fix:
        // S_fix = (s_reg + 1) << 16 -> 32 bits.
        
        // Difference:
        // diff = P_fix - S_fix.
        // Check: diff[31:16] == 0 or -1 (for positive/negative small values).
        // But careful: if diff is small positive, say 100, diff[31:16] is 0.
        // If diff is small negative, say -100, diff[31:16] is 0xFFFF (since 32-bit signed).
        // Condition: (diff[31:16] == 0) || (diff[31:16] == -1) OR simply abs(diff) < 65536.
        
        // Let's implement the Q16.16 check as requested.
        
        // Temporary values for check
        // We need to handle the latched f_i. If f_i is 0, we need to wait or skip.
        // We handled wait for divider in state machine.
        
        // Compute P_fix = ((n_reg + 1) * f_i[type_counter]) >> 16
        // Multiplication logic:
        reg [47:0] p_full;
        p_full = (n_reg + 1) * f_i[type_counter];
        // This multiplication result is actually wrong if f_i is Q16.16.
        // n is 16 bit (integer). f_i is 32 bit (Q16.16).
        // Product is Q16.16. 
        // To get integer part: we look at bits 47:16.
        // To compare with s+1 (integer), we need to see if integer part equals s+1.
        // But the condition is n'*f_j - 1 < s_j' < n'*f_j + 1.
        // If n'*f_j = 5.9, s_j' = 5. Then 4.9 < 5 < 6.9. Correct.
        // If n'*f_j = 5.1, s_j' = 5. Correct.
        // If n'*f_j = 5.0, s_j' = 5. 4 < 5 < 6. Correct.
        // So we are checking if the fractional value is within 1 unit of the integer s_j'.
        
        // Let F = n'*f_j. Let S = s_j'.
        // Check: S - 1 < F < S + 1.
        // Multiply by 65536: S*65536 - 65536 < F*65536 < S*65536 + 65536.
        // Note: F*65536 = (n'*f_j) * 65536. 
        // Since f_j = (a_j * 65536) / sum_a.
        // F*65536 = n' * a_j * 65536 / sum_a * 65536 = n' * a_j * (65536^2) / sum_a. (This gets big)
        
        // Let's go back to the direct Q16.16 comparison.
        // We have f_j (Q16.16). 
        // Compute P = (n_reg + 1) * f_j.
        // P is in 48 bits. 
        // We want to compare P (in Q16.16) with (s_reg + 1).
        // (s_reg + 1) is an integer. 
        // P represents a fixed point number. 
        // The integer part of P is P[47:16].
        // The fractional part of P is P[15:0].
        
        // Condition: | (integer(P) + fractional(P)/65536) - (s_reg + 1) | < 1
        // This is equivalent to: 
        // | integer(P) - (s_reg + 1) + fractional(P)/65536 | < 1
        
        // This is hard to check combinatorially without complex logic.
        // Let's use the normalized integer check derived from the fraction math, which is valid and simpler.
        // BUT, requirement says "Compute balance check using Q16.16 arithmetic".
        // Okay, we will strictly follow the Q16.16 requirement.
        
        // Let's define:
        // P = (n_reg + 1) * f_i[type_counter]. Result is 48 bit.
        // We want to see if (s_reg + 1) is close to P.
        // (s_reg + 1) in Q16.16 is (s_reg + 1) << 16.
        
        // Diff = P - ((s_reg + 1) << 16).
        // We need to check if Diff is within +/- 1.0 (i.e., +/- 65536 in Q16.16 units).
        // Since P is Q16.16 * 16 bit int -> Result is Q32.16 ? No.
        // 16 bit int * Q16.16 -> Result is Q(16+16).16 = Q32.16.
        // Actually, f_i is Q16.16. 
        // n is 16 bit int. 
        // n * f_i = n * (f_actual * 65536) = (n * f_actual) * 65536. -> Q16.16.
        // So the result is still Q16.16 if we consider the range of n.
        // But wait, if n is 65535, n * f_i (max 65535*65535) is 2^32 approx. 
        // So P will overflow 32 bits. We need 48 bits.
        // P[47:16] is the integer part of P (scaled by 65536).
        // No, P is the raw product. 
        // P[47:16] is the Q16.16 representation of the product? 
        // Yes. If we treat P as 48 bits (signed), then P[47:16] is the value in Q16.16 format.
        // Let's define P_fix = P[47:16].
        // Now P_fix is Q16.16.
        
        // Compare P_fix with (s_reg + 1) << 16.
        // Diff = P_fix - ((s_reg + 1) << 16).
        // Check if |Diff| < 65536.
        
        // Let's implement this in hardware.
        
        // We need to access s_reg and n_reg from the sequential block.
        // Note: In the sequential block we update s_reg and n_reg.
        // In the check logic (Combinational), we use current values.
        
        // However, we need to compute P in combinational logic or inside the state.
        // Since P requires multiplication, and we are synthesizing, we need to be careful about timing.
        // The request "latency approx 256*8 cycles" suggests iterative logic is fine.
        // But we are allowed combinational blocks.
        
        // Let's assume we do the check in a combinational block that drives the 'balance_ok' signal.
        // We will calculate P in combinational logic.
    end

    // Combinational Check Block
    reg [47:0] p_full_check;
    reg [31:0] p_fix_check;
    reg [31:0] s_fix_check;
    reg [31:0] diff_check;
    
    always @(*) begin
        balance_ok = 1'b0;
        
        // Only check if f_i is computed (non-zero) and we are in check state
        if (state == S_CHECK_ITER && !div_start && !div_done && f_i[type_counter] != 32'b0 && type_counter < m) begin
            // P = (n_reg + 1) * f_i[type_counter]
            // n_reg is 16 bit, f_i is 32 bit. Result 48 bit.
            p_full_check = (n_reg + 1) * f_i[type_counter];
            
            // p_fix is Q16.16 representation of P (upper 32 bits of p_full)
            p_fix_check = p_full_check[47:16];
            
            // s_fix = (s_reg[type_counter] + 1) * 65536
            s_fix_check = (s_reg[type_counter] + 1) << 16;
            
            // Diff = p_fix - s_fix
            // If p_fix is smaller than s_fix, diff will be negative.
            // We need absolute value < 65536.
            // In two's complement, if diff is negative, say -50000, it is 32'hFFFF3CB0.
            // -50000 is within range.
            // If diff is -70000 (which is < -65536), it is 32'hFFFE EE70.
            
            // Let's perform signed subtraction.
            diff_check = p_fix_check - s_fix_check;
            
            // Check bounds:
            // We need -65536 < diff < 65536.
            // Max positive: 0x0000FFFF (65535)
            // Min negative: 0xFFFF0001 (-65535)
            
            // This range check in verilog:
            // If diff[31] == 0 (positive): diff[31:16] must be 0.
            // If diff[31] == 1 (negative): diff[31:16] must be 0xFFFF (since -1 in 16 bits is 0xFFFF, -65535 is 0xFFFF0001).
            
            if (diff_check[31] == 0) begin
                if (diff_check[31:16] == 16'b0) begin
                    balance_ok = 1'b1;
                end
            end else begin
                if (diff_check[31:16] == 16'hFFFF) begin
                    balance_ok = 1'b1;
                end
            end
        end
    end

endmodule
