module harmonic_sum(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALCULATE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [4:0] counter, next_counter;     // Loop counter k (1 to n-1)
    reg [31:0] accumulator, next_accumulator; // Q16.16 accumulator
    reg [31:0] next_result;
    reg next_done;

    // Division logic: 65536 / (counter + 1)
    // counter + 1 is the divisor (k)
    // Since k is small (2 to 16), we can calculate the term in one cycle
    wire [4:0] divisor;
    wire [31:0] inv_term;

    assign divisor = counter + 1;
    assign inv_term = 65536 / divisor; // Integer division to compute Q16.16 1/k

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 5'b0;
            accumulator <= 32'b0;
            result <= 32'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            counter <= next_counter;
            accumulator <= next_accumulator;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_counter = counter;
        next_accumulator = accumulator;
        next_result = result;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    // Initialize: accumulator = 1.0 (for k=1), counter = 1
                    next_counter = 5'd1;
                    next_accumulator = 32'd65536;
                    next_state = CALCULATE;
                end else begin
                    next_counter = 5'b0;
                    next_accumulator = 32'b0;
                end
            end

            CALCULATE: begin
                if (start) begin
                    // Maintain state if start is still held high
                    // Or restart if desired (here we stick to iteration)
                end
                
                // Compute term for current k = counter
                // Wait for divisor logic to settle (combinational)
                // Add term to accumulator
                next_accumulator = accumulator + inv_term;
                
                // Check if we need to stop
                // n is number of terms (n-1)
                // We need to add terms for k=1 to n-1.
                // If n=1, we skip calculation (handled in IDLE? No, spec says IDLE init for n=1? 
                // Spec: "IDLE: ... initialize counter=1, accumulator=65536".
                // But if n=1, terms = 0, so result = 1.0 (for k=1?)
                // Spec: "For n=1, result = 1.0".
                // Spec: "for k from 1 to n-1".
                // Logic fix: If n=1, n-1=0. No terms to add. Result = 0? No, spec says 1.0.
                // Spec says "Initialize counter=1, accumulator=65536 (for k=1 term)".
                // This implies the 1st term (k=1) is handled in IDLE or always present.
                // However, the loop says "for k from 1 to n-1".
                // Let's re-read: "H(n-1) = 1 + 1/2 ...". Usually harmonic series starts at 1.
                // Spec: "For n=2, result=1.0". (1 term). 
                // Spec: "For n=3, result=1.0 + 0.5". (2 terms).
                // So if n=1, we expect 0 terms? But spec says 1.0.
                // Ah, "Calculate 1/k... Iterate: for k=1 to n-1".
                // And IDLE initializes accumulator=65536.
                // If n=1: IDLE sets acc=65536. We must go to DONE immediately.
                // If n=2: IDLE sets acc=65536. We need 0 additions. Immediate DONE?
                // Spec: "Done goes high approx (n-1)+2 clock cycles".
                // For n=1: 0 cycles? 
                // Let's refine IDLE logic to handle n=1 and n=2 cases.
                // If n <= 2, we should go directly to DONE from IDLE (or minimal delay).
                
                // In CALCULATE state, we assume we are adding the term for 'counter'.
                // But the 'inv_term' is computed based on 'counter'.
                // The initial accumulator in IDLE was 65536 (for k=1).
                // So we start adding for k=2? 
                // Spec: "IDLE: initialize counter=1, accumulator=65536 (for k=1 term)".
                // Spec: "CALCULATE: compute 65536 / (counter+1), add to accumulator, increment counter".
                // So if counter starts at 1:
                // Cycle 1: Add 1/2 (65536/2). Counter becomes 2.
                // This matches "for k from 1 to n-1" if we consider the accumulator initialized with k=1.
                // The loop body adds k=2, 3, ... 
                // Wait, "for k from 1 to n-1". Usually 1 to X inclusive.
                // If counter=1, we add 1/2. This covers k=2? No.
                // Let's trace n=3 (terms 1, 1/2):
                // IDLE: acc=65536 (1.0), counter=1. n=3. Target n-1=2.
                // Move to CALC.
                // CALC: Divisor = counter+1 = 2. Term = 1/2. Add. Acc = 1.5. Counter = 2.
                // Check termination: Is counter >= n-1? n-1=2. Counter=2. Yes.
                // Move to DONE.
                // This works.
                // Trace n=1 (terms 0? Spec says 1.0):
                // IDLE: acc=65536, counter=1. n=1. Target n-1=0.
                // Check termination in IDLE? Or wait for CALC.
                // If we go to CALC: Divisor=2. Term=1/2. Acc=1.5. Counter=2. 
                // This produces 1.5 for n=1. Incorrect.
                // The spec says "IDLE: initialize... move to CALCULATE". Unconditional.
                // But it also says "iterative loop for k from 1 to n-1".
                // If n=1, loop range is empty.
                // We must handle the termination check BEFORE adding.
                // Or handle it in IDLE.
                // Better approach: 
                // IDLE: Check if n <= 1. If so, go to DONE immediately (result=1.0).
                // If n > 1, go to CALCULATE with counter=1.
                // CALCULATE: 
                //   Add term (1/counter+1).
                //   Increment counter.
                //   If counter < n, stay in CALC.
                //   Else go to DONE.
                //   (Note: n is the number of terms. n=2 means add 1/2 once).
                //   Wait, spec says "counter >= n-1". 
                //   Let's stick to spec: accumulator starts with 1.0.
                //   Loop adds 1/2, 1/3... up to 1/(n-1).
                //   Total terms = n-1? No, 1 + (n-2)? 
                //   Spec: H(n-1). Example n=3 -> H(2). Terms: 1, 1/2. Total 2 terms.
                //   Formula: 1/k for k=1 to n-1.
                //   If n=3: k=1, 2.
                //   IDLE init: accumulator = 1 (k=1). counter=1.
                //   We need to add terms for k=2.
                //   CALC: divisor = counter+1 = 2. Add 1/2. Counter becomes 2.
                //   Is counter >= n-1? n-1=2. Counter=2. Yes.
                //   So we stop.
                //   If n=1: n-1=0. We need to add terms for k=1 to 0. None.
                //   IDLE init puts 1.0 in accumulator. This is wrong if n=1 implies 0 terms.
                //   But spec explicitly says "For n=1, result = 1.0".
                //   AND it says IDLE initializes accumulator=65536.
                //   So the "start" of iteration implies k=1 is already done or mandatory.
                //   However, the loop description says "for k from 1 to n-1".
                //   If n=1, loop is empty. Result should be 0. But spec says 1.0.
                //   Contradiction between "H(n-1)" math definition and examples.
                //   Examples:
                //   n=1 -> 1.0
                //   n=2 -> 1.0
                //   n=3 -> 1.5
                //   This looks like Harmonic Sum of (n-1) terms, but starting with 1.0 always?
                //   Or maybe n=1 means 1 term (k=1)? But n-1 = 0.
                //   Maybe n is the limit (exclusive)? 
                //   Or n is the number of terms? 
                //   If n=1: 1 term -> 1.0. (n-1) in text is mistake?
                //   If n=2: 2 terms -> 1.5. But spec says 1.0.
                //   Spec: "For n=2, result = 1.0".
                //   Spec: "H(n-1) = 1 + 1/2 + ... 1/(n-1)".
                //   If n=2, H(1) = 1. OK.
                //   If n=1, H(0) = 0. But spec says 1.0.
                //   Okay, I will follow the Spec Examples and Logic strictly.
                //   "IDLE: ... initialize counter=1, accumulator=65536 (for k=1 term)".
                //   "CALCULATE: compute 65536 / (counter+1), add ... Continue until counter >= n-1".
                //   This implies:
                //   1. IDLE puts 1.0 in accumulator.
                //   2. The loop adds terms starting from 1/2.
                //   3. We stop when we have added enough terms.
                //   Let's check "counter >= n-1".
                //   Target: sum from k=1 to n-1.
                //   Current state: accumulator has k=1. counter=1.
                //   We need to add k=2 to n-1.
                //   Number of additions needed: (n-1) - 1 = n-2.
                //   So we loop while counter < n-1?
                //   Or use counter to track the 'k' we are about to add?
                //   Let's use "counter" as the current index being added.
                //   Actually, spec says: "compute 65536 / (counter+1)". 
                //   So term added is 1/(counter+1).
                //   If counter=1, we add 1/2.
                //   So 'counter' represents the 'previous' k index.
                //   We stop when "counter >= n-1".
                //   Case n=3 (H(2) = 1 + 1/2):
                //     IDLE: acc=1, counter=1.
                //     Check: 1 >= 2? No.
                //     CALC: add 1/2. acc=1.5. Inc counter to 2.
                //     Check: 2 >= 2? Yes. Done. Correct.
                //   Case n=2 (H(1) = 1):
                //     IDLE: acc=1, counter=1.
                //     Check: 1 >= 1? Yes.
                //     Should move to DONE immediately?
                //     Spec says IDLE moves to CALCULATE unconditionally.
                //     So we need to check in CALCULATE.
                //     CALC: Check condition BEFORE adding? Or after?
                //     If we check after: 
                //       n=2: CALC entered. Add 1/2 (counter+1=2). Acc=1.5. Counter=2.
                //       Check: 2>=1. Done. Result=1.5. Wrong.
                //     So we must check BEFORE adding, or have a "pre-check" state.
                //     Or check in IDLE. 
                //     Spec IDLE: "When start=1 ... move to CALCULATE".
                //     But it doesn't say "Check condition".
                //     However, typically we check loop condition at start of loop.
                //     Let's put the check in IDLE. 
                //     If n <= 2, go directly to DONE.
                //     If n > 2, go to CALC.
                //     Spec says: "Latency approx (n-1) + 2".
                //     If n=2, latency = 1 + 2 = 3.
                //     If we go IDLE -> DONE, latency is 2 cycles (IDLE to DONE to IDLE).
                //     So maybe we need to pass through CALC.
                //     Let's try this logic in CALC:
                //       - Compute term (1/(counter+1)).
                //       - Check if (counter+1) > (n-1).
                //       - If yes, we are done, go to DONE.
                //       - If no, add term, increment counter, stay in CALC.
                //     Wait, that skips adding the current term if it's the last.
                //     We want to add 1/(n-1).
                //     Example n=3. Target terms 1, 1/2.
                //     IDLE: acc=1, counter=1. (This covers 1).
                //     CALC (Cycle 1): Term=1/(1+1)=1/2. 
                //        Check: Is 2 > 2 (n-1)? No. Add. Counter=2.
                //     CALC (Cycle 2): Term=1/(2+1)=1/3.
                //        Check: Is 3 > 2? Yes. Don't add. Go DONE.
                //     Result=1.5. Correct.
                //     But this requires 2 cycles of CALC. Spec latency (n-1)+2 = 3 cycles.
                //     We have: IDLE(1) + CALC(2) + DONE(1) = 4 cycles to valid result? 
                //     Spec: "Done goes high approx (n-1)+2 clock cycles after start".
                //     So Done asserted at cycle (n-1)+2.
                //     Start -> IDLE (cycle 1). 
                //     If we use the "Check (counter+1) > (n-1)" logic:
                //       n=3. 
                //       C1: IDLE. acc=1, cnt=1.
                //       C2: CALC. term=1/2. Check 2>2? No. Add. cnt=2.
                //       C3: CALC. term=1/3. Check 3>2? Yes. Move DONE. 
                //       C4: DONE. 
                //       Done high at C4. Start was high at C1. Diff = 3.
                //       (n-1)+2 = 2+2 = 4. Mismatch.
                //       Maybe start is sampled at C0?
                //       Let's assume start is pulse.
                //       If start at C0. C1: IDLE detects start. 
                //       C2: CALC.
                //       C3: CALC.
       //       C4: DONE.
       //       Done high at C4. Start at C0. Diff 4. 
       //       Target 4. Match.
       //       (n-1)=2. 2+2=4.
       //       Okay.

                // Revised Logic:
                // IDLE:
                //   if (start) begin
                //     if (n <= 2) next_state = DONE; // Handle n=1, n=2
                //     else next_state = CALCULATE;
                //     accumulator = 65536;
                //     counter = 1;
                //   end
                //   else ... idle.
                // 
                // CALCULATE:
                //   term = 65536 / (counter + 1)
                //   if ( (counter + 1) >= (n - 1) ) begin
                //      // We have added up to 1/(n-1) or just checked the boundary
                //      // Actually, if n=3, we added 1/2. We should stop.
                //      // Wait, in logic above (check > n-1):
                //      //   n=3, n-1=2. 
                //      //   First calc cycle: counter=1. term=1/2. Check 2 >= 2? Yes. 
                //      //   If we stop there, we added 1/2. Result 1.5. Correct.
                //      //   But we need to know if we should add it.
                //      //   Logic: We are at counter=k. We are about to add 1/(k+1).
                //      //   We should add it if k+1 <= n-1.
                //      //   If k+1 > n-1, stop.
                //      //   So: if (counter + 1 > n - 1) next_state = DONE;
                //      //   else begin add; counter++; stay CALC.
                //      //   end
                //   end
                //   
                //   Note: n=1. n-1=0. 
                //   IDLE: n<=2 (1<=2) -> DONE.
                //   Result = 1.0. Correct.
                //   
                //   n=2. n-1=1.
                //   IDLE: n<=2 -> DONE.
                //   Result = 1.0. Correct.
                //   
                //   n=3. n-1=2.
                //   IDLE: n>2 -> CALC. acc=1, cnt=1.
                //   CALC: term=1/2. Check 2 > 2? No. Add. cnt=2.
                //   CALC: term=1/3. Check 3 > 2? Yes. Done.
                //   Result 1.5. Correct.
                //   
                //   Wait, for n=3, we need (n-1)+2 = 4 cycles total.
                //   Start C0 -> IDLE C1 -> CALC C2 -> CALC C3 -> DONE C4.
                //   4 cycles. Correct.
                //   
                //   However, I must adhere to "IDLE: move to CALCULATE".
                //   The prompt says: "IDLE: When start=1 ... move to CALCULATE".
                //   This implies IDLE always goes to CALC.
                //   If I go IDLE -> DONE directly for n=1,2, I am technically violating "move to CALCULATE".
                //   But logically it's correct.
                //   Maybe I can go IDLE -> CALC -> DONE.
                //   In CALC: Check termination immediately.
                //   If n=1: 
                //     IDLE: acc=1, cnt=1.
                //     CALC: term=1/2. Check n-1=0. cnt+1=2 > 0. Stop. 
                //     Result = 1.0 (since we didn't add). 
                //     But we computed term 1/2. That's waste but allowed.
                //   
                //   Let's try to stick to the prompt's state transitions as much as possible while remaining correct.
                //   Prompt: "IDLE: ... move to CALCULATE".
                //   Prompt: "CALCULATE: ... Continue until counter >= n-1".
                //   Wait, "counter >= n-1". 
                //   Counter starts at 1.
                //   n=3: counter=1. 1>=2? No.
                //   n=2: counter=1. 1>=1? Yes. 
                //   So in IDLE, if we detect start, we can check `counter >= n-1`? 
                //   Counter is 1. 
                //   n=2: 1 >= 1. True. So we should go DONE.
                //   But prompt says "move to CALCULATE".
                //   Maybe I should just go to CALCULATE and let the first cycle of CALCULATE handle it?
                //   Or maybe I should implement exactly as described and fix the n=1 case? 
                //   "For n=1, result = 1.0".
                //   "For n=2, result = 1.0".
                //   The description "iterative loop for k from 1 to n-1" combined with "IDLE init acc=65536" is ambiguous for n=1,2.
                //   However, the termination condition "counter >= n-1" is key.
                //   If I go to CALCULATE from IDLE with n=2, counter=1:
                //   CALC state:
                //     Compute term (1/2).
                //     Check if `counter >= n-1`. (1 >= 1).
                //     If true, do not add. Move to DONE.
                //     Result = 1.0.
                //   This satisfies "move to CALCULATE".
                //   And satisfies "Continue until..." (implying check condition).
                //   Does it satisfy latency?
                //   n=2: (n-1)+2 = 3.
                //   Start C0. 
                //   C1: IDLE -> CALC (init).
                //   C2: CALC. Check 1 >= 1. Yes. Move DONE. (Maybe add? No, condition met).
                //   C3: DONE.
                //   Done high at C3. Diff from C0 is 3. Correct.
                //   
                //   n=1: (n-1)+2 = 2.
                //   C1: IDLE -> CALC.
                //   C2: CALC. Check 1 >= 0? Yes. Move DONE.
                //   C3: DONE.
                //   Wait, latency 2 cycles? C1 to C3 is 2 cycles.
                //   Correct.
                //   
                //   n=3: (n-1)+2 = 4.
                //   C1: IDLE -> CALC (cnt=1).
                //   C2: CALC. 1>=2? No. Add 1/2. Inc cnt=2.
                //   C3: CALC. 2>=2? Yes. Move DONE.
                //   C4: DONE.
                //   4 cycles. Correct.
                //   
                //   Wait, for n=3, we only added one term (1/2). 
                //   Accumulator started with 1.0. 
                //   So we have 1.0 + 0.5 = 1.5. Correct.
                //   
                //   BUT. The calculation of term 1/2 happens in C2. 
                //   The term 1/2 is added in C2 (or C3 depending on sync). 
                //   If we use combinational division: 
                //   C2: state=CALC, cnt=1. divisor=2. term=32768.
                //   If we check `cnt >= n-1` (1 >= 2) -> False.
                //   So we update accumulator = accumulator + term.
                //   Increment cnt.
                //   At posedge C3: accumulator updated. cnt=2.
                //   C3: state=CALC, cnt=2. divisor=3. term=21845.
                //   Check `cnt >= n-1` (2 >= 2) -> True.
                //   So we don't add. We go to DONE.
                //   Result updated in C4.
                //   This works.
                //   
                //   Edge case: n=16. 
                //   Loop runs. cnt starts 1. Ends when cnt >= 15.
                //   Last add: cnt=14 (C15). Add 1/15. Inc cnt=15.
                //   Next C16: cnt=15. Check 15 >= 15? Yes. Move DONE.
                //   So loop runs 14 times (cnt 1 -> 14). 
                //   We added terms 1/2 to 1/15? No. 
                //   C2: cnt=1, add 1/2. 
                //   C3: cnt=2, add 1/3.
                //   ...
                //   C15: cnt=14, add 1/15.
                //   C16: cnt=15, stop.
                //   So we added 1/2 ... 1/15. 
                //   We want H(15) = 1 + 1/2 + ... 1/15.
                //   This matches.
                //   
                //   What if n=0? Not possible (5-bit unsigned). Min 0.
                //   n=0 logic: Spec says n=1 min.
                //   If n=0: (n-1) = -1. < operator works. 
                //   Logic should hold.
                
                // Summary of Logic for CALCULATE:
                // 1. Calculate term = 65536 / (counter + 1).
                // 2. Check condition: if (counter >= n - 1)
                //    - If TRUE: next_state = DONE.
                //    - If FALSE: next_accumulator = accumulator + term; next_counter = counter + 1; stay in CALC.

                // Correction: 
                // The state transition happens on posedge clk.
                // The 'accumulator' update must be registered.
                // We check 'counter' (current value) against 'n'.
                // We add term based on 'counter'.
                // So yes, if counter=1, we add 1/2.
                // If counter reaches n-1, we stop adding.
                // Example: n=2. n-1=1. 
                // IDLE: cnt=1.
                // CALC (1st cycle): cnt=1. Term=1/2. 
                // Check: 1 >= 1. TRUE. 
                // Action: next_state = DONE.
                // Result = accumulator (which is 1.0). 
                // Correct.
                
                // Example: n=3. n-1=2.
                // IDLE: cnt=1, acc=1.0.
                // CALC (1st cycle): cnt=1. Term=1/2.
                // Check: 1 >= 2? FALSE.
                // Action: next_acc = 1.0 + 0.5 = 1.5. next_cnt = 2.
                // CALC (2nd cycle): cnt=2. Term=1/3.
                // Check: 2 >= 2? TRUE.
                // Action: next_state = DONE.
                // Result = 1.5.
                // Correct.

                // We need to be careful about the comparison `counter >= n - 1`.
                // If n=1, n-1=0. 
                // IDLE: cnt=1.
                // CALC: 1 >= 0? TRUE. Go DONE.
                // Result = 1.0. Correct.

                // So the logic is sound.
                
                // Let's write the combinational logic.

                // Default hold values
                next_state = state;
                next_counter = counter;
                next_accumulator = accumulator;
                next_result = result;
                next_done = done;

                case (state)
                    IDLE: begin
                        next_done = 1'b0;
                        if (start) begin
                            // Initialize for iteration
                            next_counter = 5'd1;
                            next_accumulator = 32'd65536; // 1.0
                            next_state = CALCULATE;
                        end else begin
                            // Stay in IDLE, clear internal regs if desired, but not required usually
                            // next_counter = 5'b0;
                            // next_accumulator = 32'b0;
                        end
                    end

                    CALCULATE: begin
                        // Check termination condition based on current 'counter'
                        // Condition: Have we added terms up to k = n-1?
                        // We are currently set to add term 1/(counter+1).
                        // If counter >= n-1, we stop.
                        if (counter >= (n - 1)) begin
                            next_state = DONE;
                            // Do not update accumulator
                            // Result will be updated in DONE state
                        end else begin
                            // Compute term and add
                            // Division is combinational: inv_term = 65536 / (counter + 1)
                            next_accumulator = accumulator + inv_term;
                            next_counter = counter + 1;
                            // Stay in CALCULATE
                        end
                    end

                    DONE: begin
                        next_done = 1'b1;
                        next_result = accumulator;
                        if (!start) begin
                            next_state = IDLE;
                            next_done = 1'b0;
                        end
                    end
                endcase
            end

            DONE: begin
                // Explicit state logic (redundant if covered above, but good for clarity)
                next_done = 1'b1;
                next_result = accumulator;
                if (!start) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
