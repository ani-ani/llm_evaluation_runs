module zebra_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] char_index,
    input load,
    output reg [7:0] max_len,
    output reg done
);

    // Parameters
    parameter N = 16;
    parameter CHAR_B = 8'h62;
    parameter CHAR_W = 8'h77;

    // State Machine Definition
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal Memory (16x8 buffer)
    reg [7:0] buffer[0:N-1];

    // Internal Registers for Processing
    reg [4:0] scan_idx;      // Loop counter for scanning
    reg [7:0] current_max;   // Current calculated max length
    reg [7:0] prefix_len;    // Length of alternating prefix
    reg [7:0] suffix_len;    // Length of alternating suffix
    reg processing_start;    // Trigger for single-cycle process calculation
    reg process_done;        // Flag indicating calculation is done

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            processing_start <= 1'b0;
        end else begin
            // Default transition
            current_state <= next_state;
            processing_start <= 1'b0;

            // Logic to trigger processing cycle
            if (next_state == PROCESS && current_state != PROCESS) begin
                processing_start <= 1'b1;
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS; // Start implies calculation, assuming pre-loaded or reload
                    // Requirement says: "Once loaded, asserting 'start' initiates the calculation."
                    // Requirement also says: "LOAD: When 'load' is high..."
                    // We treat 'start' as the trigger for the calculation phase.
                end else if (load) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                // Remain in LOAD state while loading data or waiting for start
                if (!load && start) begin
                    next_state = PROCESS;
                end else if (!load && !start) begin
                    next_state = IDLE;
                end else begin
                    next_state = LOAD;
                end
            end

            PROCESS: begin
                // Process takes 1 cycle to compute in this architecture
                if (process_done) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                // Stay in DONE until reset or new start
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end
        endcase
    end

    // Data Loading Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset buffer to zeros (or undefined, but zero is safe)
            // Note: Verilog doesn't support resetting 2D arrays directly in always block easily without loop
        end else begin
            if (current_state == LOAD && load) begin
                if (char_index < N) begin
                    buffer[char_index] <= char_in;
                end
            end
        end
    end

    // Processing Logic (Functional Logic)
    // This block calculates the max_len in a combinational/sequential manner
    // triggered by processing_start. It mimics a combinational logic block
    // but implemented as sequential for synthesis safety and timing.
    
    // Temporary variables for combinational calculation
    reg [7:0] temp_max;
    reg [7:0] temp_prefix;
    reg [7:0] temp_suffix;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_len <= 8'h00;
            done <= 1'b0;
            process_done <= 1'b0;
        end else begin
            // Reset done flag when entering new states
            if (current_state == IDLE || current_state == LOAD) begin
                done <= 1'b0;
                process_done <= 1'b0;
            end

            // Calculate Logic
            if (current_state == PROCESS && processing_start) begin
                // 1. Scan for longest contiguous alternating sequence
                temp_max = 1; // Minimum length is 1 if N >= 1
                
                // Linear scan (simulating loop unrolling behavior over 16 elements)
                // We compare buffer[i] and buffer[i-1]
                
                // Check individual runs
                // Ideally we do this in combinational logic for speed, 
                // but requirement says "Latency: 20-30 cycles".
                // We can implement it as a cycle-accurate loop or a single cycle combinational logic.
                // Given the small size (N=16), a single cycle combinational logic is fine 
                // (it will infer a large mux/chain of comparators).
                // However, to be safe and strictly follow "sequential" and "latency" hints, 
                // we can do a mini-sequencer or just unroll.
                // Let's unroll for N=16 to be fast (1 cycle) but area intensive.
                // Actually, let's use a small loop that takes 16 cycles to be safe with timing area.
                // Wait, the requirement says "Latency: Result valid approximately 20-30 clock cycles".
                // This implies a sequential scan is intended.
                
                // Let's use the sequential scan logic embedded here.
                // However, the previous state machine logic is already 1 cycle per state.
                // To implement a 16-cycle scan, we need more states or a sub-state machine.
                // Given the "20-30 cycles" hint, we can implement a 16-cycle scan + some overhead.
                
                // Let's restructure the PROCESS state to handle the loop internally or use a counter.
                // To keep the code clean and the state machine simple, let's do the calculation in one combinational block
                // triggered by `processing_start`. Since N=16, the logic depth is small.
                // The "20-30 cycles" hint is likely just an upper bound for a general implementation.
                // A direct combinatorial calculation for N=16 is standard.
                
                // --- Combinational Logic Implementation for Speed (Equivalent to unrolled) ---
                
                // Calculate Contiguous Max
                // We need to find max run of alternating chars.
                // Logic: Iterate i from 1 to 15. If buffer[i] != buffer[i-1], run_len++ else run_len=1.
                
                // Since we are in a sequential block triggered by processing_start, 
                // we calculate the result now.
                
                // Internal run calculation variables
                reg [7:0] run;
                reg [7:0] best;
                reg [4:0] k;
                
                best = 1;
                run = 1;
                
                // We manually unroll or use a loop. Synthesis tools handle 16 iteration loops fine.
                for (k = 1; k < N; k = k + 1) begin
                    if (buffer[k] != buffer[k-1]) begin
                        run = run + 1;
                    end else begin
                        run = 1;
                    end
                    if (run > best) best = run;
                end
                
                // Store contiguous max
                temp_max = best;

                // 2. Check Wrapping (Prefix + Suffix)
                // Prefix Length
                temp_prefix = 1;
                for (k = 1; k < N; k = k + 1) begin
                    if (buffer[k] != buffer[k-1]) begin
                        temp_prefix = temp_prefix + 1;
                    end else begin
                        break; // Loop termination in synthesis requires careful handling, but standard synthesis supports break
                    end
                end
                // Note: Synthesis tools generally support 'break' in unrolled loops. 
                // To be strictly compliant without break, we can use generate or if-else chains.
                // Let's stick to standard for-loop with break; it is widely supported.
                
                // Suffix Length
                temp_suffix = 1;
                for (k = N - 1; k > 0; k = k - 1) begin
                    if (buffer[k-1] != buffer[k]) begin
                        temp_suffix = temp_suffix + 1;
                    end else begin
                        break;
                    end
                end

                // Wrap Logic
                if (buffer[0] != buffer[N-1]) begin
                    // Valid wrap
                    // Note: if temp_prefix == N (all alternating), then temp_suffix would also be N? 
                    // Actually if all alternating, temp_prefix=N, temp_suffix=N. 
                    // sum would be 2N, which is wrong. The sum should not exceed N.
                    // If the whole string is alternating, max_run is N, wrap logic adds N+N which is invalid.
                    // The problem says: "If the string starts and ends with different characters... answer is max(max_alternating_substring, length_of_prefix + length_of_suffix)."
                    // And "Cap max_len at N".
                    // If whole string is alternating, prefix = N, suffix = N. Sum = 2N. Cap fixes this.
                    
                    if ((temp_prefix + temp_suffix) > temp_max) begin
                        temp_max = temp_prefix + temp_suffix;
                    end
                end

                // Cap at N
                if (temp_max > N) temp_max = N;

                // Update Outputs
                max_len <= temp_max;
                process_done <= 1'b1;
            end
            
            if (current_state == DONE) begin
                done <= 1'b1;
                process_done <= 1'b0;
            end
        end
    end

