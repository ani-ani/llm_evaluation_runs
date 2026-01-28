module repeating_decimal_to_fraction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] total_digits,
    input wire [3:0] repeat_digits,
    input wire [11:0] scaled_value,
    output reg [31:0] numerator,
    output reg [31:0] denominator,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CALC_POW10 = 4'd1;
    localparam [3:0] CALC_N1_N2 = 4'd2;
    localparam [3:0] CALC_NOM_DEN = 4'd3;
    localparam [3:0] CALC_GCD_START = 4'd4;
    localparam [3:0] CALC_GCD_LOOP = 4'd5;
    localparam [3:0] APPLY_GCD = 4'd6;
    localparam [3:0] FINISH = 4'd7;

    reg [3:0] state, next_state;
    reg [31:0] temp_numerator, temp_denominator;
    reg [31:0] pow10_A, pow10_B;
    reg [31:0] N1, N2;
    reg [31:0] pow10_A_minus_1, pow10_B_minus_1;
    reg [31:0] a_gcd, b_gcd;
    reg [31:0] gcd_result;
    reg [7:0] counter;
    reg gcd_calc_active;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Power of 10 calculation
    always @(*) begin
        pow10_A_minus_1 = 32'd1;
        pow10_B_minus_1 = 32'd1;
        pow10_A = 32'd1;
        pow10_B = 32'd1;
        case (total_digits)
            4'd0: begin pow10_A_minus_1 = 32'd0; pow10_A = 32'd1; end
            4'd1: begin pow10_A_minus_1 = 32'd9; pow10_A = 32'd10; end
            4'd2: begin pow10_A_minus_1 = 32'd99; pow10_A = 32'd100; end
            4'd3: begin pow10_A_minus_1 = 32'd999; pow10_A = 32'd1000; end
            4'd4: begin pow10_A_minus_1 = 32'd9999; pow10_A = 32'd10000; end
            4'd5: begin pow10_A_minus_1 = 32'd99999; pow10_A = 32'd100000; end
            4'd6: begin pow10_A_minus_1 = 32'd999999; pow10_A = 32'd1000000; end
            4'd7: begin pow10_A_minus_1 = 32'd9999999; pow10_A = 32'd10000000; end
            4'd8: begin pow10_A_minus_1 = 32'd99999999; pow10_A = 32'd100000000; end
            4'd9: begin pow10_A_minus_1 = 32'd999999999; pow10_A = 32'd1000000000; end
            4'd10: begin pow10_A_minus_1 = 32'd9999999999; pow10_A = 32'd10000000000; end
            4'd11: begin pow10_A_minus_1 = 32'd99999999999; pow10_A = 32'd100000000000; end
            default: begin pow10_A_minus_1 = 32'd0; pow10_A = 32'd1; end
        endcase
        case (repeat_digits)
            4'd0: begin pow10_B_minus_1 = 32'd0; pow10_B = 32'd1; end
            4'd1: begin pow10_B_minus_1 = 32'd9; pow10_B = 32'd10; end
            4'd2: begin pow10_B_minus_1 = 32'd99; pow10_B = 32'd100; end
            4'd3: begin pow10_B_minus_1 = 32'd999; pow10_B = 32'd1000; end
            4'd4: begin pow10_B_minus_1 = 32'd9999; pow10_B = 32'd10000; end
            4'd5: begin pow10_B_minus_1 = 32'd99999; pow10_B = 32'd100000; end
            4'd6: begin pow10_B_minus_1 = 32'd999999; pow10_B = 32'd1000000; end
            4'd7: begin pow10_B_minus_1 = 32'd9999999; pow10_B = 32'd10000000; end
            4'd8: begin pow10_B_minus_1 = 32'd99999999; pow10_B = 32'd100000000; end
            4'd9: begin pow10_B_minus_1 = 32'd999999999; pow10_B = 32'd1000000000; end
            4'd10: begin pow10_B_minus_1 = 32'd9999999999; pow10_B = 32'd10000000000; end
            4'd11: begin pow10_B_minus_1 = 32'd99999999999; pow10_B = 32'd100000000000; end
            default: begin pow10_B_minus_1 = 32'd0; pow10_B = 32'd1; end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            numerator <= 32'd0;
            denominator <= 32'd0;
            done <= 1'b0;
            temp_numerator <= 32'd0;
            temp_denominator <= 32'd0;
            N1 <= 32'd0;
            N2 <= 32'd0;
            a_gcd <= 32'd0;
            b_gcd <= 32'd0;
            gcd_result <= 32'd0;
            counter <= 8'd0;
            cycle_count <= 8'd0;
            gcd_calc_active <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CALC_N1_N2;
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                CALC_N1_N2: begin
                    // Calculate N1 = scaled_value / 10^(A-B) (integer division)
                    // Calculate N2 = scaled_value % 10^(A-B)
                    // First, we need pow10_diff = 10^(A-B)
                    // For A=total_digits, B=repeat_digits
                    // N1 = scaled_value / 10^(A-B)
                    // N2 = scaled_value % 10^(A-B)
                    // Actually, let's compute:
                    // N1 = scaled_value / 10^repeat_digits (if we assume non-repeating part)
                    // But spec says: N1 = integer part * 10^A + non-repeating fractional part
                    // N2 = repeating part
                    // The input scaled_value is: integer_part * 10^A + fractional_part
                    // where fractional_part = non_repeating * 10^B + repeating
                    // So scaled_value = integer_part * 10^A + non_repeating * 10^B + repeating
                    // N1 = integer_part * 10^A + non_repeating
                    // N2 = repeating
                    // We need to separate scaled_value into N1 and N2
                    // This is tricky. Let's use the formula:
                    // Value = (scaled_value / 10^A) but with repeating part
                    // Let X = scaled_value
                    // Let P = 10^B
                    // The repeating part cycles every B digits
                    // Formula: (N1 * (P - 1) + N2) / (10^A * (P - 1))
                    // where N1 is the non-repeating part + integer part
                    // and N2 is the repeating part
                    // To get N1 and N2 from scaled_value:
                    // scaled_value = (non_repeating_part * 10^B + repeating_part)
                    // But we need to split it.
                    // Actually, the spec implies:
                    // N1 = integer part * 10^A + non-repeating fractional part
                    // N2 = repeating part
                    // The input scaled_value contains both.
                    // Let's assume:
                    // scaled_value = N1 * 10^B + N2  (where N1 includes the shift)
                    // So N1 = scaled_value / 10^B
                    // N2 = scaled_value % 10^B
                    // But wait, the description says:
                    // "scaled_value[11:0] (decimal without point)"
                    // And A = total_digits, B = repeat_digits
                    // So the number has A digits after decimal.
                    // If B > 0, the last B digits repeat.
                    // Let's extract:
                    // N1 = scaled_value / 10^B (this is the part before repeat)
                    // N2 = scaled_value % 10^B (this is the repeating part)
                    // Then formula: numerator = N1*(10^B-1) + N2, denom = 10^A*(10^B-1)
                    // But if B = 0 (no repeat), the formula should just be:
                    // numerator = scaled_value, denominator = 10^A
                    // Let's handle B=0 as a special case or general case.
                    // If B=0, then 10^B = 1, 10^B - 1 = 0.
                    // The formula breaks for B=0.
                    // So B=0 means finite decimal. Numerator = scaled_value, Denom = 10^A.
                    // If B > 0:
                    // N1 = scaled_value / 10^B
                    // N2 = scaled_value % 10^B
                    // Numerator = N1 * (10^B - 1) + N2
                    // Denom = 10^A * (10^B - 1)
                    // We need 10^B for division/modulo.
                    // We already computed pow10_B.
                    
                    if (repeat_digits == 4'd0) begin
                        // Finite decimal case
                        temp_numerator <= {20'd0, scaled_value};
                        temp_denominator <= pow10_A;
                        state <= CALC_NOM_DEN; // Skip to reduction step
                        gcd_calc_active <= 1'b0;
                    end else begin
                        // Infinite repeating case
                        // N1 = scaled_value / pow10_B
                        // N2 = scaled_value % pow10_B
                        // We need a divider for this. 
                        // Since A <= 11, B <= A, scaled_value is at most 10^12 - 1 (~40 bits)
                        // But scaled_value is 12-bit input, so it fits in 12 bits (0-4095).
                        // Wait, 12 bits is small. Max 4095.
                        // pow10_B can be up to 10^11, which is huge.
                        // If B > 3 or so, pow10_B > scaled_value.
                        // If pow10_B > scaled_value:
                        // N1 = 0 (integer division)
                        // N2 = scaled_value
                        // Let's check if pow10_B > scaled_value.
                        // scaled_value is 12 bit, max 4095.
                        // pow10_B is 10, 100, 1000, etc.
                        // 10^3 = 1000, 10^4 = 10000.
                        // If B >= 4, pow10_B > 4095 >= scaled_value.
                        // So N1 = 0, N2 = scaled_value.
                        
                        if (pow10_B > {20'd0, scaled_value}) begin
                            N1 <= 32'd0;
                            N2 <= {20'd0, scaled_value};
                        end else begin
                            // Need to divide scaled_value by pow10_B
                            // We'll do it iteratively to save logic.
                            // Since pow10_B is always a power of 10, we can shift decimal.
                            // But for Verilog synthesis, division is division.
                            // However, since we need GCD later anyway, and inputs are small,
                            // we can just use the formula:
                            // Let X = scaled_value (integer)
                            // Let P = 10^B
                            // Value = X / 10^A but with repeating part.
                            // Actually, simpler interpretation:
                            // The value is (scaled_value) / 10^A 
                            // but the last B digits of scaled_value repeat.
                            // Formula for repeating decimal 0.X Y(Repeating Y):
                            // Value = (XY - X) / (10^A * (10^B - 1))
                            // where X is non-repeating part (A-B digits), Y is repeating part (B digits).
                            // scaled_value = XY (concatenated integer)
                            // X = scaled_value / 10^B
                            // Y = scaled_value % 10^B
                            // Numerator = X * (10^B - 1) + Y
                            // Denom = 10^A * (10^B - 1)
                            // We need to compute X and Y.
                            // Since scaled_value <= 4095, and B <= 11.
                            // If B > 4, 10^B > 4095 >= scaled_value.
                            // Then X = 0, Y = scaled_value.
                            // If B <= 4, we can compute X and Y.
                            // Let's do iterative division for robustness.
                            // But wait, 10^B is large for B>4. 
                            // scaled_value is 12 bit. max 4095.
                            // 10^0 = 1
                            // 10^1 = 10
                            // 10^2 = 100
                            // 10^3 = 1000
                            // 10^4 = 10000 (>4095)
                            // So if B >= 4, 10^B > scaled_value.
                            // So N1 = scaled_value / 10^B = 0
                            // N2 = scaled_value % 10^B = scaled_value
                            
                            if (repeat_digits >= 4'd4) begin
                                N1 <= 32'd0;
                                N2 <= {20'd0, scaled_value};
                            end else begin
                                // B is 1, 2, or 3. We can compute directly.
                                // X = scaled_value / 10^B
                                // Y = scaled_value % 10^B
                                // We need a divider. Let's use a state to do it.
                                // But we already have the values computed in combinational logic (pow10_B).
                                // We can use a divider module or logic.
                                // Given the small size, we can just compute it in combinational logic
                                // using the computed pow10_B value.
                                // N1 = scaled_value / pow10_B
                                // N2 = scaled_value % pow10_B
                                // We need to register these.
                                // Let's just register them now. The synthesis tool will handle the division.
                                // But division in combinational logic is heavy.
                                // However, inputs are tiny (12 bit / 10-1000).
                                // Let's assume synthesis is okay or use a simple loop.
                                // Since we have a state machine, let's use a cycle to compute it.
                                // But wait, we are in CALC_N1_N2 state.
                                // Let's just use the division operator. It's small.
                                // scaled_value is 12 bit. pow10_B is max 1000.
                                // Division 12/10 is cheap.
                                N1 <= {20'd0, scaled_value} / pow10_B;
                                N2 <= {20'd0, scaled_value} % pow10_B;
                            end
                        end
                        
                        state <= CALC_NOM_DEN;
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                CALC_NOM_DEN: begin
                    // Compute Numerator and Denominator
                    // If B=0: Num = scaled_value, Den = 10^A
                    // If B>0: Num = N1 * (10^B - 1) + N2
                    //         Den = 10^A * (10^B - 1)
                    
                    if (repeat_digits == 4'd0) begin
                        // Already set in CALC_N1_N2
                        state <= CALC_GCD_START;
                    end else begin
                        // temp_numerator = N1 * (pow10_B - 1) + N2
                        // temp_denominator = pow10_A * (pow10_B - 1)
                        // We need to compute these.
                        // pow10_B_minus_1 is computed in combinational logic.
                        // We can compute multiplication here.
                        // Since values are small, direct * operator is fine.
                        temp_numerator <= N1 * pow10_B_minus_1 + N2;
                        temp_denominator <= pow10_A * pow10_B_minus_1;
                        state <= CALC_GCD_START;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                CALC_GCD_START: begin
                    // Prepare for GCD calculation (Euclidean algorithm)
                    // a_gcd = temp_numerator
                    // b_gcd = temp_denominator
                    // Handle 0 denominator case if any (shouldn't happen)
                    if (temp_denominator == 32'd0) begin
                        // Error case, just pass through
                        numerator <= temp_numerator;
                        denominator <= 32'd1;
                        state <= FINISH;
                    end else if (temp_numerator == 32'd0) begin
                        // Value is 0
                        numerator <= 32'd0;
                        denominator <= 32'd1;
                        state <= FINISH;
                    end else begin
                        a_gcd <= temp_numerator;
                        b_gcd <= temp_denominator;
                        state <= CALC_GCD_LOOP;
                        counter <= 8'd0;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                CALC_GCD_LOOP: begin
                    // Euclidean algorithm: while b != 0: (a, b) = (b, a % b)
                    // Need to compute modulo. 
                    // Since we need to finish in 500 cycles, and numbers are small,
                    // we can do one step per cycle or use combinational logic.
                    // Given we have a cycle counter, let's do it iteratively.
                    // However, calculating modulo takes cycles if done iteratively.
                    // Let's use the built-in % operator for simplicity and speed.
                    // It will synthesize to a divider. Given the small width, it's acceptable.
                    // We need a loop state. 
                    // Actually, Euclidean algorithm is typically:
                    // while (b != 0) {
                    //    t = b;
                    //    b = a % b;
                    //    a = t;
                    // }
                    // To do this in hardware without a divider block (iterative),
                    // we can use repeated subtraction or binary GCD.
                    // But we have 500 cycles. 
                    // Max value is ~4 billion. 32 bits.
                    // Number of iterations for Euclidean is O(log min(a,b)), ~50-100 steps max.
                    // Let's use a simple iterative state machine using modulo.
                    // Wait, using % in a state machine is tricky because % is not atomic in one cycle for large numbers usually,
                    // unless the synthesis tool infers a divider IP which takes many cycles.
                    // To strictly meet 500 cycles and be predictable,
                    // we should use repeated subtraction or binary GCD.
                    // Repeated subtraction: a = a - b (if a > b). 
                    // This is slow if a >> b.
                    // Binary GCD is better.
                    // Let's do Binary GCD (Stein's algorithm).
                    // 1. gcd(0, v) = v; gcd(u, 0) = u
                    // 2. If u, v even, gcd(u,v) = 2 * gcd(u/2, v/2)
                    // 3. If u even, v odd, gcd(u,v) = gcd(u/2, v)
                    // 4. If u odd, v even, gcd(u,v) = gcd(u, v/2)
                    // 5. If u, v odd, gcd(u,v) = gcd(|u-v|/2, min(u,v))
                    // This requires shifts and subtraction.
                    // Shifts are cheap. Subtraction is cheap.
                    // We need to track the power of 2 factor.
                    
                    // Let's stick to the modulo approach but assume the synthesis tool optimizes small divisions.
                    // If we use `a % b`, it synthesizes to a divider. 
                    // A 32-bit divider might take 32 cycles or more.
                    // We have 500 cycles. It should be fine.
                    // Let's just use the combinational modulo operator.
                    // But strictly, for a state machine, we should have one operation per cycle or use a dedicated state.
                    // Let's use a simple Euclidean loop with combinational logic for modulo.
                    // It's the most readable and likely to synthesize correctly for small widths.
                    // We just need to make sure we don't get stuck in an infinite loop.
                    
                    if (b_gcd == 32'd0) begin
                        gcd_result <= a_gcd;
                        state <= APPLY_GCD;
                    end else begin
                        // Standard Euclidean: a, b = b, a % b
                        // We need a temporary variable for a % b because we update both.
                        // Or update sequentially.
                        // Let's do: 
                        // t = a_gcd;
                        // a_gcd = b_gcd;
                        // b_gcd = t % b_gcd;
                        // This requires b_gcd to stay stable for the modulo.
                        // Let's use a temporary register for the modulo result.
                        // Actually, just one step per cycle.
                        // a_gcd <= b_gcd;
                        // b_gcd <= a_gcd % b_gcd; // WRONG! a_gcd changed.
                        // Need old a_gcd.
                        // a_gcd_old <= a_gcd;
                        // a_gcd <= b_gcd;
                        // b_gcd <= a_gcd_old % b_gcd;
                        
                        // Let's declare a temp for the modulo result in the combinational block
                        // or calculate it here. 
                        // Since we need to avoid combinational loops or long paths,
                        // let's just do the modulo in one cycle. 
                        // 32-bit modulo is fast in FPGA (LUT based or DSP).
                        
                        // Wait, if we update a_gcd and b_gcd in the same cycle, 
                        // the calculation b_gcd <= a_gcd % b_gcd uses the *current* a_gcd and b_gcd.
                        // So we need to capture the new values correctly.
                        // Let's use a helper variable in the combinational block.
                        // But we can't use intermediate regs in always block easily for this.
                        // Let's just compute it directly.
                        // a_gcd_next = b_gcd;
                        // b_gcd_next = a_gcd % b_gcd;
                        
                        // To avoid combinational loops in always block, we compute in state.
                        // Since % is an operator, it creates a logic block.
                        // We need to be careful about timing.
                        // Given the constraint 500 cycles, we can afford multiple cycles for GCD.
                        // Let's use a dedicated GCD loop logic.
                        
                        // Euclidean algorithm (standard):
                        // if (b_gcd == 0) done
                        // else begin
                        //   a_gcd <= b_gcd;
                        //   b_gcd <= a_gcd % b_gcd;  // This is the issue.
                        // end
                        // To fix the dependency, we need:
                        // temp = a_gcd % b_gcd;
                        // a_gcd <= b_gcd;
                        // b_gcd <= temp;
                        // We can use a temporary register `gcd_mod_result`.
                        // Let's add that.
                        
                        // Actually, let's just use the `gcd_mod_result` register we can define internally.
                        // Or we can use combinational logic for the next values.
                        // Let's define `next_a_gcd` and `next_b_gcd` in combinational logic.
                        // Then register them.
                        
                        // Since we are in a state machine, let's define the logic outside or inside carefully.
                        // Let's use a combinational block for next state logic.
                        // But the instructions say "single always block" is often preferred for simple FSMs.
                        // Let's stick to single always block but use a temp register for the modulo result.
                        
                        // Let's add: reg [31:0] mod_result;
                        // We need to calculate it. 
                        // But calculating modulo takes time.
                        // Let's assume synthesis tool handles it well for 32 bits.
                        // We will use a flag `gcd_step_done` if we were pipelining.
                        // But we are synchronous.
                        // Let's just do it. 
                        
                        // Let's define a temporary variable for the modulo operation in the state transition.
                        // We can't easily do that in a single always block without intermediate signals.
                        // Let's define `gcd_next_a` and `gcd_next_b` as combinational wires.
                        // But that puts logic outside the always block.
                        // Okay, let's put the logic inside.
                        
                        // We need to compute: temp = a_gcd % b_gcd
                        // Since we can't break out of the always block to compute temp,
                        // we can use a separate state for the modulo computation or just rely on the tool.
                        // Given the small values, let's just use the modulo operator.
                        // However, Verilog modulo in procedural assignment is blocking or non-blocking?
                        // It's fine.
                        
                        // Wait, I will define `gcd_mod_temp` in combinational logic block to avoid timing issues.
                        // But the instructions say to return only the module code.
                        // Let's add a combinational block at the end.
                        
                        // Let's stick to the single always block structure as requested by the prompt's example,
                        // but I'll add a combinational logic for GCD next state if needed.
                        // Actually, let's just use repeated subtraction for GCD to keep it simple and cycle-accurate.
                        // It's safe for 500 cycles.
                        // Repeated subtraction GCD:
                        // while (a != b) {
                        //   if (a > b) a = a - b;
                        //   else b = b - a;
                        // }
                        // This is slow but takes at most (value) cycles.
                        // Max value is ~4e9. That's too many cycles.
                        // We need Euclidean or Binary.
                        
                        // Let's use Binary GCD (Stein's algorithm) as it's efficient and simple to implement in FSM.
                        // Steps:
                        // 1. shift = 0; While both even: shift++, a/=2, b/=2
                        // 2. While a even: a/=2
                        // 3. While b even: b/=2
                        // 4. While a != b: 
                        //       if (a > b) a = (a - b); else b = (b - a);
                        //       while a even: a/=2
                        // 5. return a << shift
                        
                        // We need to handle division by 2 (shift right) and subtraction.
                        // We can do one operation per cycle.
                        // Let's implement this.
                        
                        // We need more registers for Binary GCD:
                        // `gcd_shift` : count of common factors of 2
                        // `gcd_a`, `gcd_b` : working copies
                        // `gcd_state` : sub-state for binary GCD
                        
                        // Revising the FSM for GCD.
                        // Let's add a GCD sub-state machine.
                        // Or just integrate it into the main state.
                        // Given the complexity, let's use the modulo operator but assume it takes 1 cycle.
                        // If it takes more, we might time out. 
                        // To be safe and strictly follow "within 500 cycles", 
                        // let's use the standard Euclidean algorithm but with `div` and `mod` operators.
                        // Modern synthesis tools optimize 32-bit division/modulo to a reasonable size/latency.
                        // If latency is an issue, we can add a delay state.
                        // Let's assume 1 cycle latency for simplicity in code structure, but warn in thought.
                        // Actually, let's use a simpler approach: 
                        // The values are small. We can do subtraction in a loop, but limited iterations.
                        // Let's use the Euclidean algorithm with a counter to prevent infinite loops.
                        // If counter > 100, stop (should not happen for these sizes).
                        
                        // Let's use combinational logic for GCD calculation in a separate block to keep the FSM clean.
                        // We will define `next_a_gcd`, `next_b_gcd` wires.
                        
                        // Re-reading instructions: "Use fixed-width arithmetic (16-32 bits)".
                        // Okay.
                        
                        // Let's implement the GCD loop with combinational next values.
                        // This is the cleanest way in Verilog.
                        
                        // We will update a_gcd and b_gcd.
                        // We need to handle the case where a_gcd < b_gcd (Euclidean swaps implicitly if we do modulo).
                        // If b_gcd == 0, we are done.
                        // If b_gcd > 0, a_gcd <= b_gcd, b_gcd <= a_gcd % b_gcd.
                        
                        // Let's use a temporary register to hold the modulo result for one cycle.
                        // This requires a combinational always block for the modulo calculation,
                        // or we do it in the sequential block.
                        // Doing 32-bit modulo in a sequential block is usually fine.
                        
                        // Let's refine: we will compute `gcd_next_val = a_gcd % b_gcd` in a combinational block.
                        // And update in the sequential block.
                        
                        // However, the prompt asks for a *single* module code block.
                        // I will put the combinational logic inside a `always @(*)` block inside the module.
                        
                        // Let's define the combinational logic for GCD next values.
                        // But to make the code fit in the JSON, let's keep it simple.
                        // We will use a separate state for the GCD calculation that loops.
                        // In the GCD loop state, we compute the next values and update.
                        // To avoid combinational loops between a_gcd and b_gcd,
                        // we can use the fact that `a % b` only depends on current a and b.
                        // So we can compute it in the comb block and register it.
                        
                        // Let's create a combinational block for GCD logic.
                        // `wire [31:0] gcd_next_a = b_gcd;`
                        // `wire [31:0] gcd_next_b = a_gcd % b_gcd;`
                        // `wire gcd_done = (b_gcd == 0);`
                        
                        // We need to be careful with `a_gcd % b_gcd`. If b_gcd is 0, it's undefined.
                        // So check `b_gcd != 0` first.
                        
                        // Let's put this logic inside the always block using a temporary variable?
                        // No, Verilog doesn't support that well.
                        // We will define combinational logic outside the sequential always block.
                        
                        // Let's structure the module:
                        // 1. Sequential always block (state machine)
                        // 2. Combinational always block (GCD logic helper)
                        // 3. Combinational always block (Power of 10 logic helper)
                        
                        // Wait, the instructions say "Only return Verilog code".
                        // It implies I can add necessary blocks.
                        
                        // Let's try to fit the GCD logic into the sequential block using `div` and `mod`.
                        // It synthesizes to a divider. It's fine.
                        // We just need to ensure we don't transition if the division result isn't ready.
                        // But standard Verilog simulates/synthesizes blocking assignments for sequential logic carefully.
                        // If we use non-blocking `<=`, the RHS is evaluated immediately.
                        // So `b_gcd <= a_gcd % b_gcd` uses current `a_gcd` and `b_gcd`.
                        // This is valid.
                        
                        // So we will do:
                        // if (b_gcd != 0) begin
                        //    a_gcd <= b_gcd;
                        //    b_gcd <= a_gcd % b_gcd;
                        // end else begin
                        //    gcd_result <= a_gcd;
                        //    state <= APPLY_GCD;
                        // end
                        // This is standard Euclidean implementation in Verilog.
                        
                        // One issue: if `a_gcd` is updated in the same clock cycle as `a_gcd % b_gcd` evaluation,
                        // non-blocking assignment ensures RHS uses old values. Correct.
                        
                        // Let's proceed with this.
                        
                        if (b_gcd != 32'd0) begin
                            a_gcd <= b_gcd;
                            b_gcd <= a_gcd % b_gcd;
                        end else begin
                            gcd_result <= a_gcd;
                            state <= APPLY_GCD;
                        end
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                APPLY_GCD: begin
                    // Divide numerator and denominator by gcd_result
                    // temp_numerator = temp_numerator / gcd_result
                    // temp_denominator = temp_denominator / gcd_result
                    // We can compute these directly or use a divider.
                    // Given we have cycles left, let's use division.
                    // Wait, we already computed GCD. Now we just reduce.
                    // Division takes cycles if done iteratively, but single cycle if hardware.
                    // Let's assume single cycle or use the same logic as GCD.
                    // We will use the division operator.
                    // Check if gcd_result is 0 (shouldn't be if temp_denom > 0)
                    if (gcd_result == 32'd0) begin
                        // Should not happen, but safety net
                        numerator <= temp_numerator;
                        denominator <= temp_denominator;
                    end else begin
                        numerator <= temp_numerator / gcd_result;
                        denominator <= temp_denominator / gcd_result;
                    end
                    state <= FINISH;
                    cycle_count <= cycle_count + 8'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                // Force finish to prevent lockup
                numerator <= 32'd0;
                denominator <= 32'd1;
                state <= FINISH;
            end
        end
    end

endmodule