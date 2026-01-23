module digit_rearrange(
    input clk,
    input rst_n,
    input start,
    input [31:0] digit_vector,
    input [2:0] num_digits,
    output reg [39:0] result,
    output reg [3:0] result_length,
    output reg done,
    output reg valid
);

    // States
    localparam IDLE = 4'b0000;
    localparam COUNT_DIGITS = 4'b0001;
    localparam REMOVE_SPECIAL = 4'b0010;
    localparam COMPUTE_PREFIX = 4'b0011;
    localparam FIND_PERMUTATION = 4'b0100;
    localparam CONSTRUCT_RESULT = 4'b0101;
    localparam DONE = 4'b0110;

    reg [3:0] current_state, next_state;
    
    // Registers for counting and processing
    reg [3:0] digit_count [0:9]; // Counters for digits 0-9
    reg [3:0] current_digit_idx; // Iteration counter for input digits
    reg [3:0] special_count; // Count of {1,6,8,9}
    
    // Modulo computation registers
    reg [3:0] prefix_mod; // Result of (prefix_value * 10000) % 7, but calculated iteratively
    reg [3:0] mod_digit_idx;
    
    // Result construction registers
    reg [3:0] out_digit_idx; // Position in output buffer
    reg [3:0] current_output_digit;
    reg [3:0] zeros_remaining;
    
    // Temporary registers for logic
    reg [3:0] temp_digit;
    reg [7:0] cycle_count; // Latency counter (120 cycles)
    
    // Permutation lookup (4 bit value for each digit)
    reg [15:0] perm_digits; // 4 digits x 4 bits
    reg [3:0] perm_len;

    integer i;

    // State Transition and Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            valid <= 0;
            result <= 0;
            result_length <= 0;
            // Reset counters
            for (i = 0; i < 10; i = i + 1) digit_count[i] <= 0;
            current_digit_idx <= 0;
            special_count <= 0;
            prefix_mod <= 0;
            mod_digit_idx <= 0;
            out_digit_idx <= 0;
            zeros_remaining <= 0;
            current_output_digit <= 0;
            perm_digits <= 0;
            perm_len <= 0;
            cycle_count <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    result <= 0;
                    result_length <= 0;
                    cycle_count <= 0;
                    if (start) begin
                        current_state <= COUNT_DIGITS;
                        // Initialize counters
                        for (i = 0; i < 10; i = i + 1) digit_count[i] <= 0;
                        current_digit_idx <= 0;
                    end else begin
                        current_state <= IDLE;
                    end
                end

                COUNT_DIGITS: begin
                    // Process one digit per cycle to keep timing reasonable
                    if (current_digit_idx < num_digits) begin
                        // Extract current digit from vector
                        // digit_vector is packed: {digit[N-1], ..., digit[0]}? No, usually LSB is digit 0.
                        // Let's assume [3:0] is digit 0, [7:4] is digit 1, etc.
                        temp_digit <= digit_vector[current_digit_idx * 4 +: 4];
                        // Increment index immediately for next cycle logic, but logic below handles current_digit_idx
                    end else begin
                        current_state <= REMOVE_SPECIAL;
                        current_digit_idx <= 0;
                    end
                    // Update count for previous cycle's extracted digit (pipelined)
                    if (current_digit_idx > 0) begin
                        // We need to handle the extraction logic carefully to match the index. 
                        // Let's restructure: Extract happens, then count updates. 
                        // Wait, to do it in one state, we need to register the extracted digit.
                        // Actually, simpler: Extract at index i in cycle i, count in cycle i+1.
                        // Or do it all in one cycle. Let's try to finish counting in 8 cycles + 1.
                    end
                    // Re-implementation for robustness: iterate and accumulate.
                end
            endcase
        end
    end

    // Separate combinational logic for control flow to handle FSM transitions cleanly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Check if we need to initialize counters here or in next state
                        // Let's do initialization in IDLE->COUNT_DIGITS transition
                        // Actually, handled in the sequential block above, but we need to ensure clean slate.
                        // We need a separate counter for the digit extraction loop.
                    end
                end
                
                COUNT_DIGITS: begin
                    // We need a local loop counter for this state
                    // To avoid complex logic, let's unroll or use a small counter.
                    // Given the small max size (8 digits), we can use a 4-bit counter.
                    // Let's use 'current_digit_idx' as the loop counter.
                    // Extract digit
                    temp_digit <= digit_vector[current_digit_idx * 4 +: 4];
                    
                    // Increment index
                    if (current_digit_idx < num_digits) begin
                        current_digit_idx <= current_digit_idx + 1;
                    end else begin
                        current_state <= REMOVE_SPECIAL;
                    end
                end
                
                REMOVE_SPECIAL: begin
                    // Decrement counts of 1, 6, 8, 9
                    if (digit_count[1] > 0) digit_count[1] <= digit_count[1] - 1;
                    if (digit_count[6] > 0) digit_count[6] <= digit_count[6] - 1;
                    if (digit_count[8] > 0) digit_count[8] <= digit_count[8] - 1;
                    if (digit_count[9] > 0) digit_count[9] <= digit_count[9] - 1;
                    // Calculate special_count
                    special_count <= (digit_count[1] > 0 ? 1 : 0) + (digit_count[6] > 0 ? 1 : 0) + 
                                     (digit_count[8] > 0 ? 1 : 0) + (digit_count[9] > 0 ? 1 : 0);
                    // Note: This logic assumes 1 cycle for removal. 
                    // If counts are 0, we effectively skip. If >0, we decrement.
                    // Correctness check: What if we need to remove multiple instances? No, problem says remove one instance each.
                end

                COMPUTE_PREFIX: begin
                    // We need to compute (prefix_value * 10000) % 7.
                    // But we only have counts of digits left.
                    // Value is large. However, we just need the modulo.
                    // Formula: sum(digit * 10^pos)
                    // Since we can arrange prefix arbitrarily, the problem usually implies we want a valid remainder.
                    // Actually, the prompt says "Calculate prefix_value * 10000 % 7".
                    // Wait, if we arrange prefix arbitrarily, the value changes.
                    // BUT, usually in these problems, we just sum the counts or arrange them to minimize value? 
                    // The prompt says "Calculate (prefix_value * 10000) % 7 where prefix_value is the remaining digits".
                    // This implies we need to construct a value. But we can rearrange. 
                    // Let's assume we arrange the prefix digits in the smallest possible order to form a number, then check mod.
                    // Actually, the goal is to find a permutation of 1689 that works.
                    // So we just need the mod of the prefix.
                    // Let's sum the values of the remaining digits modulo 7? No, order matters.
                    // However, the prompt "Calculate (prefix_value * 10000) % 7" suggests we treat prefix as a number.
                    // Wait, if we can rearrange prefix, we can achieve many mods. 
                    // Let's look at the "Permutation search" instruction: It takes prefix_mod as input to find the suffix.
                    // This implies prefix_mod is a fixed property of the set of digits.
                    // Actually, usually in these problems, we append 4 digits to the prefix. 
                    // The value is prefix * 10000 + suffix.
                    // We need (prefix * 10000 + suffix) % 7 == 0.
                    // Since 10000 % 7 is 4 (actually 10000 / 7 = 1428 rem 4? 7*1428=9996, rem 4).
                    // Wait, let me re-read "Calculate (prefix_value * 10000) % 7".
                    // If we sum digits in base 10, order matters. 
                    // BUT, the mapping provided maps `prefix_mod` (0-6) to specific permutations.
                    // This mapping is derived assuming prefix digits are arranged in a specific way (probably ascending).
                    // OR, it assumes we can arrange the prefix digits to achieve a specific modulo?
                    // Let's look at standard "Rearrange Array to form largest number divisible by X". 
                    // Usually, we sum digits. But here it's a specific base-10 integer.
                    // Let's implement a loop that iterates through the counts and builds the number modulo 7.
                    // Since we don't know the exact order of digits in the input (just counts), 
                    // and the problem asks for "prefix_value" (singular), it implies we must use the given order? 
                    // No, "Rearrange" implies we can order.
                    // Let's assume the problem implies we arrange the prefix digits in ASCENDING order to form the smallest valid number (or just a deterministic one).
                    // Let's check the logic: "Calculate (prefix_value * 10000) % 7". 
                    // If we arrange prefix as [largest to smallest] or [smallest to largest], the value changes.
                    // BUT, since we are going to search for a suffix that satisfies the condition, we only need ONE valid prefix arrangement.
                    // The mapping provided (0->1869, etc.) is for a specific input set? No, it's general.
                    // Wait, the mapping depends on `prefix_mod`.
                    // So we must compute `prefix_mod` based on the remaining digits.
                    // To do this deterministically, we should arrange the prefix digits in a specific way (e.g., ascending) before calculating mod.
                    // Let's assume we arrange the prefix digits in ascending order.
                    // So we need to construct the number from counts in ascending order (00...11...22...).
                    // We can do this iteratively.
                    // Let's use a loop in hardware? No, we can do it in one state or a few cycles.
                    // Since total digits <= 8, we can iterate 10 times (digits 0-9).
                end

                FIND_PERMUTATION: begin
                    // Lookup based on prefix_mod
                    case (prefix_mod)
                        0: begin perm_digits <= 16'h1869; perm_len <= 4; end
                        1: begin perm_digits <= 16'h1896; perm_len <= 4; end
                        2: begin perm_digits <= 16'h1986; perm_len <= 4; end
                        3: begin perm_digits <= 16'h1698; perm_len <= 4; end
                        4: begin perm_digits <= 16'h6198; perm_len <= 4; end
                        5: begin perm_digits <= 16'h1689; perm_len <= 4; end
                        6: begin perm_digits <= 16'h1968; perm_len <= 4; end
                        default: begin perm_digits <= 0; perm_len <= 0; end
                    endcase
                    // Check validity: if special_count < 4, then we don't have enough digits to form the suffix.
                    // But the problem says "Remove one instance each of '1', '6', '8', '9'".
                    // If they don't exist, we cannot remove them. The problem states "up to 8 digits".
                    // If the input doesn't contain 1689, valid should probably be 0.
                    // However, the problem says "Remove one instance". This implies they exist if we want a valid result.
                    // Let's add a check: if any of counts of 1,6,8,9 (pre-decrement) were 0, valid <= 0.
                    // Actually, the problem says "Remove one instance". If we can't, maybe it's invalid.
                    // Let's assume valid is high only if we found the suffix and the prefix exists.
                    // In REMOVE_SPECIAL state, we decremented. We can check validity there or here.
                    // Let's check validity in REMOVE_SPECIAL or just before FIND_PERMUTATION.
                end

                CONSTRUCT_RESULT: begin
                    // We need to output: prefix + permutation + zeros.
                    // Prefix: digits arranged in some order (ascending?).
                    // Zeros: any '0's in the prefix count? No, the problem says "append zeros".
                    // Wait, standard "Digit Rearrangement" problem: 
                    // Usually: 1. Count digits. 2. Remove 1,6,8,9. 3. The remaining are prefix. 4. Append permutation. 5. Any extra 0s are appended? 
                    // "Result construction: arrange prefix digits, append permutation, append zeros".
                    // Usually, zeros are removed from the prefix and appended at the end (to minimize value or just formatting).
                    // Example: 10689. Prefix: 0. Zeros: 1 (the zero). Permutation: 1869. Result: 0 1869 0? No.
                    // Standard: If we have zeros, we usually put them after the non-zero prefix but before permutation? No.
                    // Let's check the "Result construction" instruction strictly.
                    // "arrange prefix digits, append permutation, append zeros".
                    // This suggests: (Prefix) + (Permutation) + (Zeros).
                    // But usually, if we have 0s, we want to avoid leading zeros (unless the number is 0).
                    // However, the output is fixed width? `result [39:0]` (10 digits). 
                    // If the number has fewer than 10 digits, how is it padded? 
                    // `result_length` tells us the length.
                    // Let's assume we construct the number by iterating through counts of 0-9 (except 1,6,8,9) to form prefix.
                    // BUT, we removed 1 instance of 1,6,8,9. So counts are updated.
                    // What about extra 0s? The prompt says "append zeros". 
                    // Usually, in these problems, if we have zeros in the input, they become part of the number.
                    // EXCEPT, if the number starts with 0, that's usually not allowed (unless it's just 0).
                    // However, the prompt specifically says "arrange prefix digits, append permutation, append zeros".
                    // Let's assume "zeros" here refers to the remaining 0s in the count after forming the prefix?
                    // No, wait. "Zeros" are likely the zeros that were removed from the prefix to be appended at the end.
                    // Why? Because if prefix is 0, and we append 1689, we get 01689 which is 1689. 
                    // If we have 10 zeros, and 1,6,8,9, we get 100...01689. 
                    // The prompt says "arrange prefix digits, append permutation, append zeros".
                    // This implies we output all non-special digits (ordered), then the special permutation, then the 0s.
                    // But usually, 0s are treated specially. 
                    // Let's look at the standard problem: "Largest number divisible by 7 by rearranging digits".
                    // Usually: 
                    // 1. Count digits.
                    // 2. Remove 1, 6, 8, 9.
                    // 3. The remaining are prefix. 
                    // 4. We arrange prefix. Usually, we sort ascending. BUT we need to handle leading zeros.
                    //    If prefix has digits, we usually put them in ascending order (smallest to largest).
                    //    But we need (prefix * 10000) % 7.
                    //    If we arrange ascending, the value is fixed.
                    //    Let's check the mapping. 
                    //    Mapping: 0->1869, 1->1896...
                    //    This mapping works if prefix_mod is calculated based on the remaining digits arranged in a specific order.
                    //    The problem says "Calculate (prefix_value * 10000) % 7".
                    //    If we can rearrange prefix arbitrarily, we can get ANY remainder (maybe). 
                    //    BUT the mapping is fixed. This implies we cannot arbitrarily change the remainder.
                    //    Wait, 10000 mod 7 = 4.
                    //    We need (Val * 4 + Perm) % 7 = 0.
                    //    Perm values: 1869, 1896... 
                    //    Let's calculate Perm % 7:
                    //    1869 / 7 = 267 rem 0. (Wait, 7*267=1869). 
                    //    1896 / 7 = 270 rem 6? 7*270=1890, rem 6.
                    //    1986 / 7 = 283 rem 5? 7*283=1981, rem 5.
                    //    1698 / 7 = 242 rem 4? 7*242=1694, rem 4.
                    //    6198 / 7 = 885 rem 3? 7*885=6195, rem 3.
                    //    1689 / 7 = 241 rem 2? 7*241=1687, rem 2.
                    //    1968 / 7 = 281 rem 1? 7*281=1967, rem 1.
                    //    So the mapping is:
                    //    Perm % 7 = 0, 6, 5, 4, 3, 2, 1 for mods 0-6.
                    //    Equation: (P * 4 + S) % 7 = 0.
                    //    If P = 0, need S = 0 -> 1869. 
                    //    If P = 1, need 4 + S = 0 mod 7 -> S = 3. But 1->1896 (rem 6). 
                    //    Wait, check calculation again.
                    //    1896 % 7: 1896 / 7 = 270.857. 7*270=1890. 1896-1890=6.
                    //    1986 % 7: 7*283=1981. 1986-1981=5.
                    //    1698 % 7: 7*242=1694. 1698-1694=4.
                    //    6198 % 7: 7*885=6195. 6198-6195=3.
                    //    1689 % 7: 7*241=1687. 1689-1687=2.
                    //    1968 % 7: 7*281=1967. 1968-1967=1.
                    //    So the provided mapping in prompt: 
                    //    0->1869 (rem 0)
                    //    1->1896 (rem 6)
                    //    2->1986 (rem 5)
                    //    3->1698 (rem 4)
                    //    4->6198 (rem 3)
                    //    5->1689 (rem 2)
                    //    6->1968 (rem 1)
                    //    Let's check the equation: (P * 10000 + S) % 7 = 0.
                    //    10000 % 7 = 4.
                    //    (P*4 + S) % 7 = 0.
                    //    If P=0: S%7 must be 0. -> 1869. OK.
                    //    If P=1: 1*4 + S = 0 mod 7 -> S = 3 mod 7. But mapping gives 1896 (rem 6). 
                    //    There is a discrepancy. 
                    //    Maybe 10000 is not the multiplier? Or mapping is for (prefix_mod * something).
                    //    Wait, maybe `prefix_mod` in the prompt is defined differently.
                    //    "Calculate (prefix_value * 10000) % 7"
                    //    Maybe `prefix_value` is the number formed by digits, but we can permute digits.
                    //    However, we cannot change the modulo of the set of digits freely.
                    //    Let's trust the prompt's mapping and description.
                    //    The prompt says: "Find a permutation of '1689' such that (prefix_mod * 10000 + perm_value) % 7 == 0"
                    //    AND "Hardcoded mapping: prefix_mod=0->1869..."
                    //    So I should just implement the logic: Calculate P, then pick S.
                    //    The calculation of P must be done such that it matches the mapping.
                    //    "Calculate (prefix_value * 10000) % 7"
                    //    If we calculate P based on the digits (somehow), we map to S.
                    //    Let's assume the prompt's mapping is correct for the specific calculation method.
                    //    The standard method for this specific puzzle (Divisible by 7) usually sums digits? No.
                    //    Actually, there is a known problem: "Rearrange digits to form number divisible by 7".
                    //    The logic involves dividing by 7.
                    //    But since we are given a specific FSM and mapping, I will implement exactly that.
                    //    I will compute `prefix_mod` by simulating the number formed by the remaining digits.
                    //    BUT, I need to arrange them. 
                    //    "Result construction: arrange prefix digits, append permutation, append zeros"
                    //    If we arrange prefix digits in ASCENDING order (smallest to largest), we get a specific value.
                    //    Let's try that.
                    //    Wait, if we arrange ascending, the value is minimal. 
                    //    Let's re-read carefully: "Calculate (prefix_value * 10000) % 7".
                    //    Maybe `prefix_value` is just the integer value of the set of digits (some order).
                    //    Since we have to output the rearranged number, we have to choose an order.
                    //    The order is usually: Prefix digits (remaining) + Permutation + Zeros.
                    //    But the Permutation depends on the Modulo of the Prefix.
                    //    This is cyclic.
                    //    Let's assume we arrange the prefix digits in ASCENDING order.
                    //    This is the most standard way to get a deterministic value.
                    //    Let's implement the modulo calculation for ascending order.
                    //    Wait, if we arrange ascending, we have leading zeros if we have zeros.
                    //    "append zeros" instruction might mean we remove 0s from the prefix set and append them at the end.
                    //    Standard puzzle logic: 
                    //    1. Count digits.
                    //    2. Remove 1, 6, 8, 9.
                    //    3. Count remaining.
                    //    4. If no non-zero digits remain, the prefix is empty (0).
                    //    5. If non-zero digits remain, arrange them in ascending order (smallest to largest).
                    //       But usually we want to minimize the number, so we put smallest non-zero first, then 0s, then others?
                    //       No, "arrange prefix digits" -> usually sorted.
                    //       BUT, if we sort 100... it becomes 001... which is invalid as a number representation usually.
                    //       However, `result` is 40 bits, so it can hold 10 digits. 
                    //       `result_length` tells us how many are valid.
                    //       If we have prefix digits: 0, 0, 1, 2. Sorted: 0, 0, 1, 2.
                    //       But the number 0012 is 12.
                    //       Usually in these puzzles, we output the digits directly.
                    //       If we output 0, 0, 1, 2 as prefix, that's 0012. 
                    //       But wait, the prompt says "append zeros".
                    //       "arrange prefix digits, append permutation, append zeros"
                    //       This suggests that zeros are NOT part of the prefix arrangement, but appended later.
                    //       Example: Input: 100689. 
                    //       Remove 1,6,8,9. Remaining: 0, 0.
                    //       Prefix: empty (0)? Or 0, 0?
                    //       Zeros to append: 0, 0.
                    //       Result: (empty) + (1869) + (00) = 186900.
                    //       Let's check if 186900 % 7 == 0. 186900 / 7 = 26700. Yes.
                    //       So "append zeros" likely means the 0s are moved to the end.
                    //       BUT what about other digits?
                    //       Input: 123689. 
                    //       Remove 1,6,8,9. Remaining: 2, 3.
                    //       Prefix: 2, 3. Zeros: none.
                    //       Result: 23 + Perm + (none).
                    //       Is 23... divisible by 7? We need to choose Perm.
                    //       So we calculate `prefix_value` using 23.
                    //       (23 * 10000) % 7 = (23 % 7) * 4 = 2 * 4 = 8 % 7 = 1.
                    //       `prefix_mod` = 1.
                    //       Mapping: 1 -> 1896.
                    //       Result: 231896.
                    //       Check: 231896 / 7 = 33128. Yes.
                    //       So the logic is:
                    //       1. Remove 1,6,8,9.
                    //       2. Collect all remaining non-zero digits. Sort them? 
                    //          Usually we arrange them to form a number. 
                    //          But we need `prefix_mod`.
                    //          If we arrange them in ascending order (smallest to largest), 
                    //          we get a specific value.
                    //       3. Collect remaining zeros.
                    //       4. Compute `prefix_mod` using the non-zero digits in ascending order.
                    //       5. Lookup permutation.
                    //       6. Construct result: (non-zero digits) + (permutation) + (zeros).
                    //       Wait, if we have digits like 2, 1. Ascending 1, 2 -> 12.
                    //       If we have 10. Ascending 0, 1 -> 01? 
                    //       But we said we separate zeros. So if we have 1, 0. 
                    //       Non-zero: 1. Zeros: 0.
                    //       Prefix value: 1.
                    //       Result: 1 + Perm + 0.
                    //       So we need to separate 0s from non-0s.
                    //       Sort non-0s ascending.
                    //       Count 0s.
                    //       Compute mod on sorted non-0s.
                    //       Construct output.
                    //       What if all digits are 0?
                    //       Non-zero: none. Prefix value: 0.
                    //       Perm: 1869.
                    //       Zeros: count.
                    //       Result: 1869 + zeros.
                    //       But wait, if all digits are 0, we have no 1,6,8,9. 
                    //       Then we can't remove them. Valid check.
                    //       So if we don't have 1,6,8,9, valid <= 0.
                    //       But the prompt says "Remove one instance each".
                    //       If input is "0", no 1,6,8,9. Logic fails.
                    //       Let's check requirements: "Inputs up to 8 digits".
                    //       "Valid rearrangement". 
                    //       Implies we need to have 1,6,8,9 to have a valid solution (unless prefix makes up for it, but the problem is usually specific to inputs containing these digits).
                    //       However, to be robust, if special_count < 4, we output valid=0.
                    
                    // Implementation Plan for CONSTRUCT_RESULT:
                    // We have `digit_count` for 0-9 (after removal).
                    // We need to output digits.
                    // We need to output: 
                    //   1. Non-zero digits (0-9, excluding 1,6,8,9? No, we removed one of each).
                    //      But wait, we might have extra 1,6,8,9. 
                    //      Example: Input has 2 ones. We remove 1. Remaining 1. 
                    //      So we output the remaining 1 in the prefix.
                    //      So we output all digits in `digit_count` (which are remaining).
                    //      But we need to separate zeros.
                    //      So iterate 1-9 (ascending). Output `count` times.
                    //      Then output permutation.
                    //      Then output zeros (`count` of 0).
                    //      This matches "arrange prefix digits (1-9 sorted), append permutation, append zeros".
                    //      Check mod calculation: 
                    //      We need to calculate mod of the prefix digits.
                    //      If we output 1, 2, 3 as prefix, number is 123.
                    //      If we output 0, 1 as prefix (if we didn't separate), it would be 01.
                    //      But we separate zeros. So prefix digits are only 1-9.
                    //      So we calculate mod using the digits 1-9 in ascending order.
                    //      Wait, if we have two 1s, they appear consecutively.
                    //      So we iterate 1 to 9, for each digit D, repeat count times.
                    //      We simulate this number mod 7.
                    //      Since max 8 digits, we can iterate 8 times in logic (or unroll).
                end
            endcase
        end
    end

    // We need combinational logic to transition states and handle the loop in COUNT_DIGITS and CONSTRUCT_RESULT.
    // Since we want to avoid complex logic inside the always block, let's use a combinational block for next_state.
    
    // Counter for loops
    reg [3:0] loop_idx;
    reg [3:0] extract_idx; // For extracting digits in COUNT_DIGITS state
    
    // Intermediate signal for modulo calculation in CONSTRUCT_RESULT state
    // We need to simulate the number formed by (1 repeated c1, 2 repeated c2, ... 9 repeated c9)
    // But we can't do this in one cycle easily if we want to be generic.
    // However, we have 120 cycles budget. We can spend 20 cycles for calculation.
    
    // Let's refine the CONSTRUCT_RESULT logic:
    // 1. Calculate Modulo of the "Prefix Number" (digits 1-9 in ascending order).
    //    Iterate through digits 1..9.
    //    For each digit D, repeat `digit_count[D]` times.
    //    Update `prefix_mod = (prefix_mod * 10 + D) % 7`.
    //    We can do this in a loop state or sequential logic within the state.
    //    Let's use a sub-state or counter within CONSTRUCT_RESULT.
    
    // Let's use a separate always block for next_state logic to handle loops.
    
    // Internal counters for loops
    reg [3:0] loop_digit;
    reg [3:0] loop_count;
    
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: if (start) next_state = COUNT_DIGITS;
            
            COUNT_DIGITS: begin
                // We need to process all digits.
                // Let's say we process one digit per cycle.
                if (current_digit_idx < num_digits) begin
                    next_state = COUNT_DIGITS;
                end else begin
                    next_state = REMOVE_SPECIAL;
                end
            end
            
            REMOVE_SPECIAL: begin
                // Done in 1 cycle
                // Check validity: did we have 1,6,8,9?
                // If any of the original counts (before decrement) were 0, valid should be 0.
                // But we don't have original counts saved separate from decremented.
                // We decremented in the sequential block. 
                // Wait, we decremented `digit_count`. So if they were 0, they stay 0 or wrap? No, `if >0` check prevents wrap.
                // We can check `digit_count` *after* decrement logic in the seq block.
                // But the seq block sets `digit_count` for next cycle.
                // To check validity, we need the state BEFORE decrement.
                // Let's move the decrement logic to combinational or check in REMOVE_SPECIAL state.
                // Actually, let's check in REMOVE_SPECIAL state using the `digit_count` available at entry.
                // But we need to check if we *had* them.
                // Let's use `special_count` calculated in REMOVE_SPECIAL state (seq block). 
                // If `special_count` < 4, it's invalid.
                // Wait, `special_count` was calculated in REMOVE_SPECIAL state based on `digit_count` BEFORE decrement?
                // In the seq block logic for REMOVE_SPECIAL:
                // `special_count <= (digit_count[1] > 0 ? 1 : 0) + ...` (uses old values)
                // `digit_count <= ...` (updates for next cycle).
                // So at the end of REMOVE_SPECIAL cycle, we have `special_count` and updated `digit_count`.
                // We can check `special_count`.
                // If `special_count < 4`, we go to DONE with valid=0.
                // Else, go to COMPUTE_PREFIX.
                // However, we need `digit_count` to be updated BEFORE COMPUTE_PREFIX.
                // The seq block updates `digit_count` in REMOVE_SPECIAL state.
                // So by the time we enter COMPUTE_PREFIX, `digit_count` is correct (decremented).
                // So transition logic: if (special_count < 4) next_state = DONE; else next_state = COMPUTE_PREFIX;
                // But wait, we need to wait for the decrement to happen. 
                // The transition happens at the end of the cycle. The seq block updates registers.
                // So yes, the check is valid.
                if (special_count < 4) next_state = DONE;
                else next_state = COMPUTE_PREFIX;
            end

            COMPUTE_PREFIX: begin
                // We need to calculate (Value * 10000) % 7.
                // Value is formed by digits 0-9 (except we removed 1,6,8,9). 
                // But we separated zeros. So Value is formed by digits 1-9 (excluding removed 1,6,8,9).
                // Wait, we didn't remove 1,6,8,9 from the set if we have multiple.
                // Example: Input has two 1s. Count becomes 1. We output that 1.
                // So we iterate 1..9. 
                // We need to simulate the number: S = D1 D1 D1... D2 D2... ... D9 D9...
                // To compute S % 7, we can use `((prev * 10) + digit) % 7`.
                // We need to repeat this for total count of digits.
                // Total digits remaining <= 8.
                // We can iterate through digits 1..9, and for each count, repeat the mod update.
                // Let's use a loop.
                // If we have 0 non-zero digits, prefix value is 0.
                // Let's count total non-zero digits remaining.
                // If total == 0, we can skip to FIND_PERMUTATION with prefix_mod = 0.
                // If total > 0, we loop.
                // We need to track: current digit (loop_digit), current repetition count (loop_count).
                // We can handle this in the state machine by staying in COMPUTE_PREFIX.
                // We'll use a counter 'loop_idx' to track progress.
                
                // Logic for transition:
                // If (total_non_zero == 0) -> FIND_PERMUTATION.
                // Else, we need to iterate. 
                // We can use sub-states or just a flag. Given 120 cycles, we can spend 20 here.
                // Let's define a helper logic: We need to iterate 1..9.
                // Let's assume we stay in this state and use a counter 'loop_digit' (1-9) and 'loop_count' (current digit count).
                // But 'loop_digit' and 'loop_count' need to be registers.
                // 
                // Let's simplify: In IDLE, calculate total non-zero digits. 
                // In COMPUTE_PREFIX, we iterate.
                // We need to know when we are done.
                // Let's say we iterate 1..9. For each digit D with count C > 0:
                //   Update Mod C times with D.
                // We can do this in one go.
                // Let's use `loop_idx` to iterate 0 to `total_non_zero_digits - 1`.
                // But we need to know which digit to append.
                // This requires generating the sequence of digits (e.g. 1,1,2,3,3,3).
                // This is hard without memory.
                // Alternative: Since max digits is 8, we can store the extracted digits (after removal) in a small buffer (8x4 = 32 bits).
                // But the instructions didn't specify a buffer.
                // Let's re-read: "Modulo computation: (current_mod * 10 + digit) % 7 for prefix".
                // Maybe we just sum the digits modulo 7? No, order matters for base 10.
                // But wait, the problem "Digit Rearrangement" usually allows rearranging prefix digits to achieve the desired mod.
                // But the prompt maps `prefix_mod` to suffix. 
                // IF we can rearrange prefix arbitrarily, we can get any mod?
                // No, sum of digits is fixed. But base-10 value changes.
                // However, we are given a mapping. So we must compute `prefix_mod` deterministically.
                // The standard way for this specific puzzle (Divisible by 7) is:
                // 1. Take remaining digits.
                // 2. Sort them in ascending order.
                // 3. Calculate the mod of that number.
                // 4. Append the correct suffix.
                // 5. Append zeros.
                // So we must generate the sorted sequence.
                // Since we don't have RAM, we can generate the sequence on the fly.
                // We iterate 1..9. 
                // We need a state machine within the state? Or just one long state.
                // We have 120 cycles. We can spend 20 cycles to calculate the mod.
                // Let's use a loop.
                // We need a register for `current_mod`. Initialize to 0.
                // We need a register for `remaining_count`. Initialize to sum of counts of 1..9.
                // We need a register for `current_digit_idx` (1..9).
                // We need a register for `repetitions_left` for the current digit.
                // 
                // Algorithm:
                // 1. If `remaining_count` == 0, done.
                // 2. If `repetitions_left` == 0, move to next digit (1->2->...->9).
                // 3. If `repetitions_left` > 0:
                //    `current_mod = (current_mod * 10 + current_digit_idx) % 7`.
                //    `repetitions_left`--.
                //    `remaining_count`--.
                //    Go to step 1.
                // This takes `total_non_zero` cycles.
                // Max 8 cycles. Very fast.
                // So COMPUTE_PREFIX will be a state that stays for `total_non_zero` cycles.
                // We need to detect when we are done to transition.
                // We can use a 'computation_done' flag.
            end

            FIND_PERMUTATION: begin
                // 1 cycle to lookup.
                next_state = CONSTRUCT_RESULT;
            end

            CONSTRUCT_RESULT: begin
                // We need to output the digits.
                // We can output one digit per cycle.
                // Sequence: 
                // 1. Non-zero digits (1..9, sorted, according to remaining counts).
                //    (Note: We decremented counts in REMOVE_SPECIAL, so `digit_count` holds what to output).
                // 2. Permutation digits (4 digits).
                // 3. Zero digits (count of 0).
                // Total output length = (sum of counts 1..9) + 4 + (count of 0).
                // Max 8 + 4 + 8 = 20 digits. But output buffer is 10 digits (40 bits).
                // Wait, "output reg [39:0] result // 10 digits packed as 4 bits each".
                // Max 10 digits. So output length <= 10.
                // Input is up to 8 digits. Output is prefix + suffix + zeros.
                // If input is 8 digits, we remove 4, add 4. Total 8. OK.
                // If input is 8 digits + zeros? Input is up to 8 digits.
                // So max length is 8 (prefix+zeros) + 4 (suffix) ? No.
                // If input has zeros, they are part of face.
                // Wait, if input has zeros, they are counted. 
                // Prefix: non-zero digits. Zeros: appended at end.
                // So total length = (count of non-zero remaining) + 4 + (count of zero).
                // Since total digits is 8, this is always <= 8 + 4? No.
                // If input is "0", length is 1. We remove nothing? No, we need 1,6,8,9.
                // If input is "10689", we remove 1,6,8,9. Remaining: 0.
                // Prefix: empty. Zeros: 1. Suffix: 1869. Result: 18690. Length 5.
                // OK.
                // So we iterate.
                // We need to output digits in order.
                // Phase 1: Non-zero (1..9). Iterate 1..9, print `count` times.
                // Phase 2: Permutation. Print 4 digits.
                // Phase 3: Zeros. Print `count[0]` times.
                // We need to track where we are.
                // We can use `loop_digit` (current digit 0..9 for phase 1, phase 2, phase 3).
                // Or split into sub-states.
                // Given 120 cycles, we can do this sequentially.
                // Let's use `loop_digit` to track the digit to output, and `loop_count` for repetition.
                // We can use a state variable `output_phase`: 0 (non-zero), 1 (suffix), 2 (zeros).
                
                // Transition: when all output is written.
                // Total length = (sum 1..9 counts) + 4 + (count 0).
                // We can calculate total length in previous state.
                // Let's calculate `result_length` in FIND_PERMUTATION or COMPUTE_PREFIX.
                // Then we just output until `out_digit_idx` == `result_length`.
            end

            DONE: begin
                next_state = IDLE; // Or stay in DONE until start goes low? Usually auto-return to IDLE.
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
        endcase
    end

    // Sequential Logic Implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            valid <= 0;
            result <= 0;
            result_length <= 0;
            for (i = 0; i < 10; i = i + 1) digit_count[i] <= 0;
            current_digit_idx <= 0;
            prefix_mod <= 0;
            cycle_count <= 0;
            // Reset loop counters
            loop_idx <= 0;
            loop_digit <= 0;
            loop_count <= 0;
            // Reset internal state
            temp_digit <= 0;
        end else begin
            current_state <= next_state;
            
            // Latency counter (just to show usage, though not strictly needed for logic)
            if (current_state != IDLE && current_state != DONE) cycle_count <= cycle_count + 1;

            case (current_state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    result <= 0;
                    result_length <= 0;
                    cycle_count <= 0;
                    if (start) begin
                        // Initialize loop index for extraction
                        current_digit_idx <= 0;
                        // Initialize digit counts to 0
                        for (i = 0; i < 10; i = i + 1) digit_count[i] <= 0;
                    end
                end

                COUNT_DIGITS: begin
                    if (current_digit_idx < num_digits) begin
                        // Extract digit
                        temp_digit <= digit_vector[current_digit_idx * 4 +: 4];
                        // We will increment current_digit_idx. 
                        // But we need to update count for THIS digit.
                        // We need to register the previous extracted digit to count it.
                        // Or update count based on `temp_digit` from previous cycle.
                        // Let's update count based on `temp_digit`.
                        // But `temp_digit` is updated this cycle. 
                        // So we need a separate register for the "digit to count".
                        // Let's use `prev_digit`.
                        // Actually, simpler: Update count of `digit_vector[current_digit_idx]` directly.
                        // But `current_digit_idx` increments. 
                        // If we use `current_digit_idx` to index, we update `digit_count[digit_vector[current_digit_idx]]`.
                        // This updates the count for the current index in the same cycle.
                        // Then we increment `current_digit_idx`.
                        // This works if `digit_vector` is static during the state.
                        
                        // Let's do:
                        digit_count[digit_vector[current_digit_idx * 4 +: 4]] <= digit_count[digit_vector[current_digit_idx * 4 +: 4]] + 1;
                        current_digit_idx <= current_digit_idx + 1;
                    end
                end

                REMOVE_SPECIAL: begin
                    // Decrement counts
                    if (digit_count[1] > 0) digit_count[1] <= digit_count[1] - 1;
                    if (digit_count[6] > 0) digit_count[6] <= digit_count[6] - 1;
                    if (digit_count[8] > 0) digit_count[8] <= digit_count[8] - 1;
                    if (digit_count[9] > 0) digit_count[9] <= digit_count[9] - 1;
                    
                    // Calculate special count for validation
                    // We must use the OLD values of digit_count here.
                    // But we are updating them. 
                    // We can compute `special_count` combinationally or store it before update?
                    // Since we need it for the transition, and updates happen now, we should compute based on current values.
                    // Wait, if we compute `special_count` inside this state logic, it uses the OLD values (before update) if we are careful.
                    // But `digit_count` assignment happens non-blocking. So `digit_count[1]` in the expression is the OLD value.
                    // So `special_count <= (digit_count[1] > 0) + ...` is correct.
                    // However, we need `special_count` for the `next_state` logic. 
                    // The `next_state` logic is combinational. It sees the OLD `special_count` if it wasn't updated in IDLE.
                    // So we MUST update `special_count` in REMOVE_SPECIAL state so it is available for the transition check.
                    // Wait, transition check happens at end of cycle. 
                    // So we compute `special_count` inside the state logic.
                    // We can do it here:
                    special_count <= (digit_count[1] > 0 ? 1'b1 : 1'b0) + (digit_count[6] > 0 ? 1'b1 : 1'b0) + 
                                     (digit_count[8] > 0 ? 1'b1 : 1'b0) + (digit_count[9] > 0 ? 1'b1 : 1'b0);
                    // But wait, if we check `special_count < 4` in combinational logic, and `special_count` is updated in this block, 
                    // the combinational logic sees the OLD value (unless we are in the same always block, but we separated them).
                    // In Verilog, non-blocking <= updates the register. The combinational `always @(*)` reads the register value.
                    // So if `next_state` depends on `special_count`, and `special_count` is updated in `current_state` = REMOVE_SPECIAL,
                    // then `next_state` will see the OLD value of `special_count` (from previous cycle).
                    // To fix this, we must either:
                    // 1. Put next_state logic in the same sequential block (blocking assignments).
                    // 2. Update `special_count` in the PREVIOUS state (IDLE or COUNT_DIGITS).
                    
                    // Let's calculate `special_count` in REMOVE_SPECIAL using blocking assignment for immediate use in `next_state` calculation.
                    // Actually, let's just calculate `special_count` in the combinational block.
                    // But `special_count` is a register. 
                    // Let's just check `digit_count[1], digit_count[6]...` directly in the combinational block for transition logic.
                    // That avoids the register sync issue.
                end

                COMPUTE_PREFIX: begin
                    // Logic for modulo calculation loop.
                    // We need to iterate through 1..9 and repeat based on counts.
                    // Let's use registers `loop_digit` (1 to 9) and `loop_count` (current count of `loop_digit`).
                    // We also use `prefix_mod` register.
                    
                    // Initialization: We need to initialize `loop_digit` to 1 and `loop_count` to `digit_count[1]` at the start of this state.
                    // But how do we know it's the start? We can check if `loop_digit` == 0 or `loop_digit` > 9.
                    // Let's initialize in the transition from REMOVE_SPECIAL -> COMPUTE_PREFIX.
                    // But transitions happen in combinational block. 
                    // We can use a flag or check if `prefix_mod` is initialized (but prefix_mod might be 0).
                    // Let's use `loop_idx` as a state counter. 0: init, 1: process.
                    // Actually, let's just process one digit per cycle.
                    // If `loop_digit` is 0, it means we haven't started. Set `loop_digit` to 1, `loop_count` to `digit_count[1]`.
                    // If `loop_digit` > 9, we are done (transition handled in comb block).
                    // Else, if `loop_count` > 0:
                    //   `prefix_mod = (prefix_mod * 10 + loop_digit) % 7`.
                    //   `loop_count`--.
                    //   If `loop_count` becomes 0, increment `loop_digit`, set `loop_count` to `digit_count[new_digit]`.
                    
                    // Let's implement this logic.
                    if (loop_digit == 0) begin
                        // Start of computation
                        loop_digit <= 1;
                        loop_count <= digit_count[1];
                        prefix_mod <= 0;
                    end else if (loop_digit <= 9) begin
                        if (loop_count > 0) begin
                            // Update mod
                            prefix_mod <= (prefix_mod * 10 + loop_digit) % 7;
                            loop_count <= loop_count - 1;
                        end else begin
                            // Move to next digit
                            loop_digit <= loop_digit + 1;
                            // Need to get next count. 
                            // But we can't index digit_count with a variable in a synthesis-friendly way easily without a case statement or memory.
                            // However, we can use a lookup or just loop 1..9 and check `if (digit_count[loop_digit+1] > 0)`? 
                            // No, we need the exact count to loop.
                            // Since 10 is small, we can use a case statement or a series of ifs.
                            // Or, we can unroll the loop.
                            // Given the limit of 8 digits, let's assume we iterate 1..9.
                            // If `loop_count` is 0, we increment `loop_digit`. 
                            // We need to load `loop_count` for the NEW `loop_digit`.
                            // We can do this with a combinational lookup if we want to keep it simple.
                            // But let's try to keep it sequential.
                            // We can just check `digit_count[loop_digit + 1]` in the next cycle.
                            // But `loop_digit` is a register.
                            // `digit_count` is an array of registers.
                            // `digit_count[loop_digit + 1]` is valid in hardware (combinational read).
                            loop_count <= digit_count[loop_digit + 1];
                        end
                    end
                end

                FIND_PERMUTATION: begin
                    // Just lookup
                    case (prefix_mod)
                        0: perm_digits <= 16'h1869;
                        1: perm_digits <= 16'h1896;
                        2: perm_digits <= 16'h1986;
                        3: perm_digits <= 16'h1698;
                        4: perm_digits <= 16'h6198;
                        5: perm_digits <= 16'h1689;
                        6: perm_digits <= 16'h1968;
                        default: perm_digits <= 0;
                    endcase
                    // Also calculate total result length here for the output loop.
                    // Length = sum(digit_count[1..9]) + 4 + digit_count[0]
                    result_length <= (digit_count[1] + digit_count[2] + digit_count[3] + digit_count[4] + 
                                      digit_count[5] + digit_count[6] + digit_count[7] + digit_count[8] + 
                                      digit_count[9]) + 4 + digit_count[0];
                    // Reset output index
                    out_digit_idx <= 0;
                    // Reset loop vars for output
                    loop_digit <= 1; // Start checking non-zero digits from 1
                    loop_count <= digit_count[1]; // Preload count for 1
                end

                CONSTRUCT_RESULT: begin
                    // We need to shift result and insert digits.
                    // Result is [39:0], 10 digits. We can build it by left shifting or indexing.
                    // Since we know the length, we can write to specific positions.
                    // Let's use `out_digit_idx` to track current output position (0 to length-1).
                    // We need to determine which digit to write.
                    // Sequence: 
                    //   Phase 1: Non-zero (1..9). 
                    //   Phase 2: Perm (4 digits).
                    //   Phase 3: Zeros.
                    
                    // We can use a control signal or state within state.
                    // Let's use `loop_digit` for Phase 1 (tracking 1..9).
                    // We need a phase flag. Let's use `loop_count` > 0 or special values.
                    // 
                    // Phase 1 Logic:
                    // If `loop_digit` <= 9:
                    //   If `loop_count` > 0:
                    //     Write `loop_digit` to `result[out_digit_idx*4 +: 4]`.
                    //     `out_digit_idx`++, `loop_count`--.
                    //   Else:
                    //     `loop_digit`++, load `loop_count` from `digit_count[loop_digit+1]`.
                    // 
                    // Transition to Phase 2: If `loop_digit` > 9.
                    // 
                    // Phase 2 Logic:
                    // Write 4 digits from `perm_digits`.
                    // We need a counter for this. `loop_count` can be reused.
                    // 
                    // Phase 3 Logic:
                    // Write `digit_count[0]` zeros.
                    
                    // Let's implement this with flags. We need to know if we are in Phase 1, 2, or 3.
                    // We can use `loop_digit` = 10 to indicate Phase 2.
                    // `loop_digit` = 11 to indicate Phase 3.
                    // 
                    // Detailed Logic:
                    
                    // If we are in Phase 1 (loop_digit 1..9):
                    if (loop_digit <= 9) begin
                        if (loop_count > 0) begin
                            // Write digit
                            result[out_digit_idx * 4 +: 4] <= loop_digit;
                            out_digit_idx <= out_digit_idx + 1;
                            loop_count <= loop_count - 1;
                        end else begin
                            // Move to next digit
                            loop_digit <= loop_digit + 1;
                            // Check if we exceeded 9
                            if (loop_digit < 9) begin
                                // Load next count. Need to be careful with index.
                                // We increment loop_digit. So we want count for NEW loop_digit.
                                // If loop_digit was 1, we loaded count for 2.
                                // Actually, we just incremented `loop_digit`. So we want `digit_count[loop_digit]`.
                                // But `loop_digit` is a register, update is non-blocking. 
                                // So we are loading for the *next* value.
                                // Let's load `digit_count[loop_digit + 1]`.
                                // Wait, if `loop_digit` was 1, `loop_count` was for 1. Now we want for 2.
                                // `loop_digit` updates to 2 in this cycle. But the RHS uses OLD `loop_digit`.
                                // So we should use `digit_count[loop_digit + 1]` (where loop_digit is OLD, i.e., 1). -> 2.
                                // If loop_digit was 9 and count=0, we set loop_digit=10.
                                // We don't load count.
                                if (loop_digit < 9) loop_count <= digit_count[loop_digit + 1];
                            end else begin
                                // loop_digit became 10. Transition to Phase 2.
                                // We set loop_count for Phase 2 (4 iterations).
                                loop_count <= 4;
                                // We need to write perm_digits. We need an index for perm_digits.
                                // Let's use `loop_digit` = 10 to signify Phase 2.
                                // Actually, we set `loop_digit` to 10 here.
                                loop_digit <= 10;
                            end
                        end
                    end
                    // Phase 2
                    else if (loop_digit == 10) begin
                        // Write permutation digits
                        if (loop_count > 0) begin
                            // We need to pick from perm_digits.
                            // perm_digits is 16 bits. {D3, D2, D1, D0} ? Or MSB first?
                            // Let's assume MSB is first digit (1869 -> 0x1869).
                            // 0x1 = 1, 0x8 = 8, 0x6 = 6, 0x9 = 9.
                            // So index 0 is 4 bits [15:12], index 1 is [11:8], etc.
                            // We need a counter for perm index. `loop_count` is 4,3,2,1.
                            // If `loop_count` is 4, we want index 0 (MSB). 
                            // If `loop_count` is 1, we want index 3 (LSB).
                            // Index = 4 - loop_count.
                            result[out_digit_idx * 4 +: 4] <= perm_digits[16 - loop_count * 4 +: 4];
                            out_digit_idx <= out_digit_idx + 1;
                            loop_count <= loop_count - 1;
                        end else begin
                            // Phase 3
                            loop_digit <= 11;
                            loop_count <= digit_count[0]; // Load zero count
                        end
                    end
                    // Phase 3
                    else if (loop_digit == 11) begin
                        if (loop_count > 0) begin
                            result[out_digit_idx * 4 +: 4] <= 0;
                            out_digit_idx <= out_digit_idx + 1;
                            loop_count <= loop_count - 1;
                        end else begin
                            // Done
                            // Transition to DONE handled by comb logic.
                            // We need to ensure we stay here until finished.
                        end
                    end
                end

                DONE: begin
                    // Set done and valid
                    done <= 1;
                    if (special_count < 4) begin
                        valid <= 0;
                    end else begin
                        valid <= 1;
                    end
                    // Reset loop vars for next run
                    loop_digit <= 0;
                    loop_count <= 0;
                end
            endcase
        end
    end

    // Combinational logic for transitions
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: if (start) next_state = COUNT_DIGITS;
            
            COUNT_DIGITS: if (current_digit_idx >= num_digits) next_state = REMOVE_SPECIAL;
            
            REMOVE_SPECIAL: begin
                // Check validity immediately using current counts
                // Note: In REMOVE_SPECIAL sequential block, we update counts and special_count.
                // But here we need to decide next state.
                // Since we are in REMOVE_SPECIAL state, the sequential block hasn't executed yet for this cycle's edge.
                // So `digit_count` here is still from previous state (COUNT_DIGITS).
                // We need to check if we have 1,6,8,9.
                // Actually, we need to check if we HAD them. 
                // The decrement happens in REMOVE_SPECIAL state logic. 
                // So if we are entering REMOVE_SPECIAL, we check what we had in COUNT_DIGITS.
                // But we are deciding to LEAVE REMOVE_SPECIAL.
                // At the end of REMOVE_SPECIAL cycle, `digit_count` is updated.
                // We should check if the operation was valid (i.e., we had the digits).
                // We can compute validity now:
                bit valid_move;
                valid_move = (digit_count[1] > 0) && (digit_count[6] > 0) && (digit_count[8] > 0) && (digit_count[9] > 0);
                
                if (!valid_move) next_state = DONE;
                else next_state = COMPUTE_PREFIX;
            end

            COMPUTE_PREFIX: begin
                // We need to wait for the loop to finish.
                // Loop finishes when `loop_digit` becomes 10 (or >9).
                // But `loop_digit` is a register. 
                // The transition logic happens in the same cycle as the update.
                // So if `loop_digit` becomes 10 in this cycle, we should transition.
                // However, `loop_digit` update is non-blocking. So here `loop_digit` is still OLD.
                // This is a classic Verilog problem.
                // To solve this, we can use a 'done_flag' or calculate 'is_done' combinationally.
                // `is_done` = (loop_digit == 9 && loop_count == 0) OR (loop_digit == 9 && digit_count[9] == 0).
                // Actually, we need to track when the *last* digit is processed.
                // Let's define `loop_done` signal.
                // `loop_done` is true if `loop_digit` is 9, `loop_count` is 0, AND we have no more digits (but we don't know that easily).
                // Better: Check if `loop_digit` > 9. 
                // But `loop_digit` updates to 10 at the END of the last cycle.
                // So we need to check if we are processing the last item.
                
                // Let's use a flag or just rely on the state duration.
                // Since we know the max length (8), we can count cycles or just check if we are done.
                // Let's define `compute_done`.
                // If `loop_digit` > 9, we are done. 
                // But `loop_digit` becomes 10 only when we finish 9.
                // If `digit_count[9]` is 0, we jump from 8 to 10.
                // We can check: `loop_digit == 9 && loop_count == 0`.
                // What if `digit_count[9]` is 0? Then `loop_digit` becomes 10 immediately after 8.
                // So check `loop_digit == 10` is not reliable in combinational logic because it updates non-blocking.
                // We can check `loop_digit == 9 && loop_count == 0 && digit_count[9] == 0` ? No.
                // We can check `loop_digit > 9` but use `next_loop_digit` logic.
                // Let's just check if `loop_digit` is 9 AND `loop_count` is 0.
                // If we are at 9 and finished it, we are done.
                // What if we skipped 9 because count was 0? `loop_digit` goes 8->10.
                // In that case, `loop_digit` will be 10 at the start of the cycle where we transition.
                // But in the combinational block, `loop_digit` is 8 (old) or 9 (old) or 10 (if we were in phase 2).
                // This is tricky.
                
                // Solution: Add a `compute_done` register.
                // Set `compute_done` in sequential logic when finished.
                // Or simpler: Since we have 120 cycles, we can just wait 10 cycles.
                // But we want to be efficient.
                
                // Let's use a `loop_finished` combinational signal.
                // `loop_finished` = 1 if:
                //   Current `loop_digit` is 9, `loop_count` is 0. (Just finished 9).
                //   OR `loop_digit` > 9. (Should not happen in comb logic if we transition immediately).
                //   Wait, if `loop_digit` is 8, `loop_count` is 0. Next state `loop_digit` becomes 9.
                //   We need to look ahead? No.
                //   Let's use a flag `last_digit_processed`.
                //   We can calculate if the current state will finish the loop.
                //   
                //   Let's try this: If `loop_digit` is the last digit (9), and we just decremented `loop_count` to 0.
                //   This is hard.
                // 
                //   Let's add a `computation_done` register in the sequential block.
                //   In COMPUTE_PREFIX state:
                //     if (loop_count > 0) ...
                //     else if (loop_digit < 9) ...
                //     else if (loop_digit == 9) begin
                //       // Just finished 9
                //       computation_done <= 1;
                //     end
                //   And check `computation_done` in transition.
                //   Reset `computation_done` in IDLE.
            end
            // Correction for COMPUTE_PREFIX transition:
            // Let's assume we stay in COMPUTE_PREFIX for at most 8 cycles (or 10).
            // We can just check `loop_digit == 10` or `(loop_digit == 9 && loop_count == 0)`. 
            // But `loop_digit` is non-blocking.
            // Let's add a `sub_state` for COMPUTE_PREFIX or use a counter.
            // Given the complexity, let's just check if `loop_digit > 9` (if we update it to 10 when done).
            // But to make it safe, we can add a delay or just check `loop_digit`.
            // 
            // Let's modify the plan:
            // In COMPUTE_PREFIX, we use `loop_digit` and `loop_count`.
            // When we finish, we set `loop_digit` to 10.
            // In the combinational block, we check `if (loop_digit == 10) next_state = FIND_PERMUTATION;`.
            // But `loop_digit` is updated in the sequential block. 
            // So at the time of `next_state` evaluation, `loop_digit` is OLD.
            // If `loop_digit` is 9, `loop_count` is 1. We process it. `loop_count` becomes 0.
            // Next cycle, `loop_digit` becomes 10.
            // So we stay in COMPUTE_PREFIX one extra cycle? 
            // If `loop_digit` is 9, `loop_count` is 0. We process nothing, set `loop_digit` to 10.
            // Then next cycle transition.
            // So we need to stay in state until `loop_digit` becomes 10.
            // But we can't see `loop_digit` becoming 10 in the cycle it happens.
            // We can check `loop_digit == 9 && loop_count == 0 && !something`.
            // If `loop_digit` is 9 and `loop_count` is 0, we are done. 
            // But wait, if `digit_count[9]` is 0, `loop_digit` jumps from 8 to 10.
            // In that case, `loop_digit` is 8, `loop_count` is 0. We set `loop_digit` to 9 (or 10 if we handle it).
            // In my sequential logic, I had:
            // `if (loop_digit < 9) loop_count <= digit_count[loop_digit + 1];`
            // `else begin loop_digit <= 10; loop_count <= 4; end`
            // This is inside `else if (loop_count == 0)`.
            // So if `loop_digit` is 8, `loop_count` is 0. We go to 9.
            // If `loop_digit` is 9, `loop_count` is 0. We go to 10.
            // So `loop_digit` becomes 10.
            // We need to stay in state one more cycle? No, `loop_digit` becomes 10 in that cycle.
            // The combinational logic for `next_state` sees `loop_digit` as 9 (OLD).
            // So it stays in COMPUTE_PREFIX.
            // Next cycle, `loop_digit` is 10. Combinational logic sees 10. Transitions.
            // So we need one extra cycle.
            // To avoid this, we can transition if `(loop_digit == 9 && loop_count == 0)`.
            // If `loop_digit` is 9 and `loop_count` is 0, we are finishing. Transition.
            // But we need to update `loop_digit` to 10.
            // We can do `loop_digit <= 10` in the sequential block immediately.
            // But then we transition in the same cycle?
            // If we transition to FIND_PERMUTATION, the sequential block for FIND_PERMUTATION will execute.
            // It will reset `loop_digit`.
            // So the update to 10 is lost. That's fine.
            // So the check `if (loop_digit == 9 && loop_count == 0)` works if we handle the edge case of skipping 9.
            // If `loop_digit` is 8, `loop_count` is 0. We update `loop_digit` to 9. 
            // Next cycle: `loop_digit` is 9, `loop_count` is `digit_count[9]`.
            // If `digit_count[9]` is 0, `loop_count` is 0. 
            // Then `loop_digit` becomes 10. 
            // So we have a cycle where `loop_digit` is 9, `loop_count` is 0.
            // Check catches it. Transition.
            // So we are good.
            // 
            // What if `digit_count` is all 0? 
            // `loop_digit` init to 1, `loop_count` = `digit_count[1]` = 0.
            // `loop_digit` becomes 2, `loop_count` = `digit_count[2]` = 0.
            // ...
            // `loop_digit` becomes 9, `loop_count` = `digit_count[9]` = 0.
            // `loop_digit` becomes 10.
            // Next cycle transition.
            // Works.

            FIND_PERMUTATION: next_state = CONSTRUCT_RESULT;

            CONSTRUCT_RESULT: begin
                // We need to check if we finished outputting.
                // We use `out_digit_idx` and `result_length`.
                // But `result_length` is updated in FIND_PERMUTATION.
                // So in CONSTRUCT_RESULT, `result_length` is valid.
                // We check `if (out_digit_idx >= result_length) next_state = DONE;`.
                // But `out_digit_idx` updates non-blocking. 
                // So if we write the last digit, `out_digit_idx` becomes `result_length`.
                // Next cycle, transition.
                // We can't transition immediately because we need to register the last digit.
                // So we need one extra cycle? 
                // In CONSTRUCT_RESULT sequential block, we write to `result`. 
                // We increment `out_digit_idx`. 
                // If `out_digit_idx + 1 == result_length`, we write the last digit and increment.
                // Next cycle `out_digit_idx == result_length`. We transition.
                // So we need to stay until `out_digit_idx == result_length`.
                // This implies the last digit is written, then we wait one cycle to transition.
                // Can we do it in the same cycle?
                // If we detect `out_digit_idx == result_length - 1` in combinational logic, we can transition.
                // But we need to write the digit.
                // We can't write and transition to DONE in same cycle (unless we use separate logic).
                // Let's just stay one extra cycle. It's fine.
                // Check `if (out_digit_idx >= result_length) next_state = DONE;`.
                // But `out_digit_idx` is OLD. So we check if it *will be* >=.
                // We need to calculate `next_out_digit_idx`.
                // If `out_digit_idx + 1 >= result_length`, transition.
                // But `out_digit_idx` might jump by 1 (non-zero), 1 (perm), 1 (zero).
                // So `next_out_digit_idx = out_digit_idx + 1` (if we write) or `out_digit_idx` (if we skip/write nothing?).
                // We always write in this state until done.
                // So `next_out_digit_idx = out_digit_idx + 1`.
                // Transition if `out_digit_idx + 1 >= result_length`.
                // This works.
                // But wait, what if `result_length` is 0? (Should be handled by valid=0).
                // 
                // Let's just add a `done_writing` register to be safe or use the lookahead.
                // Let's use lookahead: `if (out_digit_idx + 1 >= result_length) next_state = DONE;`.
                // 
                // Wait, what if we are in phase 1, `loop_count` is 0, `loop_digit` increments.
                // We might not write anything in a cycle (if count was 0).
                // Example: `digit_count[5]` is 0. `loop_digit` becomes 5, `loop_count` is 0. 
                // We skip to 6. No write.
                // `out_digit_idx` does not increment.
                // So we can't use `out_digit_idx + 1`.
                // We must check if we are at the end of the stream.
                // The stream ends when:
                //   We are in Phase 1, `loop_digit` is 9, `loop_count` is 0.
                //   We are in Phase 2, `loop_count` is 0.
                //   We are in Phase 3, `loop_count` is 0.
                // 
                // Let's use a flag `is_writing`. If `is_writing` is true, we increment `out_digit_idx`.
                // If `is_writing` is false, we don't.
                // `is_writing` is true if we are in Phase 1 and `loop_count` > 0, etc.
                // 
                // Let's simplify: The problem says Result valid 120 cycles after start.
                // We can just wait fixed 120 cycles or use the state machine.
                // Let's stick to state machine. 
                // 
                // Let's use a counter `output_remaining`. Calculated in FIND_PERMUTATION.
                // Decrement every time we write.
                // Transition when `output_remaining == 0`.
                // This handles skipping digits.
                // But `output_remaining` must be updated in sequential logic.
                // So `next_state` check `if (output_remaining == 0)`.
                // But `output_remaining` is non-blocking.
                // So we need to check `if (output_remaining == 1)` (if we write one) or lookahead.
                // 
                // Let's try lookahead calculation in combinational block.
                // We need to know if we write this cycle.
                // We can determine if we write based on `loop_digit`, `loop_count`, `loop_phase`.
                // This replicates the sequential logic.
                // 
                // To keep it simple and within 120 cycles:
                // Stay in CONSTRUCT_RESULT until `output_remaining` (a register) reaches 0.
                // Decrement `output_remaining` in sequential block whenever we write.
                // Transition when `output_remaining == 0`.
                // To avoid the non-blocking issue, we can transition when `output_remaining == 1` IF we know we write this cycle.
                // But we know we write if we are in a "write phase".
                // Write phases: 
                //   P1: `loop_count` > 0.
                //   P2: `loop_count` > 0.
                //   P3: `loop_count` > 0.
                // So we write if `loop_count` > 0 (in any phase, handled by sequential logic).
                // 
                // Let's use `output_remaining` register.
                // Initialize in FIND_PERMUTATION.
                // Decrement in CONSTRUCT_RESULT if we write.
                // Transition if `output_remaining == 0`.
                // But `output_remaining` is non-blocking. So we check `output_remaining == 1` AND we are writing.
                // Or we check `output_remaining == 1` and know we will finish.
                // 
                // Let's just transition if `output_remaining == 0` and `loop_count == 0` and `loop_digit` indicates done.
                // Or simpler: 
                // Since we have `result_length`, we can check `if (out_digit_idx == result_length - 1)`. 
                // But `out_digit_idx` updates in the same cycle as the write.
                // So `out_digit_idx` is OLD. We need `out_digit_idx + 1 == result_length`.
                // And we must be writing this cycle.
                // Let's calculate `will_write`. 
                // `will_write` = (loop_digit <= 9 && loop_count > 0) || (loop_digit == 10 && loop_count > 0) || (loop_digit == 11 && loop_count > 0).
                // If `will_write` and `out_digit_idx + 1 == result_length`, transition.
                // This seems robust.
            end

            DONE: if (!start) next_state = IDLE; else next_state = DONE;
        endcase
    end

    // Helper logic for transitions (must be combinational)
    // We need to calculate `will_write` and `next_out_digit_idx` for CONSTRUCT_RESULT transition.
    // And `loop_done` for COMPUTE_PREFIX.
    
    wire will_write;
    wire [3:0] next_out_digit_idx;
    assign will_write = (loop_digit <= 9 && loop_count > 0) || 
                        (loop_digit == 10 && loop_count > 0) || 
                        (loop_digit == 11 && loop_count > 0);
    assign next_out_digit_idx = out_digit_idx + (will_write ? 1 : 0);

    // Re-implementation of specific state transitions with these helpers
    always @(*) begin
        case (current_state)
            COMPUTE_PREFIX: begin
                // Check if loop is done
                // If loop_digit > 9, we are done. But loop_digit is old.
                // If loop_digit is 9, loop_count is 0, we are done.
                // If loop_digit is 9, loop_count is >0, we are not done.
                // If loop_digit is 8, loop_count is 0, we are not done (we go to 9).
                
                // Let's use a signal `loop_finished`
                // `loop_finished` = (loop_digit == 9 && loop_count == 0).
                // But what if `digit_count[9]` is 0? Then `loop_digit` becomes 10.
                // In that case, `loop_digit` is 9, `loop_count` is 0.
                // So `loop_finished` works.
                // What if we have `loop_digit` = 9, `loop_count` = 1? We process it, `loop_count` becomes 0.
                // Next cycle `loop_digit` = 10. `loop_finished` was false.
                // Next cycle we transition.
                // So we need one extra cycle where `loop_digit` = 10.
                // But we can't see `loop_digit` = 10 in the comb block.
                // We can add `loop_digit == 10` to the check?
                // No, `loop_digit` is 9.
                // 
                // Let's change the logic: 
                // If `loop_digit` is 9 and `loop_count` is 0, we are done with the sequence.
                // We can transition immediately.
                // But we need to update `loop_digit` to 10 for the next state's logic?
                // No, next state is FIND_PERMUTATION. It resets `loop_digit`.
                // So we can transition.
                // 
                // Edge case: `loop_digit` = 8, `loop_count` = 0.
                // Sequential block sets `loop_digit` = 9, `loop_count` = `digit_count[9]`.
                // If `digit_count[9]` is 0, `loop_count` is 0.
                // We enter COMPUTE_PREFIX with `loop_digit` = 9, `loop_count` = 0.
                // We see `loop_digit` == 9 && `loop_count` == 0. Transition.
                // Correct.
                // 
                // What if `digit_count` is empty? `loop_digit` init 1, `loop_count` 0.
                // Goes to 2, count 0... to 9, count 0.
                // In the cycle where `loop_digit` is 9, `loop_count` is 0.
                // Transition.
                // Correct.
                
                if (loop_digit == 9 && loop_count == 0) next_state = FIND_PERMUTATION;
                else next_state = COMPUTE_PREFIX;
                
                // But we must ensure we don't transition if we are still processing.
                // If `loop_digit` is 9 and `loop_count` > 0, we stay.
                // If `loop_digit` < 9, we stay.
                // So the condition is correct.
                // EXCEPT: We need to handle the case where `loop_digit` becomes 10 in the cycle where we transition.
                // But we transition *based on* `loop_digit` = 9.
                // So the transition happens. The sequential block also executes `FIND_PERMUTATION` logic?
                // No, `next_state` is used to determine which `case` branch runs in the sequential block.
                // So if we transition, the `COMPUTE_PREFIX` block won't run. The `FIND_PERMUTATION` block runs.
                // So we don't update `loop_digit` to 10. We reset it in `FIND_PERMUTATION`. Good.
                // 
                // What if `loop_digit` is 9, `loop_count` is 0, but we just finished the last cycle of loop?
                // This is the transition point.
                // 
                // Wait, what if `digit_count[9]` is non-zero? 
                // Cycle N: `loop_digit` = 9, `loop_count` = C > 0.
                // We process one. `loop_count` becomes C-1.
                // Cycle N+1: `loop_digit` = 9, `loop_count` = C-1.
                // ...
                // Cycle M: `loop_digit` = 9, `loop_count` = 1.
                // We process one. `loop_count` becomes 0.
                // Cycle M+1: `loop_digit` = 9, `loop_count` = 0.
                // Transition.
                // Correct.
            end
            
            CONSTRUCT_RESULT: begin
                if (next_out_digit_idx >= result_length) begin
                    next_state = DONE;
                end else begin
                    next_state = CONSTRUCT_RESULT;
                end
            end
        endcase
    end

endmodule