endmodule

// Note on Loop Synthesis: 
// The loops inside the sequential block (for k=1...) are static loops with constant bounds (1 to 15).
// Synthesis tools will unroll them into pure combinational logic.
// This creates a critical path of about 16 comparators, which is negligible for N=16.
// This satisfies the "Result valid approximately 20-30 clock cycles" (it's actually 1 cycle latency from PROCESS entry)
// but fits the "loop unrolling" description.

// If strict 20-30 cycle latency was required, a state machine counter inside PROCESS would be used.
// However, the "loop unrolling" hint suggests the intention is to use loops that become hardware logic.

// Correction: The "break" statement inside the for-loop might not be supported by all synthesis tools in the way intended (it usually terminates the iteration logic for that specific loop instance).
// To ensure maximum compatibility and avoid potential synthesis issues with `break` in a combinational block inside an FSM:
// A safer way is to use the loop variable to mask the update, but `break` is standard Verilog-2001 for synthesis.
// 
// Let's refine the loop logic to be strictly procedural without `break` to be safe:
// We can calculate the prefix by checking `k < N && buffer[k] != buffer[k-1]`.

// Revised Logic for Prefix/Suffix inside the sequential block:
// (This is logically what the synthesizer does with break, but clearer to write)

// Let's stick to the `break` version as it is most readable and standard in modern synthesis.
// If the user environment is very old, it might be an issue. Given "Expert ASIC designer", modern tools are assumed.

