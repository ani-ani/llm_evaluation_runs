module goldbach_checker (
    input clk,
    input rst_n,
    input [7:0] char_in,
    input char_valid,
    input char_last,
    output reg result,
    output reg done
);

    // Parameters and Limits
    localparam MAX_NUM = 50000;
    localparam MAX_TOKENS = 3;
    localparam MAX_DIGITS = 5; // Max digits for 50000 is 5
    localparam MAX_PRIME_SQRT = 224; // ceil(sqrt(50000))

    // State Encoding
    localparam STATE_IDLE = 4'b0000;
    localparam STATE_PARSING_TOKEN = 4'b0001;
    localparam STATE_VERIFY_PRIME_1 = 4'b0010;
    localparam STATE_VERIFY_PRIME_2 = 4'b0011;
    localparam STATE_VERIFY_SUM = 4'b0100;
    localparam STATE_VALID = 4'b0101;
    localparam STATE_INVALID = 4'b0110;
    localparam STATE_DONE_WAIT = 4'b0111;

    // Internal Registers
    reg [3:0] current_state, next_state;
    reg [31:0] token_values [0:2]; // Stores parsed integers
    reg [2:0] token_count; // Number of tokens parsed
    reg [3:0] digit_count; // Digits in current token
    reg [31:0] current_val;
    reg leading_zero_error;
    reg overflow_error;
    reg format_error;
    reg chars_processed;

    // Prime Verification Registers
    reg [31:0] divisor;
    reg [31:0] sqrt_limit;
    reg prime_check_fail;
    reg prime_check_done;

    // Helper: ASCII digit check
    wire is_digit;
    assign is_digit = (char_in >= 8'h30) && (char_in <= 8'h39);

    // Helper: Whitespace check (space, tab, newline)
    wire is_whitespace;
    assign is_whitespace = (char_in == 8'h20) || (char_in == 8'h09) || (char_in == 8'h0A) || (char_in == 8'h0D);

    // Update State Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Main State Machine Logic
    always @(*) begin
        next_state = current_state; // Default stay in current state

        case (current_state)
            STATE_IDLE: begin
                if (char_valid && !is_whitespace) begin
                    if (is_digit) begin
                        next_state = STATE_PARSING_TOKEN;
                    end else begin
                        next_state = STATE_INVALID;
                    end
                end else if (char_valid && char_last) begin
                    next_state = STATE_INVALID;
                end
            end

            STATE_PARSING_TOKEN: begin
                if (char_valid) begin
                    if (is_whitespace || char_last) begin
                        // Token finished
                        if (token_count < MAX_TOKENS) begin
                            if (token_count == 0) begin
                                next_state = STATE_VERIFY_PRIME_1; // Actually checking Token 1 constraints first
                            end else if (token_count == 1) begin
                                next_state = STATE_VERIFY_PRIME_1;
                            end else if (token_count == 2) begin
                                next_state = STATE_VERIFY_PRIME_2;
                            end else begin
                                next_state = STATE_INVALID; // More than 3 tokens found
                            end
                        end else begin
                            next_state = STATE_INVALID;
                        end
                    end else if (!is_digit) begin
                        next_state = STATE_INVALID;
                    end else begin
                        next_state = STATE_PARSING_TOKEN;
                    end
                end else if (char_last) begin
                    // End of stream while parsing
                    if (token_count < MAX_TOKENS) begin
                         if (token_count == 0) next_state = STATE_VERIFY_PRIME_1;
                         else if (token_count == 1) next_state = STATE_VERIFY_PRIME_1;
                         else if (token_count == 2) next_state = STATE_VERIFY_PRIME_2;
                         else next_state = STATE_INVALID;
                    end else begin
                         next_state = STATE_INVALID;
                    end
                end
            end

            STATE_VERIFY_PRIME_1: begin
                // Checks: Token 1 constraints (Even, >3, <=50000, No format errors)
                // If Token 1 valid, proceed to check Token 2 (if it exists) or wait for more
                // Since we are sequential, if we just parsed Token 1, we wait here.
                // Actually, logic: We check T1 constraints. If T1 valid, we need T2.
                // But we are processing stream. If we are here, we just finished a token.
                // Logic adjustment: State should transition based on what we just finished.
                // If we finished T1, next is idle/wait for T2 start or end if done (invalid).

                // Refined Flow: 
                // 1. Just finished T1. Check T1 constraints.
                // 2. If valid, we need T2. Go to IDLE to find T2.
                // 3. Just finished T2. (Handled in PARSING_TOKEN -> VERIFY_PRIME_1 for T2)
                // Actually, let's trace: 
                // T1 parsed -> VERIFY_PRIME_1. Check T1 constraints. 
                // If valid -> Wait for T2? Or go to IDLE? 
                // Let's make VERIFY_PRIME_1 general or split states.
                // Let's use a "CHECK_AND_WAIT" pattern.

                // Let's redefine:
                // Just finished a token. 
                // If Token 1: Check T1 constraints. If fail -> INVALID. If pass -> Next State: IDLE (waiting for T2 start) but mark T1 done.
                // Wait, IDLE resets counters. Need to distinguish "Waiting for T2".

                // New Idea: 
                // IDLE starts T1 parsing.
                // PARSING_TOKEN accumulates. 
                // If token ends: 
                //   If count == 1 (Just finished T1): -> STATE_CHECK_T1
                //   If count == 2 (Just finished T2): -> STATE_CHECK_T2
                //   If count == 3 (Just finished T3): -> STATE_CHECK_T3 (Sum)

                // Re-write state transitions for clarity:
                if (token_count == 1) begin // Just finished Token 1
                     // Check T1 constraints: !format_error, !leading_zero_error, !overflow_error
                     // Check T1 Value: > 3, <= 50000, even
                     if (format_error || leading_zero_error || overflow_error || 
                         current_val <= 3 || current_val > 50000 || (current_val[0] != 1'b0)) begin
                         next_state = STATE_INVALID;
                     end else begin
                         // T1 is valid, need T2
                         // If char_last was high, invalid (need 3 tokens)
                         // But char_last handling is tricky here. 
                         // We stay in a state waiting for next char or char_last.
                         // Let's stay here, but implicitly waiting for next IDLE-like behavior.
                         // Actually, let's just go to IDLE but we need to know we parsed T1.
                         // Let's add a flag or modify IDLE behavior.

                         // Simpler: Add a state CHECK_T1. 
                         // Then transition to IDLE (which now means "Wait for T2").
                         next_state = STATE_IDLE; 
                     end
                end else if (token_count == 2) begin // Just finished Token 2
                     // Check T2 constraints
                     if (format_error || leading_zero_error || overflow_error) begin
                         next_state = STATE_INVALID;
                     end else begin
                         // Check Prime T2
                         next_state = STATE_VERIFY_PRIME_1; // Use this state for T2 prime check
                     end
                end else if (token_count == 3) begin // Just finished Token 3
                     // Check T3 constraints
                     if (format_error || leading_zero_error || overflow_error) begin
                         next_state = STATE_INVALID;
                     end else begin
                         // Check Prime T3
                         next_state = STATE_VERIFY_PRIME_2; // Use this state for T3 prime check
                     end
                end else begin
                     next_state = STATE_INVALID;
                end
            end

            // Let's refine the flow to match the requirement's state names better
            // Requirement states: PARSING_TOKEN -> VERIFY_PRIME_1 -> VERIFY_PRIME_2 -> VERIFY_SUM
            // This implies PARSING_TOKEN finishes, then we jump to verification.

            // Revised Logic:
            // 1. IDLE -> PARSING_TOKEN (when first char of T1)
            // 2. PARSING_TOKEN -> VERIFY_T1 (when T1 ends). Note: Requirement said VERIFY_PRIME_1, but T1 isn't prime.
            // Requirement says: "STATE_VERIFY_PRIME_1: Check if token 2 is prime".
            // This implies we need to parse T1, check it, parse T2, check it.

            // Let's stick to the Requirement's flow but adapt:
            // PARSING_TOKEN loops until token end.
            // On Token End: 
            //   If Token 1: Check Constraints. If OK, go to IDLE (wait for Token 2) ? No, requirement has specific states.
            //   Let's use states to indicate "What we just checked/are checking".

            // Let's try this map:
            // IDLE: Start of stream or after whitespace waiting for next token.
            // PARSING_TOKEN: Reading digits.

            // When PARSING_TOKEN finishes (char is whitespace or last):
            //   Increment token_count.
            //   If count == 1: Check T1. If fail -> INVALID. If Pass -> Stay in PARSING_TOKEN? No.
            //   Let's have PARSING_TOKEN only handles accumulation. 
            //   Transition to a "CHECK" state based on count.

            // Let's stick to a robust implementation rather than forcing the exact state name logic if it conflicts.
            // But I will try to use the names.

            // Let's define:
            // IDLE -> PARSING_TOKEN (First char)
            // PARSING_TOKEN -> 
            //    If T1 done: Check T1. If OK -> IDLE (Wait for T2). 
            //    If T2 done: -> VERIFY_PRIME_1 (Check T2)
            //    If T3 done: -> VERIFY_PRIME_2 (Check T3)
            //    
            // Then:
            // VERIFY_PRIME_1 (T2) -> VERIFY_PRIME_2 (T3 check) ? No.
            // Verify T2 -> Verify T3 -> Verify Sum.
            // Requirement says VERIFY_PRIME_1 (check token 2), VERIFY_PRIME_2 (check token 3), VERIFY_SUM.

            // Implementation Strategy:
            // We need to accumulate T1, T2, T3. We can't verify T2 until we have T3? No, we can verify T2 once parsed.
            // But we need T1+T2 = T3? Wait, requirement says "Sum of second and third equals first".
            // T1 = T2 + T3.
            // So we need T1 and T2 and T3 to check sum. 
            // But we can verify primes of T2 and T3 as we get them (or after).

            // Let's adjust: 
            // IDLE -> PARSING_TOKEN.
            // PARSING_TOKEN ends token -> 
            //   If T1: Check Constraints. -> IDLE (Wait for T2 start).
            //   If T2: Check Constraints. -> VERIFY_PRIME_1 (Check T2 Prime). -> IDLE (Wait for T3).
            //   If T3: Check Constraints. -> VERIFY_PRIME_2 (Check T3 Prime). -> VERIFY_SUM (Check T1=T2+T3).

            // Wait, if we go IDLE after every token, we lose context of "Which token are we waiting for?"
            // We need a "Stage" register or use states.
            // State variable `current_state` tracks stage.

            // Let's use `current_state` to track Stage + Sub-action.
            // STAGE_1_IDLE: Waiting for T1 digit.
            // STAGE_1_PARSE: Parsing T1.
            // STAGE_1_CHECK: Check T1 constraints.
            // STAGE_2_IDLE: Waiting for T2 digit.
            // STAGE_2_PARSE: Parsing T2.
            // STAGE_2_CHECK: Check T2 constraints + Prime.
            // STAGE_3_IDLE: Waiting for T3 digit.
            // STAGE_3_PARSE: Parsing T3.
            // STAGE_3_CHECK: Check T3 constraints + Prime.
            // STAGE_SUM: Verify Sum.

            // To fit requirement names:
            // IDLE -> STAGE_1_IDLE (Start)
            // PARSING_TOKEN -> STAGE_1_PARSE, STAGE_2_PARSE, STAGE_3_PARSE
            // VERIFY_PRIME_1 -> STAGE_2_CHECK
            // VERIFY_PRIME_2 -> STAGE_3_CHECK
            // VERIFY_SUM -> STAGE_SUM

            // Let's refine logic with implicit stage tracking via state.

            // IDLE: 
            //   If char_valid & !whitespace -> 
            //     If digit: start parsing. 
            //     If T1 stage: goto PARSING_TOKEN (T1). 
            //     If T2 stage: goto PARSING_TOKEN (T2). 
            //     If T3 stage: goto PARSING_TOKEN (T3).
            //   How to know stage? 
            //   If token_count == 0 -> T1 stage.
            //   If token_count == 1 -> T2 stage.
            //   If token_count == 2 -> T3 stage.

            // PARSING_TOKEN:
            //   Accumulates digits. 
            //   On whitespace/last:
            //     If token_count == 1 (T1 done): goto CHECK_T1 (or VERIFY_PRIME_1 if we use it as T1 check).
            //     Requirement: "STATE_VERIFY_PRIME_1: Check if token 2 is prime". 
            //     This implies VERIFY_PRIME_1 happens AFTER T2 is parsed.
            //     So if we finish T1, we just reset parsing for T2.
            //     Let's add a temporary internal state `NEXT_STAGE`.

            // Let's try to match the prompt's state machine names exactly:
            // Prompt: IDLE -> PARSING_TOKEN -> VERIFY_PRIME_1 -> VERIFY_PRIME_2 -> VERIFY_SUM -> VALID/INVALID.
            // This suggests a linear flow. 
            // How? 
            // IDLE: Start.
            // PARSING_TOKEN: Reads T1, then whitespace, then T2, then whitespace, then T3.
            // But PARSING_TOKEN needs to know when to transition out.
            // And VERIFY_PRIME_1 needs to be entered after T2 is done.

            // Let's use `token_count` to branch inside PARSING_TOKEN or have sub-states.
            // Actually, let's stick to the prompt's intent: Sequential check.

            // Let's try this interpretation:
            // State = IDLE. Wait for first digit (T1). -> PARSING_TOKEN.
            // In PARSING_TOKEN, we read T1 digits. 
            // When T1 ends (space/last): 
            //   Check T1 constraints. If fail -> INVALID.
            //   If T1 OK: 
            //     We are implicitly ready for T2. 
            //     But the state machine requires us to return to PARSING_TOKEN or stay?
            //     Prompt says PARSING_TOKEN is a state.

            // Okay, let's use the state machine to control the "Stage".
            // We will map the prompt's states to what they do.

            // State: IDLE
            //   Wait for start of T1. -> PARSING_TOKEN (token_count=0).
            // State: PARSING_TOKEN
            //   Used for accumulating digits. 
            //   When token ends:
            //     If token_count == 0 (T1 done): Check T1 constraints. 
            //       If valid: Set stage to T2. Wait for next non-ws -> PARSING_TOKEN (loop? No, leave state).
            //       Actually, to stay in PARSING_TOKEN for next token, we need to handle whitespace inside it.
            //       But PARSING_TOKEN is specific to one token usually.

            // Let's add implicit "WAIT_FOR_NEXT_TOKEN" inside IDLE or a sub-state.
            // Let's stick to this: 

            // IDLE -> PARSING_TOKEN (Start T1)
            // PARSING_TOKEN -> 
            //    If T1 done: 
            //      If T1 valid: Go to IDLE (But IDLE starts T1. Need to differentiate "IDLE waiting for T2").

            // Let's use the `token_count` register to drive logic in IDLE.

            // IDLE: 
            //   If token_count == 0: Wait for T1 start. If found -> PARSING_TOKEN.
            //   If token_count == 1: T1 done. Check T1. If invalid -> INVALID. If valid -> 
            //        Wait for T2 start (whitespace skip). If T2 start -> PARSING_TOKEN.
            //   If token_count == 2: T2 done. Check T2 Constraints+Prime (VERIFY_PRIME_1). 
            //        If invalid -> INVALID. If valid -> Wait for T3 start -> PARSING_TOKEN.
            //   If token_count == 3: T3 done. Check T3 Constraints+Prime (VERIFY_PRIME_2). 
            //        If invalid -> INVALID. If valid -> Verify Sum (VERIFY_SUM).

            // This fits the prompt's state names if we consider:
            // IDLE handles the "Wait for start of next token" phase.
            // PARSING_TOKEN handles reading digits.
            // VERIFY_PRIME_1 handles T2 check.
            // VERIFY_PRIME_2 handles T3 check.
            // VERIFY_SUM handles sum check.

            // Let's refine:

            // IDLE: 
            //   if (token_count == 0) { // Waiting for T1
            //     if (char_valid && !ws) -> if (digit) PARSING_TOKEN else INVALID
            //   } else if (token_count == 1) { // T1 done, waiting for T2
            //     if (char_valid && !ws) -> if (digit) PARSING_TOKEN else INVALID
            //     // But wait, we must verify T1 first!
            //   }

            // Correct Sequence:
            // T1 -> Verify T1 Constraints -> (Pass) -> T2 -> Verify T2 Constraints + Prime -> (Pass) -> T3 -> Verify T3 Constraints + Prime -> (Pass) -> Verify Sum.

            // So states:
            // IDLE (Wait for start of next token based on count)
            // PARSING_TOKEN (Read digits)
            // VERIFY_T1 (Check T1 constraints) -> If pass, go to IDLE (now count=1)
            // VERIFY_PRIME_1 (Check T2) -> If pass, go to IDLE (now count=2)
            // VERIFY_PRIME_2 (Check T3) -> If pass, go to VERIFY_SUM
            // VERIFY_SUM (Check sum) -> If pass, go to VALID

            // Requirement says: "STATE_VERIFY_PRIME_1: Check if token 2 is prime"
            // It does NOT mention VERIFY_T1 state explicitly, but it says "First integer is...".
            // I will add a check state for T1. If I strictly follow prompt, it might be missing.
            // Prompt: "Must reject: ... fewer than 3 tokens".
            // I will assume we need to check T1 constraints. I will name the state `VERIFY_PRIME_1` for T2, `VERIFY_PRIME_2` for T3.
            // I need a state for T1 check. I'll call it `VERIFY_PRIME_1`? No, prompt says `VERIFY_PRIME_1` checks token 2.
            // I will treat `VERIFY_PRIME_1` as the state following T1 parsing.
            // Wait, prompt says "STATE_VERIFY_PRIME_1: Check if token 2 is prime".
            // This implies `VERIFY_PRIME_1` happens when we have T2.
            // So where is T1 check?
            // Prompt: "IDLE -> PARSING_TOKEN -> VERIFY_PRIME_1 ...".
            // This implies T1 check happens in transition or inside PARSING_TOKEN.

            // Let's put T1 check in a state I'll call `CHECK_T1` (internally), but if I must use prompt names, I'll skip it or merge.
            // Actually, looking at the prompt again: "Parse three integers sequentially". "Validate format".
            // "IDLE -> PARSING_TOKEN -> VERIFY_PRIME_1 -> VERIFY_PRIME_2 -> VERIFY_SUM".
            // This seems to imply: 
            // T1 is parsed. 
            // Then we verify Prime 1 (Wait, T1 isn't prime).
            // This is ambiguous.

            // CORRECT INTERPRETATION of Prompt:
            // 1. IDLE (wait for stream)
            // 2. PARSING_TOKEN (T1)
            // 3. VERIFY_PRIME_1 (Check T1 constraints? No, prompt says "Check if token 2 is prime").
            //    OK, maybe the prompt has a typo or assumes I know T1 isn't prime.
            //    BUT, the requirement says "First integer is a positive even number...".
            //    I MUST check this.

            // Let's use the state names for what they logically do:
            // IDLE -> PARSING_TOKEN (T1)
            // -> VERIFY_PRIME_1 (Check T1 constraints? No, check T1 constraints is different).
            // -> PARSING_TOKEN (T2) 
            // -> VERIFY_PRIME_1 (Check T2 Prime? Prompt says yes)
            // -> PARSING_TOKEN (T3)
            // -> VERIFY_PRIME_2 (Check T3 Prime? Prompt says yes)
            // -> VERIFY_SUM (Check T1=T2+T3)

            // This flow requires PARSING_TOKEN to be re-entered. 
            // Prompt says "State machine must track..." and lists those states.
            // It might mean these are the *distinct* logic blocks.

            // Let's try this robust logic:

            // IDLE:
            //   If token_count == 0 && char_valid && !ws -> PARSING_TOKEN
            //   If token_count == 1 && char_valid && !ws -> PARSING_TOKEN (After verifying T1)
            //   If token_count == 2 && char_valid && !ws -> PARSING_TOKEN (After verifying T2)

            // PARSING_TOKEN:
            //   Accumulate. 
            //   On End: Increment count.
            //     If count becomes 1: -> CHECK_T1
            //     If count becomes 2: -> CHECK_T2
            //     If count becomes 3: -> CHECK_T3

            // CHECK_T1: Verify T1 constraints. If Pass -> IDLE. Fail -> INVALID.
            // CHECK_T2: Verify T2 constraints + Prime (Call this VERIFY_PRIME_1). If Pass -> IDLE. Fail -> INVALID.
            // CHECK_T3: Verify T3 constraints + Prime (Call this VERIFY_PRIME_2). If Pass -> VERIFY_SUM. Fail -> INVALID.
            // VERIFY_SUM: Check T1 = T2 + T3. -> VALID / INVALID.

            // To match prompt names:
            // I will map CHECK_T1 logic to VERIFY_PRIME_1? No, prompt says VERIFY_PRIME_1 is for token 2.
            // I will create a state named `VERIFY_PRIME_1` and use it for T2 check.
            // I will create `VERIFY_PRIME_2` for T3 check.
            // I will create `VERIFY_SUM` for sum.
            // I will need `CHECK_T1` or similar. 
            // Since prompt didn't name it, I'll just create it or merge with IDLE.

            // Let's use the prompt's states and add necessary ones.
            // States: IDLE, PARSING_TOKEN, VERIFY_PRIME_1 (T2 check), VERIFY_PRIME_2 (T3 check), VERIFY_SUM, VALID, INVALID.
            // I will insert a `CHECK_T1` state implicitly or handle it in `IDLE`.

            // Refined Logic:
            // IDLE state handles "Wait for next token start" AND "Check previous token".

            // If in IDLE:
            //   If token_count == 0: Just started or waiting for T1. 
            //     If char_valid && !ws: -> PARSING_TOKEN (T1)
            //   If token_count == 1: T1 just finished (parsed in PARSING_TOKEN).
            //     Check T1 constraints. If fail -> INVALID.
            //     If pass: 
            //       If char_valid && !ws: -> PARSING_TOKEN (T2)
            //   If token_count == 2: T2 just finished.
            //     Go to VERIFY_PRIME_1 (T2 check).
            //   If token_count == 3: T3 just finished.
            //     Go to VERIFY_PRIME_2 (T3 check).

            // Wait, if IDLE checks T1, then `current_val` holds T1. 
            // PARSING_TOKEN will overwrite `current_val` for T2.
            // We need to store T1, T2, T3 separately. 
            // `token_values` array handles this.

            // Let's write the transition logic properly.

            // RE-RE-RE-FINED LOGIC:
            // State = IDLE.
            // Sub-state implied by `token_count`.

            if (current_state == STATE_IDLE) begin
                 // If we are here, we are looking for the start of the next token or have finished a token check.

                 if (token_count == 0) begin // Waiting for T1
                    if (char_valid && !is_whitespace) begin
                        if (is_digit) next_state = STATE_PARSING_TOKEN;
                        else next_state = STATE_INVALID;
                    end
                 end else if (token_count == 1) begin // T1 parsed, need to verify before T2
                    // Check T1 constraints
                    if (token_values[0] <= 3 || token_values[0] > 50000 || token_values[0][0] != 0) begin // Even check: [0] must be 0 for even? No, even means bit 0 is 0. 
                        // Wait, 8'h00 is '0'. Even numbers have LSB 0. 
                        // Logic: (val & 1) == 0.
                        if (format_error || leading_zero_error || overflow_error || (token_values[0] % 2 != 0) || token_values[0] <= 3 || token_values[0] > 50000) begin
                            next_state = STATE_INVALID;
                        end else begin
                            // T1 OK. Now wait for T2 start.
                            if (char_valid && !is_whitespace) begin
                                if (is_digit) next_state = STATE_PARSING_TOKEN;
                                else next_state = STATE_INVALID;
                            end
                        end
                    end
                 end else if (token_count == 2) begin // T2 parsed
                     // Go verify T2 (Prime)
                     next_state = STATE_VERIFY_PRIME_1;
                 end else if (token_count == 3) begin // T3 parsed
                     // Go verify T3 (Prime)
                     next_state = STATE_VERIFY_PRIME_2;
                 end
            end else if (current_state == STATE_PARSING_TOKEN) begin
                 // Logic inside always block for accumulation.
                 // Transitions handled on token end or char_last.
                 // If char_valid and (whitespace or last): End of token.
                 //   Increment token_count.
                 //   If token_count becomes 1: -> IDLE (will check T1)
                 //   If token_count becomes 2: -> IDLE (will go to VERIFY_PRIME_1)
                 //   If token_count becomes 3: -> IDLE (will go to VERIFY_PRIME_2)
                 //   If token_count > 3: -> INVALID

                 if (char_valid) begin
                     if (is_whitespace || char_last) begin
                         // Finished token
                         if (token_count < 3) begin
                             next_state = STATE_IDLE;
                         end else begin
                             next_state = STATE_INVALID;
                         end
                     end else if (!is_digit) begin
                         next_state = STATE_INVALID;
                     end else begin
                         next_state = STATE_PARSING_TOKEN;
                     end
                 end else if (char_last) begin // End of stream while parsing digit? 
                     // Treated as end of token
                     if (token_count < 3) begin
                         next_state = STATE_IDLE;
                     end else next_state = STATE_INVALID;
                 end
            end else if (current_state == STATE_VERIFY_PRIME_1) begin
                 // Check T2 (token_values[1])
                 // Use internal prime checking logic (iterative).
                 // If prime: next_state = IDLE (to wait for T3 start)
                 // If not prime: INVALID
                 // If prime_check not done: stay here.
                 if (prime_check_done) begin
                     if (prime_check_fail) next_state = STATE_INVALID;
                     else begin
                         // T2 Prime OK. Wait for T3.
                         if (char_valid && !is_whitespace) begin
                             if (is_digit) next_state = STATE_PARSING_TOKEN;
                             else next_state = STATE_INVALID;
                         end else if (char_last) next_state = STATE_INVALID; // Need 3 tokens
                         else next_state = STATE_IDLE; // Wait for stream to advance to T3
                     end
                 end else begin
                     next_state = STATE_VERIFY_PRIME_1;
                 end
            end else if (current_state == STATE_VERIFY_PRIME_2) begin
                 // Check T3 (token_values[2])
                 if (prime_check_done) begin
                     if (prime_check_fail) next_state = STATE_INVALID;
                     else next_state = STATE_VERIFY_SUM;
                 end else begin
                     next_state = STATE_VERIFY_PRIME_2;
                 end
            end else if (current_state == STATE_VERIFY_SUM) begin
                 if (token_values[0] == (token_values[1] + token_values[2])) begin
                     next_state = STATE_VALID;
                 end else begin
                     next_state = STATE_INVALID;
                 end
            end else if (current_state == STATE_VALID || current_state == STATE_INVALID) begin
                 // Stay there until reset or until handled by done logic
                 // Requirement: "Latency: Result available up to 256 clock cycles..."
                 // We need to stay in processing states? No, we finish.
                 // But we need to assert 'done' eventually.
                 // If we are VALID/INVALID, we assert done.
                 // If done is asserted, we might need to stay or go to IDLE?
                 // Usually, go to a terminal state.
                 if (next_state == STATE_VALID || next_state == STATE_INVALID) begin
                     // Already in terminal state logic above.
                 end else begin
                    // Transitions from terminal states? 
                    // Maybe stay in terminal state until reset.
                    // Or go to DONE_WAIT.
                    // Let's go to DONE_WAIT to keep 'done' high.
                    next_state = STATE_DONE_WAIT;
                 end
            end else if (current_state == STATE_DONE_WAIT) begin
                 next_state = STATE_DONE_WAIT;
            end else begin
                 next_state = STATE_INVALID;
            end
        endcase

        // Override for char_last in IDLE when expecting more
        if (current_state == STATE_IDLE && char_valid && char_last) begin
            if (token_count == 0) next_state = STATE_INVALID; // No token found
            else if (token_count == 1) next_state = STATE_INVALID; // Only T1 found
            else if (token_count == 2) begin 
                // We are in IDLE with count 2. This means we finished T2 check (Prime) and are waiting for T3 start.
                // But stream ends. Invalid.
                next_state = STATE_INVALID;
            end
        end
    end

    // Data Path Logic (Accumulation, Verification)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            token_count <= 0;
            current_val <= 0;
            token_values[0] <= 0;
            token_values[1] <= 0;
            token_values[2] <= 0;
            digit_count <= 0;
            leading_zero_error <= 0;
            overflow_error <= 0;
            format_error <= 0;
            divisor <= 2;
            sqrt_limit <= 0;
            prime_check_done <= 0;
            prime_check_fail <= 0;
            chars_processed <= 0;
            result <= 0;
            done <= 0;
        end else begin
            // Default updates for Prime Check Logic
            if (current_state == STATE_VERIFY_PRIME_1 || current_state == STATE_VERIFY_PRIME_2) begin
                // Iterative Division Logic
                // n = token_values[1] (if state 1) or token_values[2] (if state 2)
                if (!prime_check_done) begin
                    // Check if we need to start or continue
                    if (divisor == 2 && sqrt_limit == 0) begin
                        // Start check
                        if (current_state == STATE_VERIFY_PRIME_1) begin
                            if (token_values[1] < 2) begin prime_check_fail <= 1; prime_check_done <= 1; end
                            else if (token_values[1] == 2) begin prime_check_fail <= 0; prime_check_done <= 1; end
                            else if (token_values[1] % 2 == 0) begin prime_check_fail <= 1; prime_check_done <= 1; end
                            else begin
                                // Calculate sqrt limit (ceil(sqrt(n))). Use simple approximation or precompute.
                                // Since max is 50000, we can iterate up to 224.
                                // Let's just iterate until divisor*divisor > n.
                                // We need a register for 'n' being checked.
                                // Actually, let's keep it simple: 
                                // Precompute sqrt or check range.
                                // To save logic, iterate up to 224. If n is prime, it must not be divisible by odd numbers up to 224.
                                // Actually, we need to check up to sqrt(n). 
                                // We can check `divisor * divisor <= n`.
                            end
                        end else begin
                             // STATE_VERIFY_PRIME_2
                             if (token_values[2] < 2) begin prime_check_fail <= 1; prime_check_done <= 1; end
                             else if (token_values[2] == 2) begin prime_check_fail <= 0; prime_check_done <= 1; end
                             else if (token_values[2] % 2 == 0) begin prime_check_fail <= 1; prime_check_done <= 1; end
                             else begin
                                divisor <= 3;
                                prime_check_done <= 0;
                                prime_check_fail <= 0;
                             end
                        end
                    end else begin
                        // Continue iteration
                        // Check divisor * divisor > n
                        // Let's optimize: 
                        // Since we are sequential, we can use a counter.
                        // But we need to know 'n'.
                        // Let's use `divisor` and check against `token_values[...]`.
                        // Check: (divisor * divisor) > n.
                        // Multiplication is heavy. Let's assume 50000 max.
                        // We can precompute sqrt limit for max 50000, which is 224.
                        // Or, we can simply iterate up to 224.
                        // If we iterate up to 224, we cover all cases up to 50000.
                        // Because sqrt(50000) ~ 223.6.
                        // So if we check divisors 2, 3, ... 223.
                        // This is fast enough (max 111 cycles for odd numbers).

                        // Let's refine iteration logic:
                        // Start with divisor = 3 (skipped even).
                        // If token % divisor == 0 -> Composite.
                        // divisor += 2.
                        // Stop when divisor > 224.
                        // Or stop when divisor > token (for small tokens).

                        // We need to store which token we are checking.
                        // Let's use a flag or just infer from state.
                        // Actually, let's merge the logic:

                        if (current_state == STATE_VERIFY_PRIME_1) begin
                            // Check T2 = token_values[1]
                            if (divisor > 224 || divisor * divisor > token_values[1]) begin
                                prime_check_fail <= 0; prime_check_done <= 1;
                            end else if (token_values[1] % divisor == 0) begin
                                prime_check_fail <= 1; prime_check_done <= 1;
                            end else begin
                                divisor <= divisor + 2;
                            end
                        end else if (current_state == STATE_VERIFY_PRIME_2) begin
                            // Check T3 = token_values[2]
                            if (divisor > 224 || divisor * divisor > token_values[2]) begin
                                prime_check_fail <= 0; prime_check_done <= 1;
                            end else if (token_values[2] % divisor == 0) begin
                                prime_check_fail <= 1; prime_check_done <= 1;
                            end else begin
                                divisor <= divisor + 2;
                            end
                        end
                    end
                end
            end

            // Reset prime check registers when leaving VERIFY states
            if (current_state != STATE_VERIFY_PRIME_1 && current_state != STATE_VERIFY_PRIME_2) begin
                divisor <= 3; // Reset for next run (starts at 3 after handling even check)
                sqrt_limit <= 0;
                prime_check_done <= 0;
                prime_check_fail <= 0;
            end

            // Accumulation Logic in STATE_PARSING_TOKEN
            if (current_state == STATE_PARSING_TOKEN) begin
                if (char_valid && is_digit) begin
                    // Accumulate
                    // Check overflow > 50000 during accumulation or after?
                    // Requirement: <= 50000. 
                    // We can check overflow at the end, but checking during is better.
                    // Check: current_val > 50000 or current_val*10 + digit > 50000.

                    // Digit value
                    reg [7:0] digit;
                    digit = char_in - 8'h30;

                    // Update
                    if (current_val > 50000) overflow_error <= 1;
                    else begin
                        current_val <= current_val * 10 + digit;
                        if ((current_val * 10 + digit) > 50000) overflow_error <= 1;
                    end

                    // Leading Zero
                    if (digit_count == 0 && digit == 0) leading_zero_error <= 1;
                    else if (digit_count == 0 && digit != 0) leading_zero_error <= 0; // Reset if first digit is non-zero (in case of previous clear)
                    // Note: leading_zero_error stays high if set, unless reset by new token start.

                    digit_count <= digit_count + 1;
                    chars_processed <= 1;
                end
            end else begin
                // Not parsing. Reset accumulators if we are entering a new token phase or resetting.
                // But careful: We need to keep current_val until stored.
                // When do we store? 
                // When leaving STATE_PARSING_TOKEN (to IDLE).
                if (current_state == STATE_IDLE && next_state == STATE_PARSING_TOKEN) begin
                    // Starting new token. Clear accumulators.
                    current_val <= 0;
                    digit_count <= 0;
                    leading_zero_error <= 0; // Reset for new token
                    overflow_error <= 0;
                    format_error <= 0;
                end

                // Store Token Logic (Transition STATE_PARSING_TOKEN -> IDLE)
                if (current_state == STATE_PARSING_TOKEN && (next_state == STATE_IDLE || next_state == STATE_INVALID)) begin
                    // Token finished. Store value.
                    if (token_count == 0) token_values[0] <= current_val;
                    else if (token_count == 1) token_values[1] <= current_val;
                    else if (token_count == 2) token_values[2] <= current_val;

                    // Increment count (unless invalid due to overflow/format)
                    // But we handle invalid in next_state logic.
                    if (next_state != STATE_INVALID) begin
                        token_count <= token_count + 1;
                    end
                end

                // Handle end of stream in STATE_PARSING_TOKEN if char_last is high
                if (current_state == STATE_PARSING_TOKEN && char_valid && char_last && !is_whitespace && is_digit) begin
                    // Implicit end of token.
                    // Logic handled in next_state = IDLE (or INVALID).
                    // But we need to store value here because transition logic happens next cycle.
                    // Wait, standard sync logic: State changes next cycle.
                    // Data stored on this cycle.
                    // If next_state is IDLE, we need to store token.
                    // But `next_state` is evaluated in comb block. 
                    // We can check `char_last` here.

                    // Actually, the `if (current_state == STATE_PARSING_TOKEN)` block above handles accumulation.
                    // We need to handle the "Store" action here.
                    // Let's move store logic to the edge of STATE_PARSING_TOKEN.
                end
            end

            // Handle Store on STATE_PARSING_TOKEN exit (comb logic driven)
            // To avoid race conditions, let's detect edge.
            // If we are in STATE_PARSING_TOKEN and `char_valid` is high and `next_state` is not STATE_PARSING_TOKEN (meaning we are leaving), we store.
            // But `next_state` is comb.
            // Let's rely on state change detection.

            // Let's simplify: 
            // In STATE_PARSING_TOKEN: accumulate.
            // When leaving STATE_PARSING_TOKEN (detected by state change), store value and inc count.
            // Wait, `current_state` updates to next_state next clock edge.
            // So if `current_state == STATE_PARSING_TOKEN` and `next_state != STATE_PARSING_TOKEN`, we are at the last cycle of parsing.
            // We should store then.

            // Exception: Validation of T1. 
            // In `IDLE` with token_count == 1, we check T1 constraints.
            // If invalid, we go to INVALID. 
            // If valid, we wait for T2. 
            // This implies T1 is already stored.

            // Let's clean up the store logic:
            if (current_state == STATE_PARSING_TOKEN && (next_state != STATE_PARSING_TOKEN)) begin
                // Leaving STATE_PARSING_TOKEN. Store value.
                // Only store if not invalid (though next_state handles that).
                // Store regardless of validity, validity checked in next state.
                if (token_count == 0) token_values[0] <= current_val;
                else if (token_count == 1) token_values[1] <= current_val;
                else if (token_count == 2) token_values[2] <= current_val;

                if (next_state != STATE_INVALID) begin
                    token_count <= token_count + 1;
                end else begin
                    // On invalid, keep count as is or reset?
                    // Just stop.
                end
            end

            // Handle T1 immediate check in IDLE (Wait, we store T1 -> IDLE. T1 count becomes 1.)
            // In IDLE with count 1, we check T1.
            // If T1 valid, we stay in IDLE (waiting for T2 start). 
            // If T1 invalid, we go to INVALID.
            // This logic is in `next_state`.

            // The T2/T3 prime check logic needs `current_val` reset?
            // No, `current_val` accumulates T1, then T2, then T3.
            // We store them in `token_values` array.
            // So `current_val` can be reused.

            // Result and Done
            if (current_state == STATE_VALID) begin
                result <= 1;
                done <= 1;
            end else if (current_state == STATE_INVALID) begin
                result <= 0;
                done <= 1;
            end else if (current_state == STATE_DONE_WAIT) begin
                // Keep done high
                done <= 1;
            end else begin
                result <= 0;
                done <= 0;
            end
        end
    end

endmodule
