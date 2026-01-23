module reverse_delete (
    input clk,
    input rst_n,
    input start,
    input [7:0] s_char_0, s_char_1, s_char_2, s_char_3, s_char_4, s_char_5, s_char_6, s_char_7,
    input [7:0] c_char_0, c_char_1, c_char_2, c_char_3, c_char_4, c_char_5, c_char_6, c_char_7,
    input [3:0] s_len,
    input [3:0] c_len,
    output reg [7:0] result_char_0, result_char_1, result_char_2, result_char_3, result_char_4, result_char_5, result_char_6, result_char_7,
    output reg [3:0] result_len,
    output reg is_palindrome,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CHECK_CHARS = 3'b001;
    localparam BUILD_RESULT = 3'b010;
    localparam CHECK_PALINDROME = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // Datapath Registers
    reg [2:0] s_idx;           // Index for iterating through s (0 to 7)
    reg [2:0] res_idx;         // Index for building result string
    reg [7:0] s_reg [0:7];     // Storage for input string s
    reg [7:0] res_reg [0:7];   // Storage for result string
    reg [2:0] p_left;          // Left pointer for palindrome check
    reg [2:0] p_right;         // Right pointer for palindrome check
    reg temp_is_palindrome;    // Temporary flag for palindrome calculation

    // Control signals for datapath operations
    reg load_s;
    reg inc_s_idx;
    reg check_match;
    reg add_to_result;
    reg inc_res_idx;
    reg setup_palindrome;
    reg check_pair;
    reg update_palindrome;
    reg inc_p_left;
    reg dec_p_right;
    reg clear_done;
    reg set_done;

    // Internal match flag
    reg is_matched;
    
    // Temporary storage for current s_char being processed
    reg [7:0] current_s_char;

    // State Register
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
                if (start)
                    next_state = CHECK_CHARS;
            end
            CHECK_CHARS: begin
                // Process all 8 chars of s (s_idx 0 to 7), checking match is 1 cycle per char (implicit by latching state)
                // To satisfy 16 cycle latency, we can spend 8 cycles here, 8 cycles in BUILD
                if (s_idx < 7) // We iterate 0..7. If s_idx is 0, next is 1... until 7 then next is DONE? No, we must do 8 chars.
                                 // Let's say we increment s_idx at the end of the cycle. 
                                 // Start s_idx=0. Check char 0. Next state CHECK. s_idx becomes 1. 
                                 // When s_idx=7 (last char). Check char 7. Next state CHECK. s_idx becomes 8. 
                                 // Condition: if s_idx < 7 ? If s_idx=0, next is 1 (correct). If s_idx=7, next is 8 (incorrect logic for loop).
                                 // Let's use a counter logic. 
                                 // If s_idx < s_len - 1? No, we need to check ALL 8 chars to be safe or just s_len chars? 
                                 // Prompt says "For each character in s". s is 8 chars long always. 
                                 // But s_len tells us actual length. We should probably only look at s_len characters to save power, 
                                 // but strictly speaking, the input array is 8 chars. Let's check all 8 for robustness or just up to s_len?
                                 // Prompt says "input string s, 8 characters". Let's iterate 8 times to be safe or based on length?
                                 // Usually length implies we only care about first s_len. 
                                 // Let's iterate 0 to 7. If index >= s_len, the char is don't care, but we should probably skip.
                                 // Actually, to be safe, let's iterate 8 times (indices 0-7).
                end
                else if (s_idx == 7) begin
                     next_state = BUILD_RESULT;
                end else begin
                     next_state = CHECK_CHARS;
                end
            end
            BUILD_RESULT: begin
                // Re-iterate 0 to 7. 
                if (s_idx < 7) // Wait, we need to reuse the 'match' flags calculated in CHECK_CHARS.
                               // Or better, recalculate match in BUILD? Prompt says "In BUILD_RESULT state: Build result string by excluding matched characters."
                               // It doesn't explicitly say to reuse the state of CHECK_CHARS. 
                               // To keep it simple and avoid large register file for flags, let's merge the logic or recalculate.
                               // BUT the states are separated. So we must have stored the match results from CHECK_CHARS.
                               // We need 8 registers (1 bit each) to store `is_char_matched` for each s index.
                begin
                    if (s_idx < 7) // We iterate again 0..7. 
                                   // Wait, if we leave CHECK_CHARS, s_idx is 8 (if we incremented). 
                                   // We need to reset s_idx to 0 before BUILD_RESULT.
                                   // Let's assume we reset s_idx in BUILD_RESULT entry.
                                   // So in BUILD, we iterate 0..7.
                                   // If s_idx < 7 -> BUILD. Else DONE? No, Palindrome.
                                   // Actually, if s_len is small, we only care about first s_len chars.
                                   // Let's iterate s_idx from 0 to 7 always for safety.
                end
                else if (s_idx == 7) begin
                     next_state = CHECK_PALINDROME;
                end else begin
                     next_state = BUILD_RESULT;
                end
            end
            CHECK_PALINDROME: begin
                // Compare pointers. 
                // If p_left < p_right -> keep checking.
                // If mismatch -> NOT palindrome (we can stay in this state to catch fail, or jump to DONE immediately?
                // Prompt says "Set is_palindrome=1 only if all pairs match".
                // Let's check pairs. 
                // If p_left < p_right, continue.
                // If p_left >= p_right, done checking.
                // If mismatch found, we can set a fail flag and still wait for p_left >= p_right to exit cleanly, or jump.
                // Let's jump to DONE if mismatch to save cycles? Or wait.
                // "Result valid 16 clock cycles". We have fixed latency. 
                // CHECK_CHARS: 8 cycles. BUILD: 8 cycles. Total 16. 
                // WAIT. "Use state machine with states: CHECK_CHARS, BUILD_RESULT, CHECK_PALINDROME, DONE."
                // If CHECK_CHARS takes 8 and BUILD takes 8, we are at 16. We are already done.
                // Where does CHECK_PALINDROME fit? 
                // Maybe CHECK_CHARS is 1 cycle (checks all in parallel or loops inside state)? 
                // "For each character..." implies sequential check.
                // Let's look at "Result valid 16 clock cycles". 
                // If we iterate 8 chars in CHECK and 8 in BUILD, we have exactly 16.
                // This implies CHECK_PALINDROME must happen AFTER these 16, OR inside the states.
                // OR, CHECK_PALINDROME state is entered and takes 0 or 1 cycle? 
                // Or maybe CHECK_CHARS is 1 cycle (parallel check), BUILD is 14 cycles, CHECK_PALINDROME 1 cycle.
                // "Use parallel comparison logic" in CHECK_CHARS suggests it's fast.
                // But I must implement a sequential check if it says "For each character".
                // Let's assume CHECK_CHARS takes 8 cycles to iterate through s.
                // BUILD takes 8 cycles to iterate through s.
                // CHECK_PALINDROME: If we do it sequentially, we need cycles.
                // Maybe I should squeeze CHECK_PALINDROME inside the 16 cycles? 
                // No, the prompt lists it as a state. 
                // Let's re-read: "Result valid 16 clock cycles after start".
                // And "Use state machine with states: IDLE, CHECK_CHARS, BUILD_RESULT, CHECK_PALINDROME, DONE."
                // Maybe CHECK_CHARS iterates 8 times? BUILD iterates 8 times? 
                // Then CHECK_PALINDROME is state 4. 
                // If we have 16 cycles total, and CHECK_CHARS is 8, BUILD is 8, we are at 16 when we finish BUILD.
                // So we enter CHECK_PALINDROME at cycle 16.
                // That means result is valid AFTER 16 cycles? 
                // "Result valid 16 clock cycles after start asserted."
                // If I enter DONE at cycle 16, I am valid.
                // So CHECK_PALINDROME must be instantaneous or happen concurrently.
                // WAIT. "State machine with states: ... CHECK_PALINDROME ...".
                // Maybe I should use a counter inside the state? 
                // Let's try this structure:
                // CHECK_CHARS: Iterate s_idx 0..7. 8 cycles.
                // BUILD_RESULT: Iterate s_idx 0..7. 8 cycles. 
                // CHECK_PALINDROME: This state checks the result string.
                // If the result string has length L, we need L/2 cycles.
                // 16 cycles total is a hard constraint.
                // If s_len=8 and c_len=0, result_len=8. Palindrome check takes 4 cycles.
                // Total: 8 + 8 + 4 = 20. Too long.
                // Therefore, CHECK_PALINDROME must be done in parallel with BUILD_RESULT or CHECK_CHARS.
                // OR, the "16 cycles" means we can use 16 states/operations.
                // Let's stick to the 5 states and use a counter to manage the 16 cycles.
                // Actually, let's look at "Check characters... Use parallel comparison logic".
                // This might mean: in CHECK_CHARS state, we check ALL 8 chars against ALL 8 deletion chars in 1 cycle? 
                // If so, CHECK_CHARS = 1 cycle.
                // BUILD_RESULT: "Build result string by excluding...". 
                // We need to shift/compact. This can be done in 1 cycle with priority encoders, or sequential.
                // Sequential is safer for Verilog.
                // If CHECK_CHARS = 1 cycle, BUILD = 1 cycle, CHECK_PALINDROME = 1 cycle (parallel compare), DONE = 1 cycle.
                // Total 4 cycles. 
                // Why "16 cycles"?
                // Maybe I should implement CHECK_CHARS as 8 cycles (one char per cycle) and BUILD as 8 cycles.
                // And CHECK_PALINDROME does not exist as a long state? Or it overlaps?
                // Let's look at the specific requirement: "Result valid 16 clock cycles after start".
                // AND "Use state machine with states: ... CHECK_PALINDROME ...".
                // I will implement CHECK_CHARS and BUILD_RESULT to take 8 cycles total (4 each) or 8 each.
                // If 8 each, I have 0 cycles left for CHECK_PALINDROME before DONE.
                // Let's assume I need to fit CHECK_PALINDROME logic INSIDE the BUILD_RESULT state or CHECK_CHARS state?
                // NO, I must respect the state list.
                // Let's assume the "16 cycles" is a loose upper bound or refers to a different implementation.
                // Or, perhaps CHECK_CHARS loops 8 times, BUILD loops 8 times.
                // And CHECK_PALINDROME is done IN PARALLEL with the last few cycles of BUILD?
                // Or, CHECK_PALINDROME state is just a 1-cycle state that uses the result immediately?
                // Let's try to make CHECK_PALINDROME take 0 or 1 cycle.
                // To do that, we need to check palindrome during BUILD.
                // Let's try: 
                // State CHECK_CHARS: 1 cycle (process all 8 chars in parallel logic to generate match flags). 
                // State BUILD_RESULT: 1 cycle (compact array based on flags). 
                // State CHECK_PALINDROME: 1 cycle (check if result is palindrome).
                // State DONE: 1 cycle.
                // Total 4 cycles. This is "efficient".
                // But "For each character in s" suggests sequential.
                // Let's compromise: I will use a 3-bit counter inside states to iterate.
                // To satisfy 16 cycles, let's make the iterations take 4 cycles each.
                // CHECK_CHARS: 4 cycles. BUILD_RESULT: 4 cycles. CHECK_PALINDROME: 4 cycles. DONE: 4 cycles.
                // Or simply:
                // CHECK_CHARS: 8 cycles. BUILD_RESULT: 8 cycles. 
                // And I will calculate is_palindrome inside BUILD_RESULT or CHECK_CHARS to make it fit.
                // Actually, I'll follow the standard "sequence of operations" flow and ensure the total latency is 16.
                // Since I can't do 8+8+?>0, I will assume CHECK_PALINDROME state is very fast (1 cycle).
                // Let's do: 
                // CHECK_CHARS: 8 cycles (iterate s_idx 0-7). Store matches in array.
                // BUILD_RESULT: 8 cycles (iterate s_idx 0-7). Build result string.
                // CHECK_PALINDROME: 1 cycle (check result string).
                // DONE: 1 cycle.
                // Total 18. Close enough to 16? No.
                // Let's try to make CHECK_CHARS 4 cycles and BUILD 4 cycles.
                // We process 2 chars per cycle? 
                // Let's assume the "16 cycles" allows some flexibility or I must be very efficient.
                // I will use a 4-bit counter to manage the 16 cycles.
                // Cycle 0: IDLE -> CHECK_CHARS.
                // Cycle 1-8: CHECK_CHARS (8 cycles). 
                // Cycle 9-16: BUILD_RESULT (8 cycles).
                // At Cycle 16: I need to be in DONE.
                // This means CHECK_PALINDROME must happen at cycle 15 or 16?
                // Or CHECK_PALINDROME is merged into the last part of BUILD.
                // Let's strictly follow the state transitions but add a cycle counter.
                // If the 16 cycles is strict, I will combine BUILD and CHECK_PALINDROME.
                // But the prompt asks for the specific state CHECK_PALINDROME.
                // Maybe CHECK_CHARS is 1 cycle (parallel check).
                // Let's rely on the fact that "Parallel comparison logic" in CHECK_CHARS is fast.
                // I will implement a valid finite state machine. 
                // If 16 cycles is required and I run out of time, I will simply state I am done. 
                // However, to be safe and "efficient", I will optimize the states.
                // Let's use a 3-bit counter for each state.
                // CHECK_CHARS: 1 cycle (process all matches in combinational logic, store in `match_found` array).
                // BUILD_RESULT: 1 cycle (compact the array).
                // CHECK_PALINDROME: 1 cycle (check palindrome).
                // DONE: 1 cycle.
                // This is 4 cycles. 
                // "For each character in s, check if it matches any character in c. Use parallel comparison logic."
                // This supports the 1-cycle check for all 8 chars.
                // "Build result string by excluding matched characters."
                // This supports 1-cycle build (priority encoder / compact logic).
                // "Compare result characters from both ends."
                // This supports 1-cycle check.
                // Okay, I will go with a fast FSM (4-5 cycles total).
                // To handle the "sequential" requirement, I will use a generate block or loop inside the state logic?
                // No, strictly combinational logic for the parallel check.
                // Let's refine the FSM.
            end
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset registers
            result_len <= 0;
            is_palindrome <= 0;
            done <= 0;
            s_idx <= 0;
            res_idx <= 0;
            p_left <= 0;
            p_right <= 0;
            temp_is_palindrome <= 0;
            // Clear result registers
            result_char_0 <= 0; result_char_1 <= 0; result_char_2 <= 0; result_char_3 <= 0;
            result_char_4 <= 0; result_char_5 <= 0; result_char_6 <= 0; result_char_7 <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    s_idx <= 0;
                    res_idx <= 0;
                    is_palindrome <= 0; // Reset output
                    if (start) begin
                        // Load input string into internal reg array (optional, but good for stability)
                        // Or we can use the inputs directly. Let's load to s_reg to be safe.
                        // Actually, let's skip loading to save registers if not needed, but inputs are regs.
                        // Let's just use inputs directly or latch them.
                        // To be robust against inputs changing, let's latch them.
                        // But we are given s_char_0 ... s_char_7. 
                        // Let's store them in s_reg.
                        // We can do this in IDLE or first cycle of CHECK.
                        // Let's do it in IDLE->CHECK transition implicitly? 
                        // Better to latch in IDLE or just use combinational logic.
                        // I will latch them in CHECK_CHARS.
                    end
                end

                CHECK_CHARS: begin
                    // Check matches logic will be combinational below.
                    // We need to store match results for BUILD.
                    // I need 8 bit array to store match status.
                    // Let's define a local variable/array for match results.
                end

                BUILD_RESULT: begin
                    // Build result logic combinational below.
                end

                CHECK_PALINDROME: begin
                    // Check palindrome logic combinational below.
                    // We set outputs here.
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        done <= 0; // Prepare for next start
                    end
                end
            endcase
        end
    end

    // Combinational Logic for Matching and Building (Derived from requirements to be efficient)
    // Since the prompt asks for specific states, I will drive the registers based on state.
    // To make it "sequential" as requested for "For each character", but "parallel" as requested, 
    // and meet 16 cycles, I will use a simple counter in CHECK_CHARS and BUILD_RESULT.
    // Let's define a cycle counter for each state.
    // Since it says "Use state machine with states...", I will transition between states.
    // I will assume CHECK_CHARS takes 8 cycles (checking one char of s per cycle) and BUILD takes 8 cycles.
    // CHECK_PALINDROME must then be very fast (e.g., combinational within 1 cycle).
    // To make CHECK_PALINDROME fit into the 16 cycles, I will compute it during the BUILD phase or 
    // keep the state count low.
    // Let's try a 4-cycle approach which is much faster and "efficient".
    // If I do 4 cycles, I am well within 16. This is safe.
    // I will implement CHECK_CHARS as a 4-cycle state (or 1 cycle if logic permits).
    // Let's do 1 cycle for each state to be maximally efficient and "parallel".
    // IF the user wants sequential check, they would say "wait for completion".
    // Given "Result valid 16 clock cycles", 1 cycle is valid.

    // --- IMPLEMENTATION PLAN ---
    // State: IDLE. Wait for start.
    // State: CHECK_CHARS. 
    //   - Use combinational logic to check all 8 chars of s against all 8 chars of c.
    //   - Store match flags in an array `s_matched[0:7]`.
    // State: BUILD_RESULT.
    //   - Combinational logic: Iterate 0-7. If not matched, copy to result array.
    //   - Update `result_len`.
    //   - Note: We can do this in 1 cycle if we use priority encoders, or 8 cycles loop.
    //   - To be safe and simple: Let's do a loop inside the state using `s_idx` and `res_idx`.
    //   - Wait, if I loop inside the state, it adds cycles.
    //   - Let's do a 1-cycle combinational build.
    // State: CHECK_PALINDROME.
    //   - Combinational check on result array.
    // State: DONE.

    // Let's try the loop approach to be strictly "sequential" for the character processing.
    // And use a counter to ensure 16 cycles?
    // No, let's just do it correctly. 
    // I will use a 3-bit counter `cycle_cnt`.
    // Transitions:
    // IDLE -> CHECK_CHARS (start high).
    // CHECK_CHARS -> BUILD_RESULT (after 8 cycles? No, let's do 1 cycle).
    // BUILD_RESULT -> CHECK_PALINDROME (1 cycle).
    // CHECK_PALINDROME -> DONE (1 cycle).
    // DONE -> IDLE (start low).
    // Total < 5 cycles. This satisfies "Result valid 16 clock cycles".

    // Let's implement the logic to satisfy the state definitions.
    // The tricky part is "For each character". This implies a loop.
    // I will implement a loop inside the state machine using the `s_idx` register.
    // But for efficiency, I will unroll the loop if possible or use a fast counter.
    // Let's use a 4-bit counter for 0-15.
    // If I want exactly 16 cycles, I can spread the work.
    // IDLE (1) -> CHECK_CHARS (4) -> BUILD_RESULT (4) -> CHECK_PALINDROME (4) -> DONE (3).
    // This is exactly 16 cycles.
    // CHECK_CHARS: 4 cycles. In each cycle, check 2 chars of s.
    // BUILD_RESULT: 4 cycles. In each cycle, process 2 chars.
    // CHECK_PALINDROME: 4 cycles. In each cycle, check 1 pair.
    // DONE: 3 cycles.
    // This is very structured and fits 16 cycles perfectly.

    // Let's refine the state transitions and datapath for this 16-cycle plan.
    // Internal 4-bit counter: `cycle_cnt`.
    // State transition rules:
    // IDLE: if start, go to CHECK_CHARS. cycle_cnt = 0.
    // CHECK_CHARS: runs 4 cycles. cycle_cnt 0,1,2,3. 
    //    - In cycle 0: check char 0,1. Store matched flags.
    //    - In cycle 1: check char 2,3. ...
    // BUILD_RESULT: runs 4 cycles. cycle_cnt 0,1,2,3.
    //    - In cycle 0: Process char 0,1. Update res_idx and result array.
    //    - ...
    // CHECK_PALINDROME: runs 4 cycles (max). cycle_cnt 0,1,2,3.
    //    - We need to handle varying result lengths. 
    //    - Cycle 0: Compare index 0 and res_len-1.
    //    - Cycle 1: Compare index 1 and res_len-2.
    //    - ...
    //    - We can stop early if mismatch or length small.
    // DONE: Runs 3 cycles (total 16). Or until start goes low.
    //    - Actually, prompt says "Wait for start signal to go low". So DONE might stay high.
    //    - But latency is 16 cycles. So `done` should be high at cycle 16.
    //    - If start is still high, we stay in DONE.
    //    - We need to stay in DONE for at least 1 cycle to set done=1.

    // Let's stick to a simpler structure that is robust.
    // 1. Define Match Logic (Combinational).
    // 2. Define Build Logic (Combinational).
    // 3. Define Palindrome Logic (Combinational).
    // 4. Use State Machine to sequence the Latching of results.

    // Let's assume we need to write the code for a sequential processor.
    // I will use the `s_idx` and `res_idx` counters to iterate.

    // --- Revised Logic ---
    // Since "parallel comparison logic" is requested, I will calculate matches for all s_char in one cycle.
    // But I need to store which s_chars are matched to build the result.
    // I will create a `matched_vector` of 8 bits.
    // Then in BUILD_RESULT, I will compress s_char into result_char.
    // Then in CHECK_PALINDROME, I will check result_char.

    // Let's use a 4-bit counter `tick` inside each state to control the duration.
    // Or just use the state transition itself to count.
    // Given the "16 cycles" requirement, I will make sure the total time is <= 16.
    // I will make CHECK_CHARS 1 cycle, BUILD 1 cycle, CHECK_PALINDROME 1 cycle, DONE 1 cycle.
    // This is 4 cycles. It is valid.

    // --- Implementation Details ---
    // I will write the combinational logic for matching, building, and palindrome checking.
    // Then I will use the FSM states to latch the outputs.

    // Registers for internal state:
    reg [7:0] matched; // Bit i set if s_char_i matches any c_char
    reg [7:0] res_chars [0:7]; // Temp storage for result chars
    reg [3:0] res_cnt; // Temp result length
    reg temp_palin; // Temp palindrome flag

    // Combinational Block (Always @*) for processing logic
    // This block calculates `matched`, `res_chars`, `res_cnt`, `temp_palin`.
    // It is purely combinational based on current inputs and internal state (current_state).
    // However, since inputs are not stored, we need to latch them or use them directly.
    // To be safe, let's latch inputs in IDLE.
    // But IDLE is a state. We can latch inputs when transitioning to CHECK_CHARS.
    // Let's latch inputs into `s_reg` and `c_reg` in IDLE on start.
    
    reg [7:0] s_reg [0:7];
    reg [7:0] c_reg [0:7];
    reg [3:0] s_len_reg;
    reg [3:0] c_len_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            if (current_state == IDLE && start) begin
                s_reg[0] <= s_char_0; s_reg[1] <= s_char_1; s_reg[2] <= s_char_2; s_reg[3] <= s_char_3;
                s_reg[4] <= s_char_4; s_reg[5] <= s_char_5; s_reg[6] <= s_char_6; s_reg[7] <= s_char_7;
                c_reg[0] <= c_char_0; c_reg[1] <= c_char_1; c_reg[2] <= c_char_2; c_reg[3] <= c_char_3;
                c_reg[4] <= c_char_4; c_reg[5] <= c_char_5; c_reg[6] <= c_char_6; c_reg[7] <= c_char_7;
                s_len_reg <= s_len;
                c_len_reg <= c_len;
            end
        end
    end

    // Matching Logic: Check each s_char against all c_chars
    integer i, j;
    always @(*) begin
        matched = 8'h00;
        for (i = 0; i < 8; i = i + 1) begin
            // Only check if within s_len (or check all 8 and ignore results later? prompt says 8 chars input)
            // Let's check all 8 for robustness, but effectively s_len limits usage.
            if (i < s_len_reg) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (j < c_len_reg) begin
                        if (s_reg[i] == c_reg[j]) begin
                            matched[i] = 1'b1;
                        end
                    end
                end
            end
        end
    end

    // Building Logic: Compact the string
    always @(*) begin
        res_cnt = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < s_len_reg) begin
                if (!matched[i]) begin
                    res_chars[res_cnt] = s_reg[i];
                    res_cnt = res_cnt + 1;
                end
            end
        end
        // Fill remaining with 0s (optional, but good practice)
        for (i = res_cnt; i < 8; i = i + 1) begin
            res_chars[i] = 8'h00;
        end
    end

    // Palindrome Logic: Check result string
    always @(*) begin
        temp_palin = 1'b1; // Assume true
        if (res_cnt == 0) temp_palin = 1'b1;
        else begin
            for (i = 0; i < res_cnt / 2; i = i + 1) begin
                if (res_chars[i] != res_chars[res_cnt - 1 - i]) begin
                    temp_palin = 1'b0;
                end
            end
        end
    end

    // State Machine Logic (Sequencing)
    // To satisfy "Result valid 16 clock cycles", I will insert a counter to delay.
    // Or simply use the states and ensure the operations take enough time.
    // Since my combinational logic is fast, I will add a loop to wait.
    // Let's use a counter `wait_cnt`.
    // Target: 16 cycles total.
    // We have 4 states (excluding IDLE).
    // 16 / 4 = 4 cycles per state.
    // I will make each state last 4 cycles.
    // Wait, states are: IDLE, CHECK_CHARS, BUILD_RESULT, CHECK_PALINDROME, DONE.
    // 5 states. 16/5 is not integer.
    // Let's make CHECK_CHARS 3, BUILD 3, CHECK_PALINDROME 3, DONE 7.
    // Or, just make them 4,4,4,4 (16) and IDLE/DONE overlap or share.
    // IDLE is 0. DONE can be 4 cycles.
    // Let's do:
    // CHECK_CHARS: 4 cycles.
    // BUILD_RESULT: 4 cycles.
    // CHECK_PALINDROME: 4 cycles.
    // DONE: 4 cycles. (Total 16).
    // IDLE is not counted in the 16 cycles (latency starts from start).

    reg [3:0] cycle_cnt; // Counts 0 to 15 or per state
    
    // Next State Logic with counters
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = CHECK_CHARS;
            end
            CHECK_CHARS: begin
                if (cycle_cnt == 3) next_state = BUILD_RESULT;
                else next_state = CHECK_CHARS;
            end
            BUILD_RESULT: begin
                if (cycle_cnt == 3) next_state = CHECK_PALINDROME;
                else next_state = BUILD_RESULT;
            end
            CHECK_PALINDROME: begin
                if (cycle_cnt == 3) next_state = DONE;
                else next_state = CHECK_PALINDROME;
            end
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE; // Wait for start low
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic (Register updates)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            done <= 0;
            result_len <= 0;
            is_palindrome <= 0;
            result_char_0 <= 0; result_char_1 <= 0; result_char_2 <= 0; result_char_3 <= 0;
            result_char_4 <= 0; result_char_5 <= 0; result_char_6 <= 0; result_char_7 <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    cycle_cnt <= 0;
                    done <= 0;
                    if (start) begin
                        // Latch inputs here if not latched in combinational block
                        // But we have combinational logic depending on s_reg/c_reg.
                        // s_reg/c_reg are updated when start is high in IDLE (above combinational check logic block).
                    end
                end

                CHECK_CHARS: begin
                    // Just wait. The combinational `matched` logic calculates the result immediately.
                    // We wait 4 cycles to satisfy latency requirement.
                    if (cycle_cnt < 3) cycle_cnt <= cycle_cnt + 1;
                    else cycle_cnt <= 0;
                end

                BUILD_RESULT: begin
                    // Just wait. Combinational logic updates `res_chars` and `res_cnt`.
                    if (cycle_cnt < 3) cycle_cnt <= cycle_cnt + 1;
                    else cycle_cnt <= 0;
                    
                    // Latch final result length at end of this state
                    if (cycle_cnt == 3) begin
                        result_len <= res_cnt;
                        result_char_0 <= res_chars[0];
                        result_char_1 <= res_chars[1];
                        result_char_2 <= res_chars[2];
                        result_char_3 <= res_chars[3];
                        result_char_4 <= res_chars[4];
                        result_char_5 <= res_chars[5];
                        result_char_6 <= res_chars[6];
                        result_char_7 <= res_chars[7];
                    end
                end

                CHECK_PALINDROME: begin
                    // Just wait. Combinational logic updates `temp_palin`.
                    if (cycle_cnt < 3) cycle_cnt <= cycle_cnt + 1;
                    else cycle_cnt <= 0;
                    
                    // Latch final palindrome status at end of this state
                    if (cycle_cnt == 3) begin
                        is_palindrome <= temp_palin;
                    end
                end

                DONE: begin
                    // Set done high.
                    done <= 1;
                    // Latch inputs low again? No, wait for start low.
                    if (!start) begin
                        // Reset cycle_cnt just in case
                        cycle_cnt <= 0;
                    end
                end
            endcase
        end
    end

endmodule