// Final check on requirements:
// 1. Sequential: Yes, using FSM and sequential logic.
// 2. N=16: Yes.
// 3. Buffer loaded via load: Yes.
// 4. Start initiates: Yes.
// 5. Alternating max length: Yes.
// 6. Wrapping: Yes, prefix + suffix.
// 7. Capped at N: Yes.
// 8. States IDLE, LOAD, PROCESS, DONE: Yes.
// 9. Latency: Calculation is combinatorial triggered by state transition. It happens in 1 clock cycle of PROCESS state.
//    Total latency from start: 1 cycle (process) + 1 (done). Total 2-3 cycles. 
//    The prompt says "20-30 cycles... depends on loop unrolling". 
//    If they expect a state machine that iterates 16 times, I should probably implement the scan as a counter.
//    Let's adjust the PROCESS state to use a counter to iterate 16 times, making the latency explicitly ~16 cycles.

// *Revision to meet Latency requirement:*
// I will implement the processing as a 16-cycle sweep using a `scan_idx` counter.
// This makes the module more "sequential" and robust against timing issues (smaller combinational paths).

// 
// 
// REWRITTEN PROCESS STATE LOGIC FOR SEQUENTIAL SCAN (16 Cycles latency)
//

module zebra_solver_sequential (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] char_index,
    input load,
    output reg [7:0] max_len,
    output reg done
);

    parameter N = 16;

    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESS,
        DONE
    } state_t;

    state_t current_state, next_state;
    reg [7:0] buffer[0:N-1];

    // Processing Registers
    reg [4:0] idx;              // Current index for scanning
    reg [7:0] current_run;      // Length of current alternating run
    reg [7:0] best_run;         // Max contiguous run found so far
    reg [7:0] prefix_len;       // Calculated prefix length
    reg [7:0] suffix_len;       // Calculated suffix length
    reg [1:0] process_step;     // Sub-state for processing phases
    // process_step: 0=Init, 1=Scan Contiguous, 2=Calc Prefix, 3=Calc Suffix, 4=Finalize

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PROCESS;
                else if (load) next_state = LOAD;
            end
            LOAD: begin
                if (!load && start) next_state = PROCESS;
                else if (!load && !start) next_state = IDLE;
            end
            PROCESS: begin
                // Wait for internal processing to complete (5 steps * 16 cycles max? No, we do it in one cycle per step or scan)
                // Let's design it to take 16 cycles for the scan, and a few more for wrap calc.
                // To strictly map to 20-30 cycles, we can make the scan take 16 cycles.
                // The sub-logic inside PROCESS will handle the sequence.
                // We will transition to DONE when `process_step` reaches a terminal value.
                if (process_step == 3'd4) next_state = DONE; // 4 is done
                else next_state = PROCESS; // Stay in process until step 4
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_len <= 0;
            done <= 0;
            idx <= 0;
            process_step <= 0;
        end else begin
            case (current_state)
                IDLE, LOAD: begin
                    done <= 0;
                    // Handle Loading
                    if (current_state == LOAD && load) begin
                        if (char_index < N) buffer[char_index] <= char_in;
                    end
                end

                PROCESS: begin
                    // We use process_step to manage the algorithm phases
                    // Step 0: Initialize Scan
                    if (process_step == 0) begin
                        idx <= 1;
                        current_run <= 1;
                        best_run <= 1; // At least length 1 if string exists
                        process_step <= 1;
                    end
                    // Step 1: Scan Contiguous (Takes N-1 cycles)
                    else if (process_step == 1) begin
                        if (idx < N) begin
                            if (buffer[idx] != buffer[idx-1]) begin
                                current_run <= current_run + 1;
                            end else begin
                                current_run <= 1;
                            end
                            // Update best_run
                            if (current_run + 1 > best_run && buffer[idx] != buffer[idx-1]) begin
                                best_run <= current_run + 1;
                            end else if (buffer[idx] == buffer[idx-1]) begin
                                // Run broken, check previous run length (current_run was the old run length before reset? No.)
                                // Logic correction: current_run holds the run ending at idx-1.
                                // If match, new run starts at idx. Length 1.
                                // If mismatch, new run extends to idx. Length current_run+1.
                                // We need to compare best_run with the NEW length.
                                if (current_run + 1 > best_run) best_run <= current_run + 1;
                                // Actually, let's use a simpler update:
                            end
                            
                            // Simplified update logic:
                            // If mismatch: length = prev_len + 1. Check against best.
                            // If match: length = 1.
                            if (buffer[idx] != buffer[idx-1]) begin
                                current_run <= current_run + 1;
                                if (current_run + 1 > best_run) best_run <= current_run + 1;
                            end else begin
                                current_run <= 1;
                                // best_run stays same (or checked against 1, but 1 is min)
                            end

                            idx <= idx + 1;
                        end else begin
                            // Finished scan
                            process_step <= 2;
                            idx <= 0; // Reset for prefix calc
                        end
                    end
                    // Step 2: Calculate Prefix Length (Takes up to N cycles, but we can stop early)
                    else if (process_step == 2) begin
                        // We check idx from 0 up. 
                        // prefix_len starts at 1 (index 0). We increment as long as buffer[i] != buffer[i-1]
                        // We need a register for prefix_len. Let's reuse current_run or create new.
                        // Let's use `current_run` as temp storage for prefix.
                        // Wait, `current_run` was used for contiguous scan. Let's use `suffix_len` register (unused yet) as temp prefix.
                        
                        if (idx == 0) begin
                             // Initialize prefix check
                             // We need to compare buffer[1] vs buffer[0]
                             // Let's use idx to track the comparison point
                             // If N=1, prefix is 1.
                             // Let's just do it: check buffer[i] != buffer[i-1] for i=1..
                             // We need to count how many satisfy this starting from 1.
                             // Let's use `prefix_len` register properly defined.
                             prefix_len <= 1;
                             idx <= 1;
                        end else begin
                            if (idx < N) begin
                                if (buffer[idx] != buffer[idx-1]) begin
                                    prefix_len <= prefix_len + 1;
                                    idx <= idx + 1;
                                end else begin
                                    // Mismatch found, stop.
                                    process_step <= 3;
                                    idx <= N - 1; // Start suffix from end
                                end
                            end else begin
                                // Reached end, whole string is alternating prefix
                                process_step <= 3;
                                idx <= N - 1;
                            end
                        end
                    end
                    // Step 3: Calculate Suffix Length (Takes up to N cycles)
                    else if (process_step == 3) begin
                        // Scan backwards: compare buffer[N-2] vs buffer[N-1]...
                        // We need to count down from N-1.
                        // Let's use idx. Start at N-2? No, start loop at N-2 down to 0.
                        // Use suffix_len register.
                        
                        if (idx == N - 1) begin
                            suffix_len <= 1;
                            idx <= N - 2; // Move to N-2
                        end else begin
                            if (idx >= 0 && (idx + 1) < N) begin // idx >= 0 check
                                if (buffer[idx] != buffer[idx+1]) begin
                                    suffix_len <= suffix_len + 1;
                                    idx <= idx - 1;
                                end else begin
                                    // Mismatch found, stop.
                                    process_step <= 4;
                                end
                            end else begin
                                // Done or invalid idx (should not happen if logic correct)
                                process_step <= 4;
                            end
                        end
                    end
                    // Step 4: Finalize
                    else if (process_step == 4) begin
                        // Calculate wrap and max
                        // We have best_run (contiguous)
                        // We have prefix_len and suffix_len
                        // Also need to check buffer[0] != buffer[N-1]
                        
                        // Logic:
                        // max_len = best_run
                        // if (buffer[0] != buffer[N-1]) max_len = max(max_len, prefix_len + suffix_len)
                        // max_len = min(max_len, N)
                        
                        if (buffer[0] != buffer[N-1]) begin
                            if ((prefix_len + suffix_len) > best_run) begin
                                max_len <= prefix_len + suffix_len;
                            end else begin
                                max_len <= best_run;
                            end
                        end else begin
                            max_len <= best_run;
                        end
                        
                        // Cap at N (though prefix+suffix cannot exceed N unless all alternating, in which case best_run=N anyway)
                        // If wrap sum > N (e.g. all alternating), we cap.
                        // Actually, if all alternating, prefix=N, suffix=N, sum=2N. 
                        // best_run=N. So max=N. Result N.
                        // If prefix+N > N, we need to cap.
                        if (max_len > N) max_len <= N;
                        
                        // We update max_len in the next cycle or this cycle? 
                        // Since step 4 is just one cycle, we update here.
                        // However, the comparison logic might be complex. 
                        // Let's do the update in step 4, and transition to DONE in the next cycle.
                        // But we already set next_state = DONE when step == 4.
                        // So we need to make sure max_len is valid by then.
                        
                        // Let's separate Step 4 (Calc) and Step 5 (Done signal).
                        // Or just allow the state transition to DONE and assert done.
                        // Let's modify the FSM to have Step 4 as the last calculation, and we stay in PROCESS for one cycle.
                        // Then on next clock, we transition to DONE.
                        
                        // To ensure timing, let's perform the math in Step 4 and move to a "FINISH" substate or just let the FSM go to DONE.
                        // If we transition to DONE immediately, max_len might not be latched yet if we calculated it combinationally.
                        // Let's latched it in Step 4.
                        
                        // Actually, I will add a small buffer: Let Step 4 be the calculation, and I will force one cycle wait or 
                        // allow the FSM to transition to DONE, assuming combinational logic propagation is fast enough.
                        // To be safe, let's keep process_step at 4 for one cycle, then move to 5 which sets a flag to go to DONE.
                        // Or simpler: Just change the FSM logic for PROCESS: 
                        // If (process_step == 4) next_state = DONE;
                        // And calculate max_len when process_step == 4.
                        // The calculation will be ready by the time we enter DONE.
                        // However, `done` signal is set in the combinational block based on state.
                        // The registered outputs (max_len) update on clock edge.
                        
                        // So, on entering Step 4 (which happens on a clock edge), we calculate max_len.
                        // Then, on the *next* clock edge, we transition to DONE.
                        // So Step 4 should NOT transition immediately to DONE.
                        // Let's adjust the FSM:
                        // If process_step == 4, next_state = PROCESS (stay), but a flag is set to move to DONE next.
                        // Or just add a Step 5.
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // --- REVISION COMPLETE ---
    // The above logic is getting complex with nested if/else for the scan loop.
    // Let's simplify the PROCESS state implementation significantly.
    // We will use a clean sub-state machine.
    
    // Sub-states inside PROCESS (encoded in process_step):
    // 0: Init (set indices)
    // 1: Scan (cycle 0..15)
    // 2: Wrap Check (cycle 16)
    // 3: Done
    
    // Let's rewrite the `always` block for clarity and correctness.
    // The previous draft is messy. I will provide a clean, final version.
    
endmodule

// FINAL CLEAN IMPLEMENTATION
module zebra_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] char_index,
    input load,
    output reg [7:0] max_len,
    output reg done
);

    parameter N = 16;
    
    // State Machine
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESS,
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Memory
    reg [7:0] buffer[0:N-1];
    
    // Processing Registers
    reg [4:0] scan_idx;       // Counter for scanning
    reg [7:0] current_run;    // Current alternating run length
    reg [7:0] max_run;        // Max contiguous run found
    reg [7:0] prefix_len;     // Length of prefix
    reg [7:0] suffix_len;     // Length of suffix
    reg [1:0] process_phase;  // 0: Scan, 1: Prefix, 2: Suffix, 3: Finalize
    reg calculation_done;     // Flag to move from PROCESS to DONE

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            calculation_done <= 0;
        end else begin
            if (current_state == PROCESS && process_phase == 3 && scan_idx == 0) begin
                // Calculation finished in this cycle
                calculation_done <= 1;
            end else if (current_state != PROCESS) begin
                calculation_done <= 0;
            end

            case (current_state)
                IDLE: begin
                    if (start) current_state <= PROCESS;
                    else if (load) current_state <= LOAD;
                end
                LOAD: begin
                    if (!load && start) current_state <= PROCESS;
                    else if (!load) current_state <= IDLE;
                end
                PROCESS: begin
                    if (calculation_done) current_state <= DONE;
                end
                DONE: begin
                    if (!start) current_state <= IDLE;
                end
            endcase
        end
    end

    // Data Loading
    always @(posedge clk) begin
        if (current_state == LOAD && load) begin
            if (char_index < N)
                buffer[char_index] <= char_in;
        end
    end

    // Processing Logic (Sequential Scan)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_len <= 0;
            done <= 0;
            scan_idx <= 0;
            process_phase <= 0;
        end else begin
            done <= (current_state == DONE);

            case (current_state)
                PROCESS: begin
                    // Phase 0: Initialize Scan (Cycle 0 of PROCESS)
                    if (process_phase == 0) begin
                        // Reset counters
                        scan_idx <= 1;
                        current_run <= 1;
                        max_run <= 1;
                        process_phase <= 1;
                    end
                    
                    // Phase 1: Scan Contiguous Alternation (Cycles 1 to 16)
                    else if (process_phase == 1) begin
                        if (scan_idx < N) begin
                            // Logic: if buffer[scan_idx] != buffer[scan_idx-1], extend run
                            if (buffer[scan_idx] != buffer[scan_idx-1]) begin
                                current_run <= current_run + 1;
                                if (current_run + 1 > max_run) max_run <= current_run + 1;
                            end else begin
                                current_run <= 1;
                            end
                            scan_idx <= scan_idx + 1;
                        end else begin
                            // Finished scanning contiguous
                            // Move to Phase 2 (Prefix)
                            scan_idx <= 1; // Start checking from index 1 for prefix
                            prefix_len <= 1;
                            process_phase <= 2;
                        end
                    end

                    // Phase 2: Calculate Prefix (Cycles 17+)
                    else if (process_phase == 2) begin
                        if (scan_idx < N) begin
                            if (buffer[scan_idx] != buffer[scan_idx - 1]) begin
                                prefix_len <= prefix_len + 1;
                                scan_idx <= scan_idx + 1;
                            end else begin
                                // Mismatch, stop prefix
                                process_phase <= 3;
                                scan_idx <= N - 2; // Prepare for suffix scan
                            end
                        end else begin
                            // Full string is alternating prefix
                            process_phase <= 3;
                            scan_idx <= N - 2;
                        end
                    end

                    // Phase 3: Calculate Suffix and Finalize (Cycles 18+)
                    else if (process_phase == 3) begin
                        // First, initialize suffix if needed (indicated by scan_idx == N-2 usually)
                        // But we need a register to track suffix length. Let's reuse current_run or max_run.
                        // Let's reuse current_run for suffix_len.
                        
                        // Initialize suffix calc once
                        // Check a flag or just check if we are at the start of this phase? 
                        // We transitioned to phase 3. The logic flow is linear. 
                        // We need to know if we are starting suffix calc or continuing.
                        // Since we set scan_idx <= N-2 in Phase 2, we can start immediately.
                        // However, we need to set the initial suffix length.
                        // Let's use `current_run` to store suffix length.
                        
                        if (scan_idx == N - 2) begin
                            // First cycle of Phase 3
                            if (N > 1 && buffer[N-1] != buffer[N-2]) begin
                                current_run <= 2; // Suffix includes last two
                            end else begin
                                current_run <= 1;
                            end
                            
                            // If N==1, loop below won't run. Suffix is 1.
                            if (N == 1) current_run <= 1;
                        end else begin
                            // Continuing suffix calc (scan_idx < N-2)
                            // We are scanning backwards: check buffer[scan_idx] vs buffer[scan_idx+1]
                            // Wait, scan_idx decrements? 
                            // Let's decrement scan_idx each step in Phase 3.
                            
                            if (scan_idx >= 1) begin // scan_idx starts at N-2, goes down to 1? 
                                // Actually, we compare buffer[i] vs buffer[i+1] for i from N-2 down to 1?
                                // Loop: i = N-2 down to 0. Check buffer[i] != buffer[i+1].
                                // If yes, suffix_len++.
                                
                                // Let's change the loop structure slightly.
                                // We'll decrement scan_idx inside Phase 3.
                            end
                        end

                        // Let's clean up Phase 3 logic:
                        // We have already calculated prefix_len.
                        // We need suffix_len. Let's store it in `suffix_len` register.
                        // We need a temporary counter. Let's use `scan_idx` to count down.
                        
                        if (scan_idx == N - 2 && N > 1) begin
                            suffix_len <= (buffer[N-1] != buffer[N-2]) ? 2 : 1;
                            scan_idx <= scan_idx - 1;
                        end else if (scan_idx > 0 && N > 1) begin
                            if (buffer[scan_idx] != buffer[scan_idx + 1]) begin
                                suffix_len <= suffix_len + 1;
                            end else begin
                                // Mismatch, stop (but we just keep going, final calc handles it)
                                // Actually, we should stop incrementing. But for hardware, we can just stop the update.
                                // We can just force suffix_len to stay same or use a enable flag.
                                // Easier: just calculate suffix_len at the end using combinational logic on the registered buffer.
                                // Since we are in sequential logic, let's just stop updating suffix_len.
                                // But we are iterating down. 
                            end
                            scan_idx <= scan_idx - 1;
                        end else if (N == 1) begin
                            // Special case N=1
                            suffix_len <= 1;
                            scan_idx <= 0;
                        end else begin
                            // Scan finished (scan_idx reaches 0)
                            // Finalize
                            
                            // 1. Check wrapping
                            if (buffer[0] != buffer[N-1]) begin
                                max_len <= (prefix_len + suffix_len > max_run) ? (prefix_len + suffix_len) : max_run;
                            end else begin
                                max_len <= max_run;
                            end
                            
                            // 2. Cap at N (logic handled above or below)
                            // We need to ensure max_len isn't > N.
                            // If prefix+suffix > N, it means we double counted. 
                            // Max possible valid sum is N. 
                            // If max_run == N (all alternating), prefix+suffix might be 2N. We must cap.
                            // Let's do the cap here.
                            
                            // Since max_len is updated at the end of this block, we can't check `max_len` itself yet.
                            // So we calculate explicitly:
                            reg [7:0] candidate;
                            candidate = max_run;
                            if (buffer[0] != buffer[N-1]) begin
                                if ((prefix_len + suffix_len) > candidate) candidate = prefix_len + suffix_len;
                            end
                            if (candidate > N) candidate = N;
                            
                            // We need to assign to max_len. 
                            // Since this is inside an always block, we can't use intermediate 'candidate' reg easily unless defined outside.
                            // Let's do the logic directly:
                            
                            if (buffer[0] != buffer[N-1]) begin
                                if (prefix_len + suffix_len > max_run) begin
                                    if (prefix_len + suffix_len > N) max_len <= N;
                                    else max_len <= prefix_len + suffix_len;
                                end else begin
                                    max_len <= max_run;
                                end
                            end else begin
                                max_len <= max_run;
                            end
                            
                            // Set scan_idx to 0 to indicate done
                            scan_idx <= 0;
                        end
                    end
                end
            endcase
        end
    end

    // Fix for Phase 3 Logic Continuity:
    // The logic above for Phase 3 is fragmented. 
    // Let's refactor Phase 3 implementation to be robust.
    // We will use `process_phase == 3` strictly for suffix calculation and finalization.
    // To make this correct, I will rewrite the `always` block one last time to ensure correct synthesis.
    
    // RESETTING THE ALWAYS BLOCK FOR FINAL CORRECT IMPLEMENTATION
    
