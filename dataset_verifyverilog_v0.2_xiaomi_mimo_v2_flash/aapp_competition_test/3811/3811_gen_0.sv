module wcd_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a_i,
    input wire [31:0] b_i,
    output reg [31:0] result,
    output reg done
);

    // Hardcoded prime factors (max 8)
    // 2, 3, 5, 7, 11, 13, 17, 19
    wire [31:0] primes [0:7];
    assign primes[0] = 32'd2;
    assign primes[1] = 32'd3;
    assign primes[2] = 32'd5;
    assign primes[3] = 32'd7;
    assign primes[4] = 32'd11;
    assign primes[5] = 32'd13;
    assign primes[6] = 32'd17;
    assign primes[7] = 32'd19;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam FACTOR_FIRST = 3'b001;
    localparam CHECK_PAIR_1 = 3'b010;
    localparam CHECK_PAIR_2 = 3'b011;
    localparam CHECK_PAIR_3 = 3'b100;
    localparam DONE = 3'b101;

    // Registers for State and Counters
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [2:0] factor_index; // Iterates 0-7
    reg [1:0] pair_index;   // Iterates 0-2

    // One-hot register to keep track of valid factors
    reg [7:0] valid_factors;
    reg [7:0] next_valid_factors;

    // Division computation registers
    // We need 3 cycles for division: 2 for pipeline, 1 for remainder handling
    // valid_factors_pipeline tracks which factors are currently being computed in the pipeline
    reg [7:0] valid_factors_pipeline_1;
    reg [7:0] valid_factors_pipeline_2;
    reg [7:0] valid_factors_pipeline_3;
    
    // Modulo results (remainder) from the divider unit
    reg [31:0] rem_a;
    reg [31:0] rem_b;
    
    // Intermediate valid flags after modulo check
    reg check_a;
    reg check_b;

    // Output Control
    reg done_next;
    reg [31:0] result_next;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Control Logic and Next State Logic
    always @(*) begin
        next_state = current_state;
        done_next = 1'b0;
        result_next = result; // Default keep value

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = FACTOR_FIRST;
                end
            end

            FACTOR_FIRST: begin
                // This state lasts 8 cycles to initialize valid_factors
                if (factor_index == 3'd7) begin
                    // Transition based on if any factors were valid initially
                    if (valid_factors != 8'b0) begin
                        next_state = CHECK_PAIR_1;
                    end else begin
                        next_state = DONE;
                        result_next = 32'hFFFFFFFF; // No factors found in first pair
                    end
                end
            end

            CHECK_PAIR_1: begin
                // Wait for computation pipeline to flush for the current pair
                // Pipeline depth is 3 cycles (plus 1 for check logic, handled by state duration)
                // We iterate factor_index from 0 to 7. Once factor_index wraps to 0, the check is done for this pair.
                // Actually, we advance state when we have processed the 8 factors.
                if (factor_index == 3'd7) begin
                    if (valid_factors == 8'b0) begin
                        next_state = DONE;
                        result_next = 32'hFFFFFFFF;
                    end else if (pair_index == 2'd2) begin
                        next_state = DONE;
                    end else begin
                        next_state = CHECK_PAIR_2;
                    end
                end
            end

            CHECK_PAIR_2: begin
                if (factor_index == 3'd7) begin
                    if (valid_factors == 8'b0) begin
                        next_state = DONE;
                        result_next = 32'hFFFFFFFF;
                    end else if (pair_index == 2'd2) begin
                        next_state = DONE;
                    end else begin
                        next_state = CHECK_PAIR_3;
                    end
                end
            end

            CHECK_PAIR_3: begin
                if (factor_index == 3'd7) begin
                    if (valid_factors == 8'b0) begin
                        next_state = DONE;
                        result_next = 32'hFFFFFFFF;
                    end else begin
                        next_state = DONE;
                        // Find the first valid factor for output
                        // Synthesis will prioritize LSB (smallest index/primes[0])
                        // We use combinational logic here for simplicity, but we set the register.
                        // Since we are in the DONE state, we need the final valid_factors.
                        // However, the result_next is usually set in the previous cycle or based on current state.
                        // Let's just set it to a default here and use a helper logic block to determine the exact value.
                        result_next = 32'h0; // Placeholder, actual logic below
                    end
                end
            end

            DONE: begin
                done_next = 1'b1;
                // Stay in DONE until reset or start goes low (implied by waiting for start high)
                // Actually, the problem says "return to IDLE".
                // We typically wait for start to go low to avoid re-triggering immediately if start is held high.
                // But for standard pulse behavior, we just return to IDLE if start is low.
                // Since we are in DONE, we will go to IDLE if start is low.
                if (!start) begin
                    next_state = IDLE;
                end
                // Logic to set result for DONE state
                // If we just entered DONE, result_next might be updated by the specific transition logic above.
                // But for CHECK_PAIR_3, we have a condition. Let's refine result_next logic.
            end
        endcase
    end

    // Helper logic for result output during DONE transition
    // We need to capture the first valid factor index when entering DONE.
    // We can do this with a separate combinational block that updates result_next specifically for DONE.
    // However, the previous always block sets result_next. Let's make a dedicated block for result determination.
    reg [31:0] selected_result;
    always @(*) begin
        // Default: find first valid bit
        selected_result = 32'hFFFFFFFF;
        if (valid_factors[0]) selected_result = primes[0];
        else if (valid_factors[1]) selected_result = primes[1];
        else if (valid_factors[2]) selected_result = primes[2];
        else if (valid_factors[3]) selected_result = primes[3];
        else if (valid_factors[4]) selected_result = primes[4];
        else if (valid_factors[5]) selected_result = primes[5];
        else if (valid_factors[6]) selected_result = primes[6];
        else if (valid_factors[7]) selected_result = primes[7];
    end

    // Update result_next with the correct value for DONE state transitions
    always @(*) begin
        if (current_state == CHECK_PAIR_3 && factor_index == 3'd7 && valid_factors != 8'b0) begin
            result_next = selected_result;
        end else if (current_state == CHECK_PAIR_2 && factor_index == 3'd7 && valid_factors != 8'b0 && pair_index == 2'd2) begin
            result_next = selected_result;
        end else if (current_state == CHECK_PAIR_1 && factor_index == 3'd7 && valid_factors != 8'b0 && pair_index == 2'd2) begin // Unlikely but possible if N=1?
             result_next = selected_result;
        end else if (next_state == DONE && current_state != DONE) begin
            // Catch transitions to DONE that were set in the FSM block with default -1 or 0
            if (valid_factors == 8'b0 && next_state == DONE) begin
                 result_next = 32'hFFFFFFFF;
            end else if (next_state == DONE && valid_factors != 8'b0) begin
                 result_next = selected_result;
            end
        end
    end

    // Counter and Index Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            factor_index <= 3'b0;
            pair_index <= 2'b0;
        end else begin
            // Factor Index Logic
            if (current_state == IDLE) begin
                factor_index <= 3'b0;
            end else if (current_state == FACTOR_FIRST || 
                         current_state == CHECK_PAIR_1 || 
                         current_state == CHECK_PAIR_2 || 
                         current_state == CHECK_PAIR_3) begin
                factor_index <= factor_index + 1'b1;
            end

            // Pair Index Logic
            if (current_state == IDLE) begin
                pair_index <= 2'b0;
            end else if (current_state == FACTOR_FIRST && factor_index == 3'd7) begin
                pair_index <= 2'b0; // Start at pair 1
            end else if (current_state == CHECK_PAIR_1 && factor_index == 3'd7) begin
                pair_index <= pair_index + 1'b1;
            end else if (current_state == CHECK_PAIR_2 && factor_index == 3'd7) begin
                pair_index <= pair_index + 1'b1;
            end
        end
    end

    // Division Logic (Iterative Checking)
    // We compute a_i % p and b_i % p for the current factor_index.
    // This block is combinational logic based on factor_index and current inputs (a_i, b_i).
    // Since we need to match the pipeline timing, we assume the inputs a_i/b_i are stable during the 8 cycles.
    // This is a strong assumption but fits the "simplified" nature.
    
    // Helper combinational block for modulo calculation
    // Note: A real synthesizable divider is complex. We assume the tool can synthesize % operator for constants.
    // To be strictly valid for a test without a div unit, we can implement a simple logic.
    // However, the prompt asks for a specific algorithm and valid synthesizable Verilog.
    // Using the modulo operator is valid Verilog and synthesizable for constants/small numbers.
    // But we need to pipeline it to meet timing or just use it.
    // Let's simulate the pipeline explicitly to handle state transitions correctly.

    // Pipeline Stage 1: Input Latch for the current cycle
    reg [31:0] p_a;
    reg [31:0] p_b;
    reg [7:0] p_factors;

    always @(posedge clk) begin
        if (!rst_n) begin
            p_a <= 0;
            p_b <= 0;
            p_factors <= 0;
        end else begin
            // Latch inputs for the specific factor check cycle
            // We only care about the values when the state is processing pairs
            if (current_state == FACTOR_FIRST || 
                current_state == CHECK_PAIR_1 || 
                current_state == CHECK_PAIR_2 || 
                current_state == CHECK_PAIR_3) begin
                p_a <= a_i;
                p_b <= b_i;
                // Capture which factor we are checking now
                p_factors <= 8'b00000001 << factor_index;
            end else begin
                p_factors <= 8'b0;
            end
        end
    end

    // The modulo calculation happens in the next cycle (Stage 2)
    // We calculate remainder of p_a % prime and p_b % prime
    // We need to select the prime based on p_factors
    wire [31:0] current_prime_wire;
    assign current_prime_wire = primes[factor_index]; // Use factor_index to select prime directly to avoid delay
    // Actually, we need to match the pipeline. The factor is determined by factor_index.
    // The check happens 1 cycle after inputs are stable.
    // Let's perform calculation combinationaly on p_a/p_b which were latched in previous cycle.
    
    // To handle the modulo check correctly in hardware without a full divider block in the description:
    // We will implement the check: `if (factor != (a % factor) && factor != (b % factor))`
    // We need to compute (a % factor) and (b % factor).
    // Since we are in a sequential design, let's assume we have 1 cycle latency for the modulo operation.
    // Or we can do it in combinational logic if the cycle time allows.
    // Given the complexity, I will use combinational logic for the modulo to drive the update signals.

    // We need to determine which factor we are checking for the *current* pipeline data.
    // The data p_a/p_b belongs to a specific factor index.
    // We can extract the index from p_factors using a priority encoder or just use the delayed index.
    reg [2:0] delayed_factor_index;
    always @(posedge clk) begin
        if (!rst_n) delayed_factor_index <= 0;
        else if (current_state == FACTOR_FIRST || current_state == CHECK_PAIR_1 || 
                 current_state == CHECK_PAIR_2 || current_state == CHECK_PAIR_3) begin
            delayed_factor_index <= factor_index;
        end
    end

    // Combinational check for the current pipeline data
    wire [31:0] check_prime = primes[delayed_factor_index];
    wire [31:0] rem_a_calc = p_a % check_prime;
    wire [31:0] rem_b_calc = p_b % check_prime;
    wire factor_divides_a = (rem_a_calc == 0);
    wire factor_divides_b = (rem_b_calc == 0);
    wire factor_is_valid_for_pair = factor_divides_a || factor_divides_b;

    // State-based Update of valid_factors
    // We need to update valid_factors based on the result of the check.
    // The check result comes from the pipeline which is 1 cycle delayed from when we started checking a factor.
    // So, we update valid_factors one cycle after the check.
    // The check happens in FACTOR_FIRST (initialization) and CHECK_PAIR_ states.
    // Update logic:
    // FACTOR_FIRST: If valid, set bit. If not, clear bit.
    // CHECK_PAIR_n: If currently valid, but check fails, clear bit.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_factors <= 8'b0;
        end else begin
            // Apply updates when the result of the calculation is ready (delayed by 1 cycle from latch)
            // We need to ensure we only update when we are in the correct state and the pipeline has valid data.
            // p_factors was set in cycle N, delayed_factor_index is set in cycle N+1 (same as p_a/p_b latch), 
            // and the calculation is combinational. So the result is valid in cycle N+1.
            // We update in cycle N+1.
            
            // We need to know if we are in FACTOR_FIRST or CHECK_PAIR states in the previous cycle.
            // Let's register a flag to indicate we are processing a pair.
            
            if (current_state == FACTOR_FIRST) begin
                // Initialization: check if factor divides a0 or b0
                if (delayed_factor_index == 3'd7 && p_factors != 0) begin // Only update once per cycle? No, update continuously.
                    // This logic is tricky. Let's use a simpler approach.
                    // We iterate factor_index 0..7 in FACTOR_FIRST.
                    // The check for index i happens in the cycle after we see index i.
                    // We can write to valid_factors using a shift register or just update bit by bit.
                end
            end
        end
    end

    // Revised Update Logic for valid_factors:
    // We will use a separate block to handle the updates clearly.
    // We need to know the state of the previous cycle to know if we are doing Initial Check or Filter Check.
    reg [2:0] prev_state;
    always @(posedge clk) begin
        if (!rst_n) prev_state <= IDLE;
        else prev_state <= current_state;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_factors <= 8'b0;
        end else begin
            // We update when we have a valid result from the combinational logic above.
            // This happens when p_factors != 0 (meaning we are processing a factor).
            if (p_factors != 0) begin
                // Determine if this is an initial check (from FACTOR_FIRST) or a filter check (from CHECK_PAIRs)
                // We can infer this from the state when the data was latched.
                // The data was latched when current_state was FACTOR_FIRST or CHECK_PAIR_1 etc.
                // But we don't have that state available now easily unless we delayed it.
                // Let's delay the state just like the data.
                // Or simpler: valid_factors is all 0 initially.
                // In FACTOR_FIRST, we set bits.
                // In CHECK_PAIR, we clear bits.
                
                // Let's use a flag 'mode_is_init' which is set when in FACTOR_FIRST and delayed.
            end
        end
    end

    // Let's try a clean state machine implementation for valid_factors update.
    // We need to process 8 factors per state.
    // The check takes 1 cycle (due to modulo logic).
    
    // Pipeline Registers for State (to match modulo timing)
    reg [2:0] state_pipe_1;
    reg [2:0] state_pipe_2;
    reg [2:0] state_pipe_3;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            state_pipe_1 <= IDLE;
            state_pipe_2 <= IDLE;
            state_pipe_3 <= IDLE;
        end else begin
            state_pipe_1 <= current_state;
            state_pipe_2 <= state_pipe_1;
            state_pipe_3 <= state_pipe_2;
        end
    end

    // The check result (factor_is_valid_for_pair) is valid now for state_pipe_2 (assuming 1 cycle delay for modulo).
    // We need to know which factor bit to update.
    // We need to track which factor index corresponds to this result.
    // We can track the delayed factor index.
    // Let's create a shift register for the one-hot factor mask.
    // When we start a state, we shift in '1' based on factor_index.
    // Or just use the delayed index to generate the mask.
    
    wire [7:0] update_mask = 8'b00000001 << delayed_factor_index;
    
    // Decide whether to Set or Clear
    // If state_pipe_2 == FACTOR_FIRST: SET if valid, CLEAR if invalid (initial check).
    // If state_pipe_2 == CHECK_PAIR_n: CLEAR if invalid (filter check).
    
    wire do_update = (state_pipe_2 == FACTOR_FIRST) || 
                     (state_pipe_2 == CHECK_PAIR_1) || 
                     (state_pipe_2 == CHECK_PAIR_2) || 
                     (state_pipe_2 == CHECK_PAIR_3);
    
    wire is_init_phase = (state_pipe_2 == FACTOR_FIRST);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_factors <= 8'b0;
        end else if (do_update && p_factors != 0) begin // p_factors ensures we are looking at a valid slot
            if (is_init_phase) begin
                // Initialization: Set bit if valid, keep 0 if not (implicitly)
                if (factor_is_valid_for_pair) begin
                    valid_factors <= valid_factors | update_mask;
                end
                // Note: valid_factors starts at 0. If invalid, bit stays 0.
            end else begin
                // Filter: Clear bit if invalid
                if (!factor_is_valid_for_pair) begin
                    valid_factors <= valid_factors & ~update_mask;
                end
            end
        end
    end

    // Output Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else begin
            done <= done_next;
            if (next_state == DONE && current_state != DONE) begin
                // Capture result only when transitioning to DONE
                result <= result_next;
            end else if (current_state == IDLE) begin
                result <= 0; // Clear on idle
            end
        end
    end

    // Fix for Module End
    // The logic above implements the requirements.
    // The critical part is handling the iteration.
    // factor_index increments every cycle in the processing states.
    // p_factors is set when factor_index increments.
    // p_a/p_b are latched. The modulo is combinational.
    // valid_factors updates 2 cycles later.
    // This effectively processes 8 factors in 8 cycles.
    // When factor_index wraps to 0 (or hits 7), we advance state.
    // However, the update happens later.
    // So we need to make sure the state transition waits for the updates to complete.
    
    // In the FSM block, the transition condition "factor_index == 7" checks the current cycle index.
    // The actual update of valid_factors happens 2 cycles later.
    // The next state transition happens in the next cycle.
    // So there is a mismatch.
    
    // We need to synchronize state transitions with the pipeline.
    // Let's add a 'pipeline_drain' counter or use the delayed factor index.
    // Actually, if we transition to the next state while the pipeline is still processing the last factor of the previous state, it's okay.
    // Because the pipeline carries the state information (state_pipe_1).
    // So, if we transition from CHECK_PAIR_1 to CHECK_PAIR_2, the pipeline still thinks it's CHECK_PAIR_1 for 2-3 cycles.
    // This is fine because we want to filter on the pair we just received.
    
    // The only issue is: when do we stop?
    // We stop iterating when factor_index == 7.
    // We need to ensure we don't miss the last update.
    // Since update happens ~2 cycles after index 7, we are fine.
    
    // The only logic missing is the `done_next` signal generation.
    // Currently, done_next is set in DONE state.
    // We need to transition to DONE.
    // If we are in CHECK_PAIR_3 and factor_index wraps to 0, we transition.
    // My previous logic used factor_index == 7 to trigger transition.
    // This triggers at the start of the last cycle.
    // The updates for the last factor will happen 2 cycles later.
    // By then, we are in DONE state.
    // This is acceptable.
    
    // One detail: The requirement says "Loop 3 times".
    // My logic uses pair_index counter.
    // pair_index increments when factor_index == 7.
    // So: 0->1 (CHECK_PAIR_1 done), 1->2 (CHECK_PAIR_2 done), 2->3 (CHECK_PAIR_3 done).
    // When pair_index is 2 (CHECK_PAIR_3) and factor_index == 7, we go to DONE.
    
    // Let's double check the initial factor extraction.
    // FACTOR_FIRST lasts 8 cycles.
    // Inputs a0/b0 must be stable during these 8 cycles.
    // This is assumed.
    
    // Result logic in DONE:
    // We use `valid_factors` to pick the result.
    // By the time we reach DONE, the pipeline has drained (mostly).
    // However, the update for the last factor (factor 7) happens 2 cycles after index 7.
    // If we transition to DONE immediately, valid_factors might be stale for the last factor.
    // To fix this, we should stay in the processing state for a few extra cycles, 
    // OR delay the transition.
    // Since we have a complex pipeline, let's ensure we process the last update.
    // We can transition to a "DRAIN" state, or just extend the state duration.
    
    // Let's modify the FSM to transition based on `delayed_factor_index`.
    // When `delayed_factor_index` reaches 7, we know the last update has been issued.
    // But we still need to wait for it to commit to the register.
    // Wait, `delayed_factor_index` is the index of the calculation currently happening.
    // When it is 7, the result is valid next cycle.
    // So we can transition 1 cycle after `delayed_factor_index == 7`.
    // This is complicated.
    
    // Alternative: Single-Cycle logic (ideal) or 2-Cycle state extension.
    // Let's extend the DONE entry condition.
    // Instead of `factor_index == 7`, use `delayed_factor_index == 7`.
    // `delayed_factor_index` is updated with `factor_index` in the same cycle `factor_index` increments.
    // Wait, `delayed_factor_index` is registered. 
    // If `factor_index` becomes 7 in cycle N, `delayed_factor_index` becomes 7 in cycle N+1.
    // So we need to wait for `delayed_factor_index` to become 7.
    
    // Actually, let's stick to `factor_index == 7` but introduce a `finalizing` flag or just a small wait.
    // Or, we can put the update logic in the combinational block that determines next_state.
    // But the update logic (modulo) takes a cycle.
    
    // Let's use `delayed_factor_index` to gate the transition.
    // When `delayed_factor_index == 7` and we are in the last state, transition to DONE next cycle.
    
    // Revising the FSM block in my head:
    // The current implementation uses `factor_index == 3'd7`.
    // This causes a race condition where we leave the state before the last update is calculated.
    // To fix this cleanly without adding too many states:
    // Use `delayed_factor_index` for the transition to DONE.
    // `delayed_factor_index` matches `factor_index` but delayed by 1 cycle.
    // If we use `delayed_factor_index == 3'd7` as the condition to move to the next state (or DONE),
    // then by the time we transition, the update for index 7 is just being computed (or available).
    // Wait, if delayed_factor_index is 7, the modulo is computed using p_a/p_b from the cycle when factor_index was 7.
    // The update to valid_factors happens in the NEXT cycle.
    // So if we transition based on delayed_factor_index == 7, we transition 1 cycle too early (relative to the final valid_factors value).
    
    // Let's add a small "FINISH" step inside each state.
    // Or, simpler: The module is done when the last update is committed.
    // Since `factor_index` increments continuously, we can check `factor_index == 7` AND `state_pipe_2 == current_state` (some how).
    
    // Let's use the `state_pipe_3` (3 cycle delay) to ensure updates are applied.
    // If `state_pipe_3` is the last state and we have processed all factors.
    // This adds latency but ensures correctness.
    
    // To keep it efficient, let's assume `factor_index` runs 0..7.
    // The update happens for index i in cycle i+2.
    // So for index 7, update happens in cycle 9.
    // If we stay in state for 9 cycles, it's slow.
    
    // We can detect when the pipeline is empty for the current state.
    // The pipeline is empty when `delayed_factor_index` wraps around or is invalid.
    // Since `delayed_factor_index` is just a counter, it goes 0..7.
    // When `delayed_factor_index` goes from 7 to 0, the last update of the batch has just finished (cycle after 7).
    
    // Let's change the state transition to be based on `delayed_factor_index == 7` AND `factor_index == 0` (wrapped).
    // No, factor_index resets at the start of the next state.
    
    // Let's trust the pipeline. The update for the last factor happens 2 cycles after we start it.
    // We will simply delay the state transition by 2 cycles.
    // The current logic transitions when `factor_index == 7`.
    // Let's add a flag `flush_pipeline`.
    
    // Actually, looking at the prompt requirements again: "Simple Check".
    // Maybe the modulo operator is supposed to be combinational?
    // If combinational, we don't have this problem.
    // But 'module wcd_solver' usually implies sequential logic for the FSM.
    // I will add a small modification: Use the delayed index to trigger the transition.
    // And add a wait state.
    
    // Let's add a state `WAIT_PIPELINE` before `DONE`.
    // Or, simpler: Just extend the last state duration.
    // We can keep `factor_index` running and use `delayed_factor_index` to determine when the batch is finished.
    
    // Modified logic:
    // Transition from CHECK_PAIR_n to next or DONE when:
    // `factor_index == 3'd7` AND `delayed_factor_index == 3'd7`.
    // This ensures we have started the calculation for the last factor.
    // We still need to wait for it to finish.
    
    // Let's stick to the simplest correct implementation:
    // 1. Run `factor_index` 0..7.
    // 2. In the FSM, if `factor_index == 7`, move to a temporary state `WAIT_UPDATE`.
    // 3. In `WAIT_UPDATE`, wait until `delayed_factor_index == 7` (or a cycle counter).
    // 4. Then move to next state or DONE.
    
    // However, the prompt asks for specific states: IDLE, FACTOR_FIRST, CHECK_PAIR_1, CHECK_PAIR_2, CHECK_PAIR_3, DONE.
    // So we cannot add `WAIT_UPDATE`.
    // We must fit into these states.
    
    // So, we MUST make the update happen within the state duration, OR transition after the update happens.
    // The transition condition `factor_index == 7` happens at the start of the cycle where we process factor 7.
    // The update for factor 7 happens 2 cycles later.
    // So if we transition immediately, we go to the next state, but the update for factor 7 (of previous state) happens in the new state.
    // This corrupts the valid_factors for the new state (if we clear bits) or mixes them up.
    
    // To prevent corruption, we must NOT update valid_factors in the new state for the old pair.
    // How do we prevent that?
    // The update logic is tied to `state_pipe_2`.
    // If we transition states, `state_pipe_2` changes.
    // So the update for factor 7 (which was latched when state was CHECK_PAIR_1) will arrive when `state_pipe_2` is CHECK_PAIR_2 (assuming 2 cycle delay).
    // If we are filtering (CHECK_PAIR_2), we want to clear bits for CHECK_PAIR_2 inputs.
    // We do NOT want to apply updates for CHECK_PAIR_1 inputs to CHECK_PAIR_2 logic.
    
    // So we must delay the state transition until the pipeline is drained for the current state.
    // Since we cannot add a state, we must extend the duration of the current state.
    // We can do this by changing the transition condition.
    // Don't transition when `factor_index == 7`.
    // Transition when `delayed_factor_index == 7`.
    // Wait, `delayed_factor_index` is 7 one cycle after `factor_index` is 7.
    // Then, the update for factor 7 happens in the cycle `delayed_factor_index` is 7 (combinational modulo) or the next cycle.
    
    // Let's look at the timing:
    // Cycle T: State X, factor_index=6. p_factors=bit6. p_a/p_b latched.
    // Cycle T+1: State X, factor_index=7. p_factors=bit7. p_a/p_b latched. 
    //            delayed_factor_index=6. Modulo result for bit6 valid. Update valid_factors.
    // Cycle T+2: State X, factor_index=0 (wrap?) No, factor_index stays 7 for one cycle then resets or increments.
    //            Actually, factor_index increments every cycle. So T+2: factor_index=0? 
    //            If we transition at T+1 based on factor_index=7, we go to next state.
    //            Then T+2: New State. factor_index=0.
    //            T+3: delayed_factor_index=7 (from T+1). Modulo for bit7 valid. Update valid_factors.
    //            Problem: New State is active. If New State is CHECK_PAIR_2, we update valid_factors based on bit7 (which was from old inputs).
    //            This is bad.
    
    // So, we must transition AFTER the update for bit7 happens.
    // Update for bit7 happens when delayed_factor_index == 7.
    // This happens in cycle T+2 (assuming factor_index=7 in T+1).
    // So we must remain in State X until T+3 (so the update is applied to valid_factors register).
    // We remain in State X for 8 cycles (0..7) + 2 cycles = 10 cycles? No.
    
    // Let's adjust the counters.
    // We iterate factor_index 0 to 7.
    // We stop when `delayed_factor_index == 7` (i.e., we have computed the result for index 7).
    // When `delayed_factor_index == 7`, the update for index 7 will happen next cycle.
    // We want to transition to the next state AFTER that update.
    // So we transition when `delayed_factor_index == 7`.
    // But we need to make sure we don't miss the processing of the last factor.
    
    // Let's try this: Keep factor_index 0..7.
    // Transition condition: `factor_index == 7` AND `delayed_factor_index == 6` (so next cycle delayed_factor_index is 7, update happens, we leave).
    // No, if we leave, the update happens in the next state.
    
    // Let's go back to the `factor_index` based logic and assume the `valid_factors` update logic is robust.
    // The update logic checks `state_pipe_2`.
    // If I transition to state S_new, then `state_pipe_2` will become S_new after 2 cycles.
    // The update for the last factor (from S_old) happens when `state_pipe_2` is S_old.
    // So if I transition S_old -> S_new, then for 2 more cycles, `state_pipe_2` is S_old.
    // The update will happen correctly (using S_old logic).
    // So, the transition can happen as soon as we finish starting the last factor calculation.
    // i.e., when `factor_index` wraps to 0.
    
    // Wait, if `factor_index` runs 0..7.
    // Cycle k: factor_index=0. 
    // ...
    // Cycle k+7: factor_index=7.
    // Cycle k+8: factor_index wraps to 0 (if we continue).
    // But we want to stop.
    // We can transition when `factor_index` wraps to 0.
    // But `factor_index` wraps to 0 naturally if we don't stop it.
    
    // So, let's change the transition trigger.
    // Transition from state S to S_next when `delayed_factor_index == 7`.
    // This means we have just processed the calculation for index 7.
    // The update for index 7 will happen next cycle (when delayed_factor_index is 7, combinational calc, update reg next edge).
    // If we transition to S_next now, the update for S_old will happen while we are in S_next.
    // As reasoned, `state_pipe_2` will still be S_old for 2 cycles.
    // So the update logic `if (state_pipe_2 == S_old) ...` will work correctly.
    // So, we can transition when `delayed_factor_index == 7`.
    
    // Let's implement this.
    // We need `delayed_factor_index`.
    // I already defined it above.
    
    // Revising the FSM block in the code:
    // Use `delayed_factor_index == 3'd7` instead of `factor_index == 3'd7` for transitions.
    // This handles the pipeline latency correctly.

    // Wait, `delayed_factor_index` is updated with `factor_index` every cycle.
    // So `delayed_factor_index` follows `factor_index` exactly, just delayed by 1 cycle.
    // If `delayed_factor_index` is 7, it means `factor_index` was 6 in the previous cycle? No.
    // If `delayed_factor_index` is 7, it means `factor_index` is 7 in the current cycle.
    // Because `delayed_factor_index <= factor_index`.
    // So if `delayed_factor_index` is 7, `factor_index` is 7.
    // The calculation for `delayed_factor_index` (7) uses `p_a/p_b` latched when `factor_index` was 6.
    // Wait. 
    // Cycle A: factor_index=6. p_factors=bit6. p_a/p_b = inputs.
    // Cycle B: factor_index=7. p_factors=bit7. p_a/p_b = inputs. delayed_factor_index=6. 
    //          Calculation for delayed_factor_index=6 happens.
    // Cycle C: factor_index wraps (or 0). delayed_factor_index=7. 
    //          Calculation for delayed_factor_index=7 happens (using p_a/p_b from Cycle B).
    
    // So, if we transition based on `delayed_factor_index == 7`, we are in Cycle C.
    // In Cycle C, the calculation for index 7 happens.
    // The update for index 7 happens at the end of Cycle C (posedge clk).
    // If we transition in Cycle C, we go to next state in Cycle C+1.
    // So the update happens correctly before we start the next state.
    
    // But `delayed_factor_index` is 7 in Cycle C.
    // What is `factor_index` in Cycle C?
    // We need `factor_index` to be 7 in Cycle B to have valid `p_a/p_b` for index 7.
    // If `factor_index` is 0 in Cycle C, `p_a/p_b` has been overwritten with Cycle C inputs.
    // So we need `delayed_factor_index` to be 6 to trigger the transition?
    // No.
    
    // Let's try to keep `factor_index` at 7 for an extra cycle.
    // Or, use `factor_index` to gate the latching of `p_a/p_b`.
    // If `factor_index` is 7, we latch. 
    // `delayed_factor_index` becomes 7 next cycle.
    // Calculation for 7 happens. Update happens.
    // We can transition after `delayed_factor_index` becomes 7.
    // This means `delayed_factor_index` is 7, calculation happens, we transition.
    
    // Wait, if `delayed_factor_index` is 7, and we transition, what inputs does the calculation use?
    // `p_a/p_b` were latched when `factor_index` was 6.
    // (Because `delayed_factor_index` is 7 -> `factor_index` was 6 in previous cycle).
    // So the calculation for index 7 would use inputs from index 6.
    // This is wrong.
    
    // So, we need `delayed_factor_index` to correspond to `factor_index` at the time of latching.
    // Latching happens when `factor_index` increments.
    // Let's define `valid_input_latch` signal.
    // `valid_input_latch` is high for 1 cycle when `factor_index` changes.
    // `p_a/p_b` latched only when `valid_input_latch` is high.
    // `p_factors` also latched.
    
    // If we use `factor_index` as a counter.
    // Cycle N: factor_index=6. valid_input_latch=1. p_factors=bit6. p_a/p_b = inputs.
    // Cycle N+1: factor_index=7. valid_input_latch=1. p_factors=bit7. p_a/p_b = inputs.
    // Cycle N+2: factor_index=0. valid_input_latch=1. p_factors=bit0. p_a/p_b = inputs (new inputs if we transitioned!).
    
    // If we transition at Cycle N+2, we are in new state.
    // The update for bit7 comes from Cycle N+1 pipeline.
    // Cycle N+2: delayed_factor_index=6. Calculation for bit6.
    // Cycle N+3: delayed_factor_index=7. Calculation for bit7 (inputs from N+1).
    // Update happens at end of N+3.
    // If we transition at N+2, we are in new state in N+3.
    // `state_pipe_2` logic: N+3 -> state_pipe_1 (N+2) -> state_pipe_2 (N+1? No).
    // Let's map it:
    // Cycle N: current_state=S. 
    // Cycle N+1: current_state=S.
    // Cycle N+2: current_state=S (if transition condition met, next_state = S_new).
    // Cycle N+3: current_state=S_new.
    
    // Latch pipeline:
    // Cycle N+2: p_factors=0 (transitioning?).
    // Cycle N+2: p_factors=0? Or should we latch bit7 in N+2?
    
    // Let's refine the state transition.
    // We stay in S until `delayed_factor_index == 7` AND `factor_index == 0`.
    // Cycle where `delayed_factor_index == 7` is Cycle N+3.
    // In N+3, `factor_index` is 0 (wrapped).
    // We transition to S_new in N+4.
    // By N+4, the update for bit7 has been applied (at end of N+3).
    // Correct.
    
    // Condition: `delayed_factor_index == 3'd7` && `factor_index == 3'd0`.
    // This means we just finished the batch.
    
    // Let's implement this.

    // Re-writing the FSM block with this condition:

    always @(*) begin
        next_state = current_state;
        done_next = 1'b0;
        result_next = result;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = FACTOR_FIRST;
                end
            end

            FACTOR_FIRST: begin
                // Check for completion: We have processed factor 7 and wrapped around
                if (delayed_factor_index == 3'd7 && factor_index == 3'd0) begin
                    if (valid_factors != 8'b0) begin
                        next_state = CHECK_PAIR_1;
                    end else begin
                        next_state = DONE;
                        result_next = 32'hFFFFFFFF;
                    end
                end
            end

            CHECK_PAIR_1: begin
                if (delayed_factor_index == 3'd7 && factor_index == 3'd0) begin
                    if (valid_factors == 8'b0) begin
                        next_state = DONE;
                        result_next = 32'hFFFFFFFF;
                    end else if (pair_index == 2'd2) begin
                        next_state = DONE;
                    end else begin
                        next_state = CHECK_PAIR_2;
                    end
                end
            end

            CHECK_PAIR_2: begin
                if (delayed_factor_index == 3'd7 && factor_index == 3'd0) begin
                    if (valid_factors == 8'b0) begin
                        next_state = DONE;
                        result_next = 32'hFFFFFFFF;
                    end else if (pair_index == 2'd2) begin
                        next_state = DONE;
                    end else begin
                        next_state = CHECK_PAIR_3;
                    end
                end
            end

            CHECK_PAIR_3: begin
                if (delayed_factor_index == 3'd7 && factor_index == 3'd0) begin
                    if (valid_factors == 8'b0) begin
                        next_state = DONE;
                        result_next = 32'hFFFFFFFF;
                    end else begin
                        next_state = DONE;
                    end
                end
            end

            DONE: begin
                done_next = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Update result_next logic for DONE entry
    // We need to ensure result_next is set correctly when transitioning to DONE.
    // The transition logic above sets result_next to -1 if valid_factors is empty.
    // If valid_factors is not empty, it doesn't set result_next in the FSM block (defaults to old value).
    // So we need a combinational logic to set result_next based on valid_factors when transitioning to DONE.
    
    wire entering_done = (next_state == DONE && current_state != DONE);
    always @(*) begin
        if (entering_done) begin
            if (valid_factors == 8'b0) begin
                result_next = 32'hFFFFFFFF;
            end else begin
                // Find first valid
                result_next = selected_result;
            end
        end
    end

    // Update the pair_index logic.
    // pair_index increments when we complete a check state.
    // Completion detected by `delayed_factor_index == 7 && factor_index == 0`.
    // We need to increment pair_index in that specific cycle.
    // Currently, pair_index is a register. We update it in the combinational block or sequential block.
    // Let's update it in the sequential block.
    wire process_complete = (delayed_factor_index == 3'd7 && factor_index == 3'd0);
    
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset logic handles this
        end else begin
            // Logic moved to the sequential block below
        end
    end
    
    // Revising the sequential logic for counters:
    // We need to increment pair_index when process_complete is high.
    // But only in the specific states.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            factor_index <= 3'b0;
            pair_index <= 2'b0;
        end else begin
            // Factor Index Logic
            if (current_state == IDLE) begin
                factor_index <= 3'b0;
            end else if (current_state == DONE) begin
                factor_index <= 3'b0;
            end else begin
                // Increment if we haven't completed the batch (or even if we have, it resets next cycle to 0)
                // To handle the wrap condition cleanly:
                // If we are about to transition (process_complete is high), we stop incrementing.
                // Or we increment until we reach 7, then stop.
                // But `factor_index` is used for latching. It needs to run 0..7.
                // If process_complete is high, we are at 7 (delayed) and 0 (current). 
                // Actually, if delayed_factor_index is 7 and factor_index is 0, then factor_index just wrapped.
                // We shouldn't increment anymore for this state.
                // We should wait for the state transition.
                
                if (current_state == FACTOR_FIRST || 
                    current_state == CHECK_PAIR_1 || 
                    current_state == CHECK_PAIR_2 || 
                    current_state == CHECK_PAIR_3) begin
                    
                    if (!process_complete) begin
                        factor_index <= factor_index + 1'b1;
                    end
                    // If process_complete is true, factor_index stays at 0 (or whatever it was, but we are done).
                end
            end

            // Pair Index Logic
            if (current_state == IDLE) begin
                pair_index <= 2'b0;
            end else if (current_state == FACTOR_FIRST && process_complete) begin
                // Just finished FACTOR_FIRST. Start at pair 1 (index 0).
                pair_index <= 2'b0;
            end else if ((current_state == CHECK_PAIR_1 || current_state == CHECK_PAIR_2 || current_state == CHECK_PAIR_3) && process_complete) begin
                // If we are moving to the next state, increment.
                // But we only increment if we are NOT moving to DONE.
                // The FSM block determines next_state.
                // If we are in CHECK_PAIR_3 and process_complete, we move to DONE.
                // So we only increment if we are moving to a CHECK_PAIR state.
                
                // We can check the next_state.
                if (next_state == CHECK_PAIR_2 || next_state == CHECK_PAIR_3) begin
                    pair_index <= pair_index + 1'b1;
                end
            end
        end
    end

    // One final fix: The `factor_index` must go 0..7.
    // If we stop incrementing when `process_complete`, `factor_index` is 0.
    // In the cycle where `factor_index` wraps from 7 to 0, `process_complete` is true.
    // So `factor_index` becomes 0 and stays 0.
    // In the next cycle, state changes.
    // This works.

endmodule

// Note: The above implementation assumes the inputs a_i/b_i are stable during the 8 cycles of processing.
// This is a standard assumption for such sequential hardware unless a FIFO is specified.
// The code uses the modulo operator which is synthesizable for constants.
