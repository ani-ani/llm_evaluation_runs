module triangle_ways(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] l,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 5'b00001;
    localparam CALC_TOTAL = 5'b00010;
    localparam CALC_INVALID_A = 5'b00100;
    localparam CALC_INVALID_B = 5'b01000;
    localparam CALC_INVALID_C = 5'b10000;
    localparam DONE = 5'b11111;

    reg [4:0] state;
    reg [7:0] x; // Loop counter 0 to 255
    reg [31:0] accum; // Accumulator for total or invalid
    reg [31:0] l_q16; // l in Q16.16
    reg [31:0] a_q16, b_q16, c_q16; // Inputs in Q16.16
    reg [31:0] s_q16; // Current stick parameter
    reg [31:0] temp_val; // Intermediate storage
    reg [1:0] step; // Sub-state for arithmetic steps

    // Helper signals
    wire [31:0] l_plus_1 = l_q16 + 32'h00010000;
    wire [31:0] l_plus_2 = l_q16 + 32'h00020000;
    wire [31:0] l_plus_3 = l_q16 + 32'h00030000;
    
    // Loop bounds
    wire [7:0] x_plus_1 = x + 1;
    wire [7:0] x_plus_2 = x + 2;

    // Arithmetic overflow protection (saturating add for counters)
    // We iterate x from 0 to l (integer). Since l is 0-255 (scaled), x fits in 8 bits.
    // We need to check if x <= l. Since l is Q16.16, we compare x with l_q16[31:16].
    wire x_lte_l = (x <= l_q16[31:16]);

    // Register inputs on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_q16 <= 0;
            b_q16 <= 0;
            c_q16 <= 0;
            l_q16 <= 0;
        end else if (start && state == IDLE) begin
            a_q16 <= {a, 16'b0};
            b_q16 <= {b, 16'b0};
            c_q16 <= {c, 16'b0};
            l_q16 <= {l, 16'b0};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            accum <= 0;
            x <= 0;
            s_q16 <= 0;
            temp_val <= 0;
            step <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALC_TOTAL;
                        step <= 0;
                        accum <= 0;
                    end
                end

                CALC_TOTAL: begin
                    // Formula: (l+3)*(l+2)*(l+1)/6
                    // Cycle 1: (l+3)*(l+2)
                    if (step == 0) begin
                        temp_val <= l_plus_3 * l_plus_2; // 32b * 32b -> 64b, truncated to 32b. Wait, Q16.16 * Q16.16 -> Q32.32. We take upper 32 bits.
                        // Actually, Verilog multiplication is 64-bit result for 32-bit operands.
                        // We need to shift right by 16 to get back to Q16.16 from Q32.32.
                        // But here we are accumulating. Let's keep precision.
                        // Just do the math: (l+3)*(l+2) is roughly 256*256 = 65536 which is 1.0 in Q16.16. Fits in 32 bits if we handle shift.
                        // Let's use a 64-bit temp variable to be safe.
                        // But we are restricted to 32-bit logic in description. Let's stick to 32-bit ops with scaling awareness.
                        // l is 0-255. l+3 <= 258. (l+3)*(l+2) <= 66564. < 2^16. So it fits in 16 bits integer part.
                        // If we treat them as integers (shift out lower 16), the product is (a<<16)*(b<<16) = (a*b)<<32.
                        // We need a*b. So shift right 16, multiply, shift right 16? No, that loses precision.
                        // Let's just multiply them. (l+3) is 32'h00010000 + l.
                        // Product is (l+3)(l+2) << 32. 
                        // To divide by 6, we need to divide by 2 then 3.
                        // Let's compute: (l+3)*(l+2)*(l+1)
                        temp_val <= (l_plus_3 * l_plus_2) >> 16; // Now effectively Q16.16 * Q0.16 -> Q16.16
                        step <= 1;
                    end else if (step == 1) begin
                        // * (l+1)
                        temp_val <= (temp_val * l_plus_1) >> 16;
                        step <= 2;
                    end else if (step == 2) begin
                        // / 2
                        temp_val <= temp_val >> 1;
                        step <= 3;
                    end else if (step == 3) begin
                        // / 3. We can approximate 1/3 = 0x5555.
                        // Or use repeated subtraction. Or use (val * 0x5555) >> 16.
                        // 0x5555 is 21845.
                        // Let's use multiply by inverse.
                        // But wait, 0x5555 is Q16.0. 0x5555 * (val >> 16) is good.
                        // But val is Q16.16. 
                        // Let's do: (temp_val * 0x5555) >> 16.
                        // But 0x5555 is 1/3 in Q16. 
                        // Actually, standard way: accum = val / 3.
                        // Since we need precision, let's stick to integer logic for the division if possible, but we have Q16.16.
                        // (l+3)*(l+2)*(l+1)/6. Max value approx 256^3/6 ~ 2.8 million. ~ 0.04 in Q16.16? No, 2.8 million is 2.8 million.
                        // Q16.16 format: 2.8 million requires 22 bits integer. It fits in 32 bits.
                        // Let's compute (l+3)*(l+2)*(l+1) in 64 bit, divide by 6, store in 32 bit.
                        // Use 64-bit calc for this one step.
                        // Reset temp_val for next phase
                        accum <= temp_val / 3; // Integer division on the Q16.16 value? 
                        // Wait, temp_val is (l+3)*(l+2)*(l+1)/2 in Q16.16.
                        // Division by 3 of Q16.16. 
                        // Let's do (temp_val * 0x5555) >> 16.
                        // Since 0x5555 is roughly 21845/65536.
                        accum <= (temp_val * 32'h5555) >> 16;
                        state <= CALC_INVALID_A;
                        step <= 0;
                        x <= 0;
                        s_q16 <= 0;
                    end
                end

                CALC_INVALID_A, CALC_INVALID_B, CALC_INVALID_C: begin
                    // Loop: for x from 0 to l
                    if (x_lte_l && step == 0) begin
                        // Calculate s = 2*z - sum. 
                        // z is a, b, c depending on state.
                        // Use 64-bit to avoid overflow during 2*z
                        // 2*z needs 9 bits integer. 255*2 = 510. 
                        // If state A: s = 2*a - a - b - c = a - b - c. 
                        // If state B: s = 2*b - a - b - c = b - a - c.
                        // If state C: s = 2*c - a - b - c = c - a - b.
                        // All are 8-bit signed arithmetic (wrapped). We need signed Q16.16.
                        // s_q16 is already 32 bits.
                        // Pre-calculate s in idle or here.
                        // Let's do it here. 
                        // We need to construct s_q16 from inputs. 
                        // Wait, s depends on state.
                        // A: a - b - c
                        // B: b - a - c
                        // C: c - a - b
                        // We can compute s once per state.
                        if (state == CALC_INVALID_A) begin
                             s_q16 <= a_q16 - b_q16 - c_q16;
                        end else if (state == CALC_INVALID_B) begin
                             s_q16 <= b_q16 - a_q16 - c_q16;
                        end else begin
                             s_q16 <= c_q16 - a_q16 - b_q16;
                        end
                        step <= 1;
                    end else if (x_lte_l && step == 1) begin
                        // s + x (x is integer, convert to Q16.16: x << 16)
                        // Also need l - x
                        // s + x
                        // s_q16 is Q16.16. x << 16 is Q16.16.
                        // l - x. l_q16 is Q16.16.
                        // Note: x is 0..255. l is 0..255. x <= l ensures l-x >= 0.
                        // We need min(s + x, l - x)
                        // Let's compute s_plus_x = s_q16 + (x << 16)
                        // Let's compute l_minus_x = l_q16 - (x << 16)
                        // Then compare them.
                        temp_val <= s_q16 + (x << 16);
                        // We can reuse x for loop, but we need x for calculation.
                        // Store l_minus_x in some unused reg? Or compute inside step 2.
                        // Let's use 'accum' as temp storage for l_minus_x? No, accum holds the sum.
                        // Use another temp reg? We have 's_q16' which we can overwrite later.
                        // Let's store l_minus_x in s_q16 temporarily? No, s_q16 is needed for next iteration if we reset.
                        // Actually, we can compute l_minus_x in step 2.
                        step <= 2;
                    end else if (x_lte_l && step == 2) begin
                        // Calculate l - x
                        // x << 16
                        // temp_val holds s+x
                        // Let's compare temp_val (s+x) with (l - x).
                        // Need to store (l - x) to compare.
                        // We can compute (l - x) and store in temp_val if temp_val > (l-x)? No need to store.
                        // Just compute m.
                        // m = min(s+x, l-x).
                        // If (s+x) < (l-x), m = s+x. Else m = l-x.
                        // Let's compute diff = (s+x) - (l-x) = s+x - l + x = s + 2x - l.
                        // If diff < 0, s+x < l-x. 
                        // Note: s+x might be negative. l-x is non-negative (since x <= l).
                        // If s+x < 0, then s+x < l-x definitely. 
                        // So check if s+x < 0. If yes, m = s+x.
                        // If s+x >= 0, check if s+x <= l-x.
                        // Let's compute m_val.
                        // We need m+1 and m+2 for formula.
                        // Formula: (m+1)*(m+2)/2. m is Q16.16.
                        // However, in the invalid formula, m is defined in integer domain? 
                        // "min(s + x, l - x)". s is integer (scaled). x is integer. l is integer.
                        // So m is integer. 
                        // m = min(s + x, l - x). Where s, x, l are integers (from input scale).
                        // So we should treat s_q16, x, l_q16 as integers for this calc.
                        // s_q16[31:16] is integer part.
                        // l_q16[31:16] is integer part.
                        // Let's use integer parts for m.
                        // m_int = min(s_int + x, l_int - x).
                        // s_int = s_q16[31:16]. l_int = l_q16[31:16].
                        // Let's use a wire for integer parts.
                        // But s_int can be negative.
                        // l_int - x is non-negative.
                        // If s_int + x < 0, m = s_int + x (negative).
                        // Wait, the problem description says "If s + x < 0, continue". This implies m is not used (or effectively m < 0 leads to zero contribution?).
                        // Actually, the formula (m+1)*(m+2)/2 is triangular number. If m < -1, this is 0 (or positive? m=-3 -> (-2)*(-1)/2 = 1). 
                        // The problem says "If s + x < 0, continue". So we skip if s+x < 0.
                        // But m = min(s+x, l-x). 
                        // If s+x < 0, then m = s+x (since l-x >= 0). 
                        // So "If s + x < 0, continue" is equivalent to "If m < 0, continue".
                        // So we calculate m. If m < 0, skip (add 0). If m >= 0, subtract (m+1)*(m+2)/2.
                        // Wait, "Subtract (m+1)*(m+2)/2".
                        // So accum -= ...
                        
                        // Integer calculation:
                        // val1 = s_q16[31:16] + x
                        // val2 = l_q16[31:16] - x
                        // m = min(val1, val2)
                        
                        // Let's use a temporary register for m to avoid re-reading s_q16.
                        // We can use s_q16 to store m after calculation? No, s_q16 is needed for next x loop if we don't reset it.
                        // But s is constant for the whole loop. So we can restore s_q16 later or just keep s_q16 and use temp for m.
                        // We can use 'temp_val' to store m? 'temp_val' holds s+x (Q16.16). We can overwrite it with m (integer).
                        // Let's perform comparison.
                        // val1 (signed) = s_q16[31:16] + x. 
                        // val2 (unsigned) = l_q16[31:16] - x.
                        // If val1 < val2, m = val1 else m = val2.
                        // Also if val1 < 0, m = val1 (since val2 >= 0). This is covered by comparison if val2 is unsigned? 
                        // val2 is always >= 0. val1 can be negative. 
                        // In Verilog signed/unsigned comparison, we should be careful.
                        // Let's cast to signed for comparison.
                        // val1_s = signed'(s_q16[31:16]) + signed'(x);
                        // val2_s = signed'(l_q16[31:16]) - signed'(x);
                        // If val1_s < val2_s, m = val1_s else m = val2_s.
                        // If m < 0, skip. 
                        // If m >= 0, accum -= (m+1)*(m+2)/2.
                        // Note: accum is Q16.16. m is integer. (m+1)*(m+2)/2 is integer.
                        // We need to subtract integer from Q16.16. 
                        // accum = accum - (integer << 16).
                        
                        // Step 2: Compute m.
                        // Let's use 'temp_val' to hold m. 
                        // Since we need to handle the subtraction in step 3, let's compute m in step 2.
                        // But step 2 logic might be tight. Let's use combinational logic for m if possible, or break down.
                        // With 3 cycles per loop (given in instructions), we have room.
                        // Cycle 1: Compute m.
                        // Cycle 2: Compute (m+1)*(m+2)/2.
                        // Cycle 3: Subtract from accum.
                        
                        // Let's use step 2 for computing m.
                        // We need m as integer.
                        // s_int = s_q16[31:16], l_int = l_q16[31:16].
                        // If (s_int + x) < (l_int - x) then m = s_int + x else m = l_int - x.
                        // Also check if (s_int + x) < 0? No, just min.
                        // If m < 0, we skip the calculation.
                        
                        // To save registers, let's compute (m+1)*(m+2)/2 in step 2 if m>=0, else set to 0.
                        // Then step 3 subtracts.
                        
                        // Wait, we need to handle the case where we skip.
                        // Let's put m calculation in step 2.
                        // Store m in 's_q16'? No, s_q16 is needed for next iteration. 
                        // We can store m in 'temp_val'. temp_val is 32 bit. m fits in 16 bits (signed).
                        
                        // Signed arithmetic for min:
                        // Let A = s_q16[31:16] + x
                        // Let B = l_q16[31:16] - x
                        // m = min(A, B)
                        
                        // We'll do this calculation now in step 2.
                        // We need to know if m < 0.
                        // If m < 0, we skip the rest (just go to increment x).
                        // But we have to wait for the loop structure.
                        // We are in step 2. Next step is step 3. 
                        // Let's compute the term to subtract in step 2 and store in 'temp_val'.
                        // If m < 0, store 0.
                        // If m >= 0, store (m+1)*(m+2)/2.
                        // Then in step 3, subtract from accum and increment x.
                        
                        // So here (step 2) we compute m.
                        // Let's calculate A and B.
                        wire signed [15:0] A = s_q16[31:16] + x;
                        wire signed [15:0] B = l_q16[31:16] - x;
                        wire signed [15:0] m_int = (A < B) ? A : B;
                        
                        // Compute term if m_int >= 0
                        if (m_int >= 0) begin
                            // (m+1)*(m+2)/2
                            // m is signed 16 bit. result fits in 32 bits.
                            // Let's do unsigned math for m since we know m >= 0.
                            // (m+1) and (m+2) are positive.
                            // We can use a 32-bit result.
                            // Let's calculate (m+1)*(m+2) then shift right 1.
                            // (m+1)*(m+2) needs 32 bits.
                            // m <= l <= 255. (255+1)*(255+2) = 256*257 = 65792. < 2^16. 
                            // So it fits in 16 bits! 
                            // So (m+1)*(m+2)/2 fits in 16 bits.
                            // But accum is Q16.16. We need to shift left 16.
                            // So we can store (m+1)*(m+2)/2 in the upper 16 bits of temp_val? 
                            // No, just calculate value and shift left 16.
                            temp_val <= ((m_int + 1) * (m_int + 2)) << 15; // (val/2) << 16 = val << 15
                            // Wait, /2 is shift 1. << 16 is shift 16. Total shift 15.
                        end else begin
                            temp_val <= 0;
                        end
                        step <= 3;
                    end else if (x_lte_l && step == 3) begin
                        // Subtract temp_val from accum
                        accum <= accum - temp_val;
                        step <= 0;
                        x <= x + 1;
                    end else if (!x_lte_l && step == 0) begin
                        // Loop finished for current stick
                        // Switch to next state
                        if (state == CALC_INVALID_A) begin
                            state <= CALC_INVALID_B;
                            step <= 0;
                            x <= 0;
                        end else if (state == CALC_INVALID_B) begin
                            state <= CALC_INVALID_C;
                            step <= 0;
                            x <= 0;
                        end else if (state == CALC_INVALID_C) begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    // Result is Total - Invalid.
                    // Total is in 'accum' after CALC_TOTAL? No, CALC_TOTAL puts result in 'accum' temporarily?
                    // Wait, in CALC_TOTAL we put result in 'accum'. Then we transitioned to CALC_INVALID_A.
                    // So 'accum' holds Total. Then we subtracted Invalid terms in the loop.
                    // So 'accum' now holds Total - Invalid.
                    result <= accum;
                    done <= 1;
                    if (!start) begin // Wait for start to go low to return to IDLE or stay in DONE?
                        // Usually done stays high until next start.
                        // We need to exit DONE state.
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