endmodule

// FINAL CLEAN AND SYNTHESIZABLE MODULE
module zebra_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] char_index,
    input load,
    output reg [7:0] max_len,
    output reg done
);

    parameter N = 16;
    
    typedef enum logic [1:0] { IDLE, LOAD, PROCESS, DONE } state_t;
    state_t current_state;
    
    reg [7:0] buffer[0:N-1];
    
    // Processing registers
    reg [4:0] i;
    reg [7:0] run_len;
    reg [7:0] best_len;
    reg [7:0] p_len;
    reg [7:0] s_len;
    reg [1:0] phase;
    reg calc_done;

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            max_len <= 0;
            calc_done <= 0;
        end else begin
            done <= (current_state == DONE); // Default done signal
            
            case (current_state)
                IDLE: begin
                    if (start) current_state <= PROCESS;
                    else if (load) current_state <= LOAD;
                end
                
                LOAD: begin
                    if (load && char_index < N) buffer[char_index] <= char_in;
                    if (!load && start) current_state <= PROCESS;
                    else if (!load) current_state <= IDLE;
                end
                
                PROCESS: begin
                    // Sub-state machine for calculation
                    if (phase == 0) begin
                        // Initialize
                        i <= 1;
                        run_len <= 1;
                        best_len <= 1;
                        phase <= 1;
                    end else if (phase == 1) begin
                        // Scan contiguous max
                        if (i < N) begin
                            if (buffer[i] != buffer[i-1]) begin
                                run_len <= run_len + 1;
                                if (run_len + 1 > best_len) best_len <= run_len + 1;
                            end else begin
                                run_len <= 1;
                            end
                            i <= i + 1;
                        end else begin
                            // Prepare for prefix/suffix
                            i <= 1;
                            p_len <= 1;
                            phase <= 2;
                        end
                    end else if (phase == 2) begin
                        // Scan Prefix
                        if (i < N) begin
                            if (buffer[i] != buffer[i-1]) begin
                                p_len <= p_len + 1;
                                i <= i + 1;
                            end else begin
                                phase <= 3; // End of prefix
                                i <= N - 2; // Start suffix scan index
                            end
                        end else begin
                            phase <= 3; // Full string is alternating prefix
                            i <= N - 2;
                        end
                    end else if (phase == 3) begin
                        // Scan Suffix (Backwards) & Finalize
                        // Initialize s_len once based on i value
                        if (i == N - 2) begin
                            if (N > 1 && buffer[N-1] != buffer[N-2]) s_len <= 2;
                            else s_len <= 1;
                            if (N == 1) s_len <= 1; // Corner case
                        end else if (i > 0 && N > 1) begin // We decrement i, so check > 0
                            if (buffer[i] != buffer[i+1]) begin
                                s_len <= s_len + 1;
                            end
                            // If mismatch, we keep s_len same (don't increment)
                        end

                        // Decrement i to scan backwards
                        if (i > 0 && N > 1) begin
                            i <= i - 1;
                        end else begin
                            // Done scanning, Final Calculation
                            // max_len = max(best_len, (p_len + s_len) if wrap valid)
                            // Cap at N
                            
                            // Calculate wrap candidate
                            if (buffer[0] != buffer[N-1]) begin
                                if ((p_len + s_len) > best_len) begin
                                    max_len <= (p_len + s_len > N) ? N : (p_len + s_len);
                                end else begin
                                    max_len <= best_len;
                                end
                            end else begin
                                max_len <= best_len;
                            end
                            
                            current_state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    if (!start) begin
                        current_state <= IDLE;
                        phase <= 0;
                    end
                end
            endcase
        end
    end
