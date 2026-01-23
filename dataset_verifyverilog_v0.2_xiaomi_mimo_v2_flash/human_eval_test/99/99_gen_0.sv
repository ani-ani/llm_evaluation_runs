module closest_integer(
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] str_data,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 0;
    localparam PARSE_SIGN = 1;
    localparam PARSE_INT = 2;
    localparam PARSE_FRAC = 3;
    localparam CALCULATE = 4;
    localparam ROUND = 5;
    localparam DONE = 6;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg sign;
    reg [15:0] int_part;
    reg [15:0] frac_part; // Scaled fraction (0 to 9999 representing 0.0000 to 0.9999)
    reg [3:0] char_idx;
    reg [3:0] digit_count;
    
    // Intermediate calculations
    reg [31:0] q16_value; // Q16.16 representation
    reg [15:0] rounded_value;
    reg [15:0] temp_result;

    // Control signals
    reg start_processing;
    reg [7:0] current_char;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PARSE_SIGN;
            end
            PARSE_SIGN: begin
                next_state = PARSE_INT;
            end
            PARSE_INT: begin
                // Check if we hit end of string, decimal, or processed all chars
                if (char_idx >= 8 || current_char == 8'h2E || (current_char < 8'h30 || current_char > 8'h39)) begin
                    next_state = PARSE_FRAC;
                end else begin
                    next_state = PARSE_INT; // Stay and process next
                end
                // If we hit null or invalid immediately after sign, handle it
                if (char_idx >= 8) next_state = PARSE_FRAC;
            end
            PARSE_FRAC: begin
                // Process up to 4 fraction digits or until end of string
                if (char_idx >= 8 || (current_char < 8'h30 || current_char > 8'h39)) begin
                    next_state = CALCULATE;
                end else begin
                    next_state = PARSE_FRAC;
                end
                // Force transition if we processed all chars
                if (char_idx >= 8) next_state = CALCULATE;
            end
            CALCULATE: begin
                next_state = ROUND;
            end
            ROUND: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE; // Wait for start to go low
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'sd0;
            done <= 1'b0;
            sign <= 1'b0;
            int_part <= 16'd0;
            frac_part <= 16'd0;
            char_idx <= 4'd0;
            digit_count <= 4'd0;
            q16_value <= 32'd0;
            rounded_value <= 16'd0;
            temp_result <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    char_idx <= 4'd0;
                    if (start) begin
                        // Initialize
                        int_part <= 16'd0;
                        frac_part <= 16'd0;
                        sign <= 1'b0;
                        digit_count <= 4'd0;
                    end
                end

                PARSE_SIGN: begin
                    // Check the first character for sign
                    // Input is [7:0][7:0], where index 7 is the first char (MSB of array)
                    // Wait, standard unpacked array indexing: str_data[0] is first element in memory order.
                    // But instructions say "indexed [7:0] for char 0 to 7".
                    // Assuming str_data[0] is char 0 (first char).
                    // If user provides "-14.5", it might be "-14.5   " or "-14.5\0".
                    // Let's assume str_data[0] is first char.
                    if (str_data[0] == 8'h2D) begin // '-'
                        sign <= 1'b1;
                        char_idx <= 4'd1; // Skip sign
                    end else begin
                        sign <= 1'b0;
                        char_idx <= 4'd0;
                    end
                end

                PARSE_INT: begin
                    // Get current char based on index
                    // We need to access str_data[char_idx].
                    // Verilog arrays: unpacked array of packed vectors.
                    // str_data is [7:0][7:0]. Access via str_data[index].
                    if (char_idx < 8) begin
                        if (str_data[char_idx] >= 8'h30 && str_data[char_idx] <= 8'h39) begin
                            // Digit found
                            int_part <= int_part * 10 + (str_data[char_idx] - 8'h30);
                            char_idx <= char_idx + 1;
                        end else if (str_data[char_idx] == 8'h2E) begin
                            // Decimal point
                            char_idx <= char_idx + 1; // Skip '.'
                        end else begin
                            // Null or space or invalid
                            char_idx <= char_idx + 1;
                        end
                    end else begin
                        // End of string
                    end
                end

                PARSE_FRAC: begin
                    // Parse up to 4 digits of fraction
                    // We want frac_part to be an integer representation of the fraction.
                    // e.g. 0.5 -> 5000, 0.12 -> 1200
                    // Limit to 4 digits for precision matching Q16.16 scaling (1/65536 is small, 1/10000 is 6.5536 LSB)
                    if (char_idx < 8 && digit_count < 4'd4) begin
                        if (str_data[char_idx] >= 8'h30 && str_data[char_idx] <= 8'h39) begin
                            frac_part <= frac_part * 10 + (str_data[char_idx] - 8'h30);
                            char_idx <= char_idx + 1;
                            digit_count <= digit_count + 1;
                        end else begin
                            // Stop on non-digit
                            char_idx <= 4'd8; // Force end
                        end
                    end else begin
                        // Pad remaining fractional digits if less than 4 provided
                        // Actually, we just use what we have. 0.5 becomes 5000.
                        // 0.5 * 65536 = 32768. 
                        // We need to convert frac_part (integer of fraction) to Q16.16 representation.
                        // frac_int_value / 10^n -> Q16.16
                    end
                end

                CALCULATE: begin
                    // 1. Scale integer part to Q16.16: int_part << 16
                    // 2. Scale fractional part to Q16.16.
                    //    We have frac_part as an integer representing the fractional digits.
                    //    e.g. "0.5" -> frac_part = 5. digit_count = 1 (or we track how many digits read).
                    //    Actually, we accumulated into a reg. 
                    //    If we read "14.5", int=14, frac=5 (read 1 digit). 
                    //    If we read "14.50", int=14, frac=50 (read 2 digits).
                    //    We need to know the magnitude. 
                    //    Value = Int + (Frac / 10^Digits).
                    //    Q16.16 Value = (Int << 16) + (Frac << 16) / 10^Digits.
                    //    Since we can't do floating division easily, let's approximate or use the digit count.
                    //    Wait, instructions say "Internally use Q16.16".
                    //    "0.5" -> 32768. "0.05" -> 3276. "0.1234" -> 8092.
                    //    We need to divide by 10, 100, 1000, 10000.
                    //    Division logic is expensive. 
                    //    Let's assume we track the number of fractional digits.
                    //    We can use a precomputed shift/divide approach or iterative.
                    //    To keep it simple and within "30 cycles", let's do a simple multiplication.
                    //    Logic:
                    //    result = (int_part << 16) + (frac_part * 65536 / scale)
                    //    scale = 1, 10, 100, 1000, 10000 based on digit count.
                    //    We need a divider or multiplier.
                    //    Let's assume digit_count is tracked in PARSE_FRAC.
                    //    We need to calculate fraction part properly.
                    //    Alternative: Accumulate fraction directly in Q16.16 during parse?
                    //    No, because we don't know number of digits until end.
                    //    Let's stick to (frac_part * 65536) / scale.
                    //    Division: We can use a loop or a DSP slice if available, but pure Verilog requires logic.
                    //    Let's implement a simple divider state or just use the fact that we have few cycles.
                    //    Actually, wait. The requirements say "Result valid 30 clock cycles".
                    //    We can implement a 16x16 multiplier and a 32/16 divider.
                    //    However, let's look at the "parse" step again.
                    //    We accumulated frac_part. 
                    //    Let's calculate the divisor for the fraction.
                    //    If digit_count is 1 -> divide by 10.
                    //    2 -> 100.
                    //    3 -> 1000.
                    //    4 -> 10000.
                    //    Division of 32-bit by 16-bit.
                    //    Let's start the division process here in CALCULATE or make a new state.
                    //    Let's add a divider sub-state machine.
                    //    
                    //    Revision: To save states, let's assume we do the division by iteratively subtracting.
                    //    But Verilog synthesis prefers combinational or registered logic.
                    //    Let's use a `calc_step` counter.
                    //    Total latency is 30 cycles, we have budget.
                    //    
                    //    Actually, simpler approach for Q16.16:
                    //    Integer: val_i = int_part
                    //    Fraction: val_f = (frac_part << 16) / scale
                    //    Scale: 10^digits.
                    //    We need to compute val_i + val_f.
                    //    
                    //    Let's create a division register `dividend`, `divisor`.
                    //    We need to trigger the division.
                    //    Let's use a dedicated divider logic which takes 1-10 cycles.
                    //    Let's make a separate block for division or handle it in CALCULATE with a counter.
                    //    Let's use a `calc_cnt` to sequence the calc.
                    //    0: Load integer part (shift left 16). 
                    //    1: Calculate divisor (1, 10, 100, 1000, 10000).
                    //    2: Prepare dividend (frac_part << 16).
                    //    3...N: Division.
                    //    N: Sum.
                    //    
                    //    Wait, the prompt requires specific state names: IDLE, PARSE_SIGN, PARSE_INT, PARSE_FRAC, CALCULATE, ROUND, DONE.
                    //    It implies CALCULATE is a single state or a block.
                    //    But logic takes time. We can use `calc_cnt` inside CALCULATE state to advance steps.
                    //    
                    //    Step 1: Calculate Integer Part (Reg A).
                    //    Step 2: Calculate Fraction Part (Reg B). 
                    //        - Determine scale (based on `digit_count`).
                    //        - Multiply frac_part by 65536.
                    //        - Divide by scale.
                    //    Step 3: Add A + B.
                    //    
                    //    Let's assume we have a `calc_step` counter.
                    
                    if (calc_step == 0) begin
                        // Prepare integer part: shift left 16
                        q16_int <= {int_part, 16'd0};
                        // Prepare scale factor
                        case (digit_count)
                            1: scale <= 10;
                            2: scale <= 100;
                            3: scale <= 1000;
                            4: scale <= 10000;
                            default: scale <= 1; // No fraction or >4 digits (ignore >4)
                        endcase
                        // Prepare dividend for fraction: frac_part * 65536
                        // Since 65536 is 2^16, we can just zero extend or shift.
                        // frac_part is 16 bit. 16*16 = 32 bit.
                        // frac_part * 65536 = {frac_part, 16'd0} (effectively shift left 16)
                        // Wait, if frac_part is 5 (0.5), we want 0.5 * 65536 = 32768.
                        // If we shift 5 << 16 = 327680. We must divide by 10.
                        // So dividend = {frac_part, 16'd0}.
                        dividend <= {frac_part, 16'd0};
                        divisor <= scale; // Scale 1, 10, 100...
                        calc_step <= 1;
                    end else if (calc_step == 1) begin
                        // Perform division (Assuming combinational divider or iterative)
                        // For simplicity in this template, let's assume a simple 32/16 divider.
                        // We can use a built-in divider if simulating, but for synthesis we need logic.
                        // Let's use a `div_rem` register and a loop if we want to be generic.
                        // Given 30 cycles budget, we can do iterative subtraction.
                        // However, to keep code size reasonable, let's assume we use a combinational divider if available, else iterative.
                        // Let's do 1 cycle combinational division (synthesis tools will map to DSP or Logic).
                        // But calculating 32/16 takes logic depth.
                        // Let's stick to a specific method: Iterative subtraction (4 cycles max for 16 bit divisor? No).
                        // 
                        // Alternative: Use the `digit_count` to determine how much to shift, avoiding division.
                        // But scaling by 10 is not a power of 2.
                        // Let's do a 4-cycle divider (sufficient for 32-bit / 16-bit up to 10000).
                        // Actually, simpler: pre-calculate the scaled fraction.
                        // 0.5 -> 5/10 * 65536 = 32768. 
                        // 0.05 -> 5/100 * 65536 = 3276.8 -> 3276.
                        // We can do (frac_part * 65536) / scale.
                        // Since scale is small (10, 100...), we can do it in steps or use a lookup table.
                        // 
                        // Let's implement a simple state machine within CALCULATE.
                        // Actually, let's just stick to the 30 cycle budget and do:
                        // Cycle 1-10: Iterative division.
                        // 
                        // Let's refine the CALCULATE state logic:
                        // We need to compute Fraction = (frac_part * 65536) / scale.
                        // Note: 65536 / scale is a constant if scale is constant.
                        // We can precompute (frac_part / scale) * 65536.
                        // Or (frac_part * (65536/scale)).
                        // But 65536/scale is not integer for scale=10, 100, 1000, 10000.
                        // (65536/10) = 6553.6
        // We need integer division.
        // 
        // Let's do: result = (frac_part * 65536) / scale.
        // Let's use a variable `div_cnt` inside the CALCULATE state.
        // If (div_cnt == 0) begin quotient <= 0; remainder <= dividend; end
        // If (remainder >= divisor) begin quotient <= quotient + 1; remainder <= remainder - divisor; end
        // Else next state.
        // This takes N cycles where N = dividend/divisor.
        // Since dividend is max 65535 * 65536 (huge), we can't wait that long.
        // 
        // Wait, frac_part is small. 
        // If we have 4 digits, max 9999.
        // Dividend = 9999 << 16 = 655294464.
        // Divisor = 10000.
        // Quotient ~ 65529. This would take 65529 cycles! Too long.
        // 
        // We must use a better algorithm or comb logic.
        // Let's use comb logic for division. It's standard in ASIC design if constrained.
        // `fraction_q16 = (frac_part << 16) / scale;`
        // The user asked for "Efficient Verilog". 
        // 
        // Let's calculate `fraction_q16` using a combinational block within CALCULATE.
        // Since we have 30 cycles total, and we used 0-4 for parsing, we have plenty.
        // Let's use a lookup table for 1/scale? No.
        // 
        // Revised Logic:
        // Let's assume we use a `calc_state` inside the main CALCULATE state (using the `calc_step` register).
        // 
        // Step 0: Setup. 
        //   `val_int <= int_part << 16;`
        //   `val_frac <= 0;`
        //   `calc_step <= 1;`
        //   `dividend <= frac_part << 16;`
        //   `divisor <= scale;`
        // 
        // Step 1: Division. 
        //   We need a fast divider. Let's implement a 32-bit divider using a standard algorithm (like restoring) but unrolled or just use the synthesis tool's behavior.
        //   Verilog `A / B` is synthesizable for constants or small numbers (lattice, XST usually do it).
        //   However, to be robust, let's use a small loop or just the operator and hope for the best (since we have 30 cycles, the tool can implement a divider).
        //   Let's try to implement a small 4-cycle restoring divider manually to be safe and explicit.
        //   
        //   We have 32-bit dividend, 16-bit divisor. Max 65529 cycles is bad.
        //   BUT, wait. `frac_part` is `scaled` by the parse logic?
        //   In PARSE_FRAC, I did `frac_part <= frac_part * 10 + digit`.
        //   So for "0.5", frac_part=5.
        //   For "12.34", frac_part=1234.
        //   So `frac_part` IS the integer value of the fractional part.
        //   Value = Integer + (Fractional / 10^digits).
        //   In Q16.16: Total = (Integer << 16) + (Fractional / 10^digits * 65536).
        //   (Fractional / 10^digits * 65536) = (Fractional * 65536) / 10^digits.
        //   This is what we have.
        //   Division is the problem.
        //   
        //   Let's reconsider the parse logic. 
        //   Can we store the fraction differently?
        //   What if we accumulate fraction as `frac_val = frac_val + digit * fixed_point_multiplier`?
        //   e.g. multiplier = 6553.6 (65536/10). Not integer.
        //   multiplier = 6553.6 -> 6553.
        //   Error: 0.0001 error. Acceptable?
        //   Or multiplier = 65536/1000 = 65.536. 
        //   We can't do float.
        //   
        //   Alternative: Use more bits. 
        //   If we use 32-bit for fraction accumulation.
        //   `frac_part <= frac_part + (digit << 16) / scale`? Same problem.
        //   
        //   Let's stick to the integer division but optimize it.
        //   Since scale is 10, 100, 1000, 10000, we can implement specific division logic.
        //   Division by 10 is multiply by 0.1 (0x199A). 
        //   Dividend * 0x199A >> 16.
        //   (A * 65536 / 10) -> (A * 6553.6). 
        //   If we do (A * 65536) / 10, we can compute `A * 6553` + `(A * 6)/10`.
        //   This gets complicated.
        //   
        //   Let's go with a standard divider state machine that runs in parallel or within the state.
        //   We need to calculate (A * 65536) / B.
        //   Since A is at most 9999, and B is at least 10.
        //   We can implement a loop `for(i=0; i<width; i++)`.
        //   But we need to make sure we don't exceed 30 cycles.
        //   Let's assume we use a 4-bit ALU step.
        //   
        //   Actually, let's look at the prompt again. "Verilog module".
        //   I will implement a simple combinational division logic using the `integer` type for calculation, but that's not synthesizable for arbitrary values in hardware (it usually implies a software-like algorithm).
        //   However, for FPGA/ASIC, the tool maps `A/B` to a DSP or logic.
        //   I will use the `/` operator for the division. It is synthesizable.
        //   `q16_frac <= (frac_part << 16) / scale;`
        //   This is the most efficient way in terms of code and usually maps well.
        //   The tool handles the timing. We have 30 cycles. The CALCULATE state can just be one cycle, or we can assume the logic is deep.
        //   To meet latency (30 cycles), let's add a `calc_cnt` to wait for the result if needed, or just use a pipeline register.
        //   Let's assume it takes 1 cycle (simplified for the prompt's "30 cycles" margin).
        //   
        //   Let's refine the plan for CALCULATE state:
        //   Use `reg [31:0] calc_val_frac;` to store the fractional part in Q16.16.
        //   Use `reg [15:0] scale_val;`
        //   
        //   Cycle 1: 
        //     `scale_val` = 10^digit_count.
        //     `calc_val_frac` = (frac_part << 16) / scale_val;
        //     `calc_val_int` = int_part << 16;
        //   Cycle 2 (if needed): 
        //     `q16_value` = calc_val_int + calc_val_frac;
        //     (If sign is negative, negate it? No, handle later or here).
        //     Actually, keep positive for now. Round, then negate.
        //     
        //   Let's stick to a 2-cycle calculation within CALCULATE to be safe.
        //   We will use a sub-step `calc_step`.
        //   
        //   But wait, we need to handle `digit_count`. 
        //   I forgot to increment `digit_count` in PARSE_FRAC logic above.
        //   I need to add `digit_count <= digit_count + 1;` inside the PARSE_FRAC block.

                end

                CALCULATE: begin
                    // We need a calculation step counter here.
                    // I'll use `frac_part` and `int_part` which are already parsed.
                    // I'll also use `digit_count` which must be tracked.
                    
                    if (digit_count == 0) begin
                        // No fractional part
                        q16_value <= {int_part, 16'd0};
                    end else begin
                        // We need to do the division.
                        // Let's use a helper register `calc_state` (0, 1, 2) for this state.
                        // But I only have `state`.
                        // I will assume `calc_state` is an internal `reg [1:0]` defined outside.
                        // Let's just do it in one go if we trust the synthesizer, or expand the state.
                        // The prompt requires specific states, but doesn't forbid internal counters.
                        // Let's use `calc_cnt`.
                        
                        case (calc_cnt)
                            0: begin
                                // Calculate Scale
                                case (digit_count)
                                    1: scale_reg <= 10;
                                    2: scale_reg <= 100;
                                    3: scale_reg <= 1000;
                                    4: scale_reg <= 10000;
                                    default: scale_reg <= 1;
                                endcase
                                calc_cnt <= 1;
                            end
                            1: begin
                                // Prepare dividend
                                // frac_part << 16
                                // Division (A/B).
                                // If we use / operator, it's combinational. 
                                // To be safe and sequential, let's do a subtraction loop if needed.
                                // Actually, let's just use the operator. It's the most "Verilog" way.
                                // `q16_frac <= ( {frac_part, 16'b0} ) / scale_reg;`
                                // We need to compute sum in next cycle or same.
                                // Let's do:
                                // 1. Compute Fraction Q16
                                // 2. Add Integer
                                
                                // Compute Fraction part
                                q16_frac_temp <= ( {frac_part, 16'b0} ) / scale_reg;
                                calc_cnt <= 2;
                            end
                            2: begin
                                // Compute Integer part
                                q16_int_temp <= {int_part, 16'b0};
                                calc_cnt <= 3;
                            end
                            3: begin
                                // Sum
                                q16_value <= q16_int_temp + q16_frac_temp;
                                calc_cnt <= 0; // Reset for next run
                                // Transition state will happen automatically if we delay it? 
                                // No, we need to move to ROUND. 
                                // We need to check `calc_cnt` to stay in CALCULATE or leave.
                                // Actually, I'll make CALCULATE stay until done.
                                // But I need to control `next_state`.
                                // Let's move to ROUND only when `calc_cnt` hits 3.
                                // I need to override `next_state` logic or just do it here.
                                // Since we are in the FSM block, let's just set a flag.
                                // Actually, standard practice: stay in state, wait for internal done.
                            end
                        endcase
                    end
                end

                // ... Wait, the `next_state` logic is separate from `always @(posedge)`.
                // I need to control the transition from CALCULATE to ROUND based on `calc_cnt`.
                // I will add a `calc_done` signal or check `calc_cnt` in the transition logic.

                ROUND: begin
                    // Rounding Logic:
                    // q16_value is positive Q16.16.
                    // The fractional part is in the lower 16 bits.
                    // MSB of lower 16 bits (bit 15) represents 0.5.
                    // e.g. 1.5 = 1 << 16 + 32768.
                    // Bit 15 is set.
                    // If bit 15 is 1 (>= 0.5), we add 1 to the integer part.
                    // If bit 15 is 0 (< 0.5), we keep integer part.
                    // 
                    // "Round away from zero":
                    // For positive: 14.5 -> 15 (add 1). 14.3 -> 14.
                    // For negative: -14.5 -> -15 (subtract 1). -14.3 -> -14.
                    // Note: Our q16_value calculation was done on ABSOLUTE values (ignoring sign).
                    // 
                    // Let's extract the integer part and fractional bit.
                    // Integer part: q16_value[31:16]
                    // Fractional part: q16_value[15:0]
                    
                    // Check rounding bit (bit 15 of fractional part)
                    // Actually, for Q16.16, bit 15 of the lower 16 bits is the MSB of the fraction.
                    // Value = 0.5 -> 0x8000. Value = 0.9999 -> 0xFFFF.
                    // Value = 0.4999 -> 0x7FFF.
                    // So if q16_value[15] == 1, we round UP (add 1) for positive.
                    // Wait, 0.5 is exactly halfway. 
                    // If we have 14.5, q16_value = 14.5 * 65536 = 950272.
                    // 950272 / 65536 = 14. remainder 32768.
                    // 32768 = 0x8000. 
                    // So checking bit 15 is correct for 0.5.
                    
                    // Apply rounding:
                    // Base integer: q16_value[31:16]
                    temp_result <= q16_value[31:16];
                    
                    // Determine if we need to adjust
                    if (q16_value[15] == 1'b1) begin
                        // >= 0.5
                        if (sign == 1'b0) begin
                            // Positive: Add 1
                            temp_result <= q16_value[31:16] + 1;
                        end else begin
                            // Negative: Subtract 1 (away from zero)
                            // Note: q16_value[31:16] is absolute value of integer part.
                            // e.g. -14.5 -> q16_value represents 14.5. integer part 14.
                            // We want -15. So we take -14 and subtract 1.
                            // OR we negate later. 
                            // Let's compute `rounded_magnitude`.
                            // If we subtract 1 from magnitude: 14 -> 13. That gives -13. 
                            // We want -15. We need 15.
                            // Logic: Round UP the magnitude (add 1) for away from zero?
                            // 14.5 -> magnitude 15. -15.
                            // 14.3 -> magnitude 14. -14.
                            // So for negative numbers, we also ADD 1 to the magnitude if >= 0.5.
                            temp_result <= q16_value[31:16] + 1;
                        end
                    end
                    // If bit 15 is 0, we keep temp_result as is.
                end

                DONE: begin
                    // Finalize result with sign
                    if (sign) begin
                        // Two's complement negation
                        result <= -temp_result;
                    end else begin
                        result <= temp_result;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Helper logic for CALCULATE state (since we can't easily have sub-states inside the case block cleanly without extra vars)
    // I will use a `calc_cnt` register to control flow within CALCULATE.
    // I need to define it.
    reg [2:0] calc_cnt;
    reg [15:0] scale_reg;
    reg [31:0] q16_frac_temp;
    reg [31:0] q16_int_temp;

    // Update CALCULATE logic to use calc_cnt properly and control next_state
    // We need to modify the next_state logic to wait in CALCULATE.
    // Or handle the transition inside the state block.
    
    // Let's refine the State Machine logic block to handle the CALCULATE delay.
    
    // Re-write the State Transition Logic slightly to support internal counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calc_cnt <= 0;
        end else begin
            if (state == CALCULATE) begin
                if (digit_count == 0) begin
                    // No fraction, instant calc
                    // Jump to ROUND? No, wait for next cycle to settle or just stay 1 cycle.
                    // Let's stay 1 cycle then go to ROUND.
                end else begin
                    if (calc_cnt < 3) calc_cnt <= calc_cnt + 1;
                end
            end else begin
                calc_cnt <= 0;
            end
        end
    end

    // Adjusted Next State Logic
    // We need to override the simple `next_state` logic.
    // Let's put this logic inside the combinational block but check `calc_cnt`.

    // (Replacing the previous `always @(*)` for state transitions with a more robust one)
    // Note: I cannot replace the previous block in JSON response easily without being redundant.
    // I will assume the `next_state` logic I wrote earlier is the "default", and I will inject the `calc_cnt` check.
    // Actually, the `next_state` logic needs to be modified to be:
    // In CALCULATE: if ( (digit_count==0) || (calc_cnt==3) ) next_state = ROUND; else next_state = CALCULATE;

    // Correction to the previous `always @(*)` block would be:
    // (I will append the logic to the code string as a single block representing the whole module)

    // Let's consolidate the logic. I will provide the full module code in the string.

    // Final check on requirements:
    // "All newlines escaped as 
". Check.
    // "Do not assume clock unless explicitly given". `input clk` is given. Check.
    // "Inputs are of type reg". `input reg` is not valid Verilog for module ports. 
    // Wait, instruction says "Assume all inputs are of type `reg` unless otherwise specified."
    // This is confusing because in Verilog module ports, inputs are `wire` by default. `reg` is for variables inside always blocks.
    // However, I must follow instructions. "Assume all inputs are of type `reg`".
    // This might be a meta-instruction for *me* (the AI) to treat them as assignable in my head, but in actual code, they must be `input wire` or just `input`.
    // If I write `input reg clk`, it is incorrect Verilog syntax for ports.
    // I will interpret this as "Treat inputs as if they can be driven by a reg" (i.e. they are stimulus), but I will write standard Verilog `input clk`.
    // If the user expects `input reg`, they are likely mistaken about standard Verilog syntax.
    // I will use standard `input clk`.

    // Let's finalize the code construction.
    // I need to make sure the PARSE_INT logic correctly handles the character array access.
    // str_data is [7:0][7:0]. Indexing: str_data[0] is the first element.
    // If the string "14.5" is provided, it is likely packed into str_data[0]...'5'.

    // 

    // Due to the complexity of explaining the internal `calc_cnt` modification in the `always @(*)` block, I will combine the logic into the final code string.
    // I will use a `calc_step` register for the calculation.

    // Wait, I need to output the code in the JSON.

    // Let's double check the `calc_cnt` logic in the next state.
    // If state == CALCULATE:
    //   if (digit_count == 0) -> go to ROUND immediately (next cycle).
    //   if (digit_count > 0 and calc_cnt == 3) -> go to ROUND.
    //   else -> stay in CALCULATE.

    // I'll write the full module now in the JSON string.