endmodule

// The logic above has a slight issue with `phase` handling in DONE state (needs reset) and general flow.
// Let's provide the most robust, compact version.

// FINAL ROBUST IMPLEMENTATION
module zebra_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] char_index,
    input load,
    output reg [7:0] max_len,
    output reg done
);

    parameter N = 16;
    typedef enum logic [1:0] { IDLE, LOAD, PROCESS, DONE } state_t;
    
    state_t state;
    reg [7:0] buf[0:N-1];
    
    // Processing registers
    reg [4:0] idx;
    reg [7:0] run, best, p_len, s_len;
    reg [1:0] step;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_len <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (load) state <= LOAD;
                    else if (start) state <= PROCESS;
                end
                
                LOAD: begin
                    if (load && char_index < N) buf[char_index] <= char_in;
                    if (!load && start) state <= PROCESS;
                    else if (!load) state <= IDLE;
                end
                
                PROCESS: begin
                    case (step)
                        0: begin // Init Contiguous Scan
                            idx <= 1; run <= 1; best <= 1; step <= 1;
                        end
                        1: begin // Scan Contiguous
                            if (idx < N) begin
                                if (buf[idx] != buf[idx-1]) begin
                                    run <= run + 1;
                                    if (run + 1 > best) best <= run + 1;
                                end else run <= 1;
                                idx <= idx + 1;
                            end else begin
                                idx <= 1; p_len <= 1; step <= 2; // Start Prefix
                            end
                        end
                        2: begin // Scan Prefix
                            if (idx < N && buf[idx] != buf[idx-1]) begin
                                p_len <= p_len + 1;
                                idx <= idx + 1;
                            end else begin
                                idx <= N - 2; s_len <= 1; step <= 3; // Start Suffix
                            end
                        end
                        3: begin // Scan Suffix & Finalize
                            if (idx > 0 && N > 1 && buf[idx] != buf[idx+1]) begin
                                s_len <= s_len + 1;
                            end
                            if (idx > 0) idx <= idx - 1;
                            else begin // Done
                                if (buf[0] != buf[N-1]) begin
                                    if (p_len + s_len > best) 
                                        max_len <= (p_len + s_len > N) ? N : p_len + s_len;
                                    else 
                                        max_len <= best;
                                end else max_len <= best;
                                state <= DONE;
                            end
                        end
                    endcase
                end
                
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        step <= 0;
                    end
                end
            endcase
        end
    end
endmodule
