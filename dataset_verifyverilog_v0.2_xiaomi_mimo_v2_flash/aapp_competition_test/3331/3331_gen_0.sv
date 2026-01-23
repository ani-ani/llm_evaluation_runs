module horse_chase(
    input clk,
    input rst_n,
    input start,
    input [3:0] L,
    input [3:0] A,
    input [3:0] B,
    input [3:0] P,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam FINISHED = 3'b100;

    // Internal Registers
    reg [2:0] current_state;
    reg [3:0] current_time;
    reg [3:0] current_bound; // Stores L (length)

    // Memory for current and next frontier (Flattened 3D array)
    // Index: {Horse, Cow1, Cow2} -> 12 bits index
    reg [4095:0] frontier_current;
    reg [4095:0] frontier_next;

    // Memory for visited states to prevent cycles
    // We reset this for each new search
    reg [4095:0] visited;

    // Temporary variables for combinational logic
    reg [11:0] idx;
    reg [3:0] h, c1, c2;
    reg [3:0] next_h, next_c1, next_c2;
    reg [11:0] next_idx;
    reg found_capture;
    reg all_visited; // Flag to check if next frontier is empty

    // Wires for boundaries
    wire [3:0] L_minus_1;
    assign L_minus_1 = current_bound - 1;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            frontier_current <= 0;
            frontier_next <= 0;
            visited <= 0;
            current_time <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize state
                        current_bound <= L;
                        current_time <= 0;
                        // Load initial positions into frontier
                        // Index: {P, A, B}
                        frontier_current <= (1'b1 << {P, A, B});
                        // Reset visited for new search
                        visited <= 0;
                        // Check immediate capture at t=0 (not typically required but good practice)
                        if (P == A || P == B) begin
                            result <= 0;
                            done <= 1;
                            current_state <= FINISHED;
                        end else begin
                            visited[{P, A, B}] <= 1; // Mark initial as visited
                            current_state <= CALCULATE;
                        end
                    end
                end

                CALCULATE: begin
                    // We iterate through the current frontier to generate next frontier
                    // To avoid iterating all 4096 bits in one cycle (slow routing),
                    // we use a variable 'i' to scan bits sequentially.

                    // If we just started processing this time step (i reset)
                    // or we are continuing...
                    // But for simplicity and given "100-200 cycles", we can iterate the whole frontier.
                    // A single cycle scan of 4096 bits is heavy. Let's process 1 bit per cycle using 'i'.

                    // Optimization: Use a priority encoder / lookup to find set bits.
                    // Since we need to scan efficiently, we will use 'i' as the pointer.

                    if (current_time == 0 && !start && frontier_current == 0) begin
                        // Just entered CALCULATE from IDLE (start triggered previous cycle)
                        // Reset i? No, we need to start processing the bit set in IDLE.
                        // Let's use 'i' as a reg to track progress.
                    end
                end
            endcase
        end
    end

    // Separate combinational logic for state expansion to keep FSM clocked cleanly
    // We need a control loop. The FSM above handles the high level, but we need a cycle-by-cycle update.

    // Re-implementation with explicit iterator 'i' to scan frontier bit by bit per cycle.
    // This ensures synthesisable logic that fits timing.

    reg [11:0] scan_ptr; // Registers to track scanning position
    reg processing_step; // Flag indicating we are in the middle of scanning current frontier

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            frontier_current <= 0;
            frontier_next <= 0;
            visited <= 0;
            current_time <= 0;
            scan_ptr <= 0;
            processing_step <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        current_bound <= L;
                        current_time <= 0;
                        // Set initial state
                        frontier_current <= (1'b1 << {P, A, B});
                        visited <= 0;
                        // Immediate check
                        if (P == A || P == B) begin
                            result <= 0;
                            done <= 1;
                            current_state <= FINISHED;
                            frontier_current <= 0;
                        end else begin
                            visited[{P, A, B}] <= 1;
                            // Start processing t=0 -> t=1
                            current_state <= CALCULATE;
                            scan_ptr <= 0;
                            processing_step <= 0; // Not yet processed current frontier
                            frontier_next <= 0; // Clear next buffer
                        end
                    end
                end

                CALCULATE: begin
                    // 1. Check if we are done with current time step expansion
                    //    (Scanned all bits of current frontier OR found capture)

                    // We scan for the first valid bit in frontier_current starting from scan_ptr
                    // If found, expand moves, OR to frontier_next, check capture.
                    // If not found, transition to next time step.

                    // Optimization: Find next set bit
                    // Since we can't easily do priority encoding on 4096 bits in one go without latency,
                    // we iterate 'scan_ptr' from 0 to 4095.

                    // Logic for finding valid states:
                    // If (frontier_current[scan_ptr] && !visited[scan_ptr]) process it.

                    if (frontier_current[scan_ptr]) begin
                        // Found a valid state to expand
                        // Decode positions
                        // Index format: {H, C1, C2}
                        // scan_ptr is the index

                        // Extract positions
                        // h = scan_ptr[11:9] * 2 is too large. 4 bits each. 12 bits total.
                        // scan_ptr[11:8] = Horse, scan_ptr[7:4] = Cow1, scan_ptr[3:0] = Cow2

                        // Logic expansion for one state per cycle is good.

                        // Generate moves
                        // Cow 1 (A)
                        // Cow 2 (B)
                        // Horse (H)

                        // We need to unroll the move generation or do it sequentially.
                        // Given constraints, let's generate moves for one state.

                        // Since this is inside an always block, we can't easily call sub-functions.
                        // We will define the expansion logic explicitly.

                        // Note: To avoid metastability/latch inference, we must be careful with assignments.
                        // We will use intermediate variables defined outside.

                        // Let's calculate next states and OR them into frontier_next.
                        // We also check for capture immediately.

                        // To handle multiple moves per cycle, we can OR them all.
                        // But if we do multiple checks, we need to be careful about writing to frontier_next multiple times in one cycle.
                        // It's fine to OR.

                        // Let's unroll the loops for synthesis efficiency.
                        // We only process one parent state per clock cycle to keep logic depth shallow.
                        // 4096 cycles is < 200us at 50MHz. Acceptable.

                        // Cow 1 moves: c1-1, c1, c1+1 (bounded)
                        // Cow 2 moves: c2-1, c2, c2+1 (bounded)
                        // Horse moves: h-2 to h+2 (bounded, jump 1 or 2)

                        // Check for collision (Horse cannot occupy Cow position in the SAME minute?)
                        // "restricted if occupied". 
                        // Let's assume Horse cannot land on a Cow position in the intermediate step if we were simulating step-by-step.
                        // But problem says "End of minute" capture.
                        // "BFS explores reachable states... restricted if occupied".
                        // Let's assume Horse cannot land on a Cow position in the generated state if it's a "during minute" restriction.
                        // But standard "End of minute" usually implies they can pass through or land if it's capture.
                        // Let's interpret "restricted if occupied" as: Horse cannot move to a spot occupied by a Cow (unless it's the capture).
                        // However, capture happens at End of Minute. 
                        // If Horse moves to A or B, it's capture.
                        // If Horse moves to a spot and Cows also move there, capture.

                        // Wait, the prompt says: "End of minute, capture if Horse == Cow".
                        // So we generate states where H_new == C1_new or H_new == C2_new.
                        // If H_new == C_new, we record the time and finish.

                        // Let's implement the expansion logic directly.

                        // We need variables for the CURRENT state being processed
                        // We use scan_ptr to index.
                        // We need to decode scan_ptr to H, C1, C2.
                        // Since scan_ptr is a register, we can access its bits.

                        // H = scan_ptr[11:8], C1 = scan_ptr[7:4], C2 = scan_ptr[3:0]
                        // Note: 4096 states = 12 bits. Correct.

                        // We need to generate all combinations of moves.
                        // This is a 3D loop. Unrolling manually is tedious but robust.
                        // We can use a nested loop structure with temporary registers, but standard Verilog synthesizes loops to logic.
                        // Given the "per cycle" processing limit, we can unroll or use nested loops within the comb block that drives the next state.
                        // But we are in a clocked block.

                        // Strategy: 
                        // 1. Reset 'processing_step' counter.
                        // 2. In this cycle, we generate all possible next states from 'scan_ptr'.
                        // 3. We OR them into 'frontier_next'.
                        // 4. We mark 'frontier_current[scan_ptr] = 0' (or just track scan_ptr).
                        // 5. Increment 'scan_ptr'.

                        // The problem with unrolling 3 loops is that it creates a huge combinational path.
                        // Horse: 5 options * Cows: 3 options * Cows: 3 options = 45 combinations.
                        // 45 OR gates is fine.

                        // Implementation:
                        // We will use localparams or wires for bounds.
                        // We need to be careful about position bounds [0, L].

                        // Let's assume L is the max index (0 to L inclusive?) or 0 to L-1? "Length L" usually means 0..L.
                        // If L=2, positions 0, 1, 2.
                        // "Positions A, B, P are 4-bit inputs".

                        // We need to update the combinational logic driving the registers.
                        // Since we are modifying 'frontier_next', we can write to it.
                        // However, if we OR multiple things, we need to preserve the previous value.
                        // 'frontier_next' accumulates.

                        // To implement "OR to frontier_next", we effectively need:
                        // frontier_next <= frontier_next | (generated_mask);
                        // But we can't do this if we are iterating many states. 
                        // Actually, we are iterating ONE state per cycle. 
                        // So: frontier_next <= frontier_next | (new_states_from_scan_ptr);

                        // Now, the core logic: generate new_states_from_scan_ptr.
                        // We need to iterate the sub-loops (C1, C2, H) in one cycle or multiple?
                        // 45 combinations is manageable for a single cycle combinational block.

                        // We will create a wire [4095:0] expanded_states;
                        // Then in clocked block: frontier_next <= frontier_next | expanded_states;

                        // Let's write the combinational logic for expanded_states.

                        // But we are inside an always block.
                        // Let's use a separate combinational always block for the expansion logic.

                        // However, to keep it in one module for the prompt, let's use functions or inline logic.
                        // We can't easily use functions for vector indexing in synthesis always blocks in older Verilog, but SystemVerilog is implied.

                        // Let's stick to the "1 state per cycle" plan.

                        // --- Combinational Expansion Logic ---
                        // Inputs: scan_ptr (current state)
                        // Output: next_state_mask (4096 bits)
                        // Output: capture_found (1 bit), capture_time (4 bit)

                        // We will compute this combinationally.

                        // C1 moves: 0, +1, -1 (clamped to 0 and L)
                        // C2 moves: 0, +1, -1
                        // H moves: +1, +2, -1, -2, 0 (clamped to 0 and L)

                        // Collision Rule: "Horse restricted if occupied".
                        // 1. If Horse lands on a Cow (H_new == C1_new or C2_new), it's Capture. Time = current_time + 1.
                        // 2. If Horse lands on a position occupied by a Cow (but not capture, meaning?)
                        //    Actually, if H_new == C_new, it's capture.
                        //    The prompt says: "restricted if occupied".
                        //    Let's assume H cannot jump to a square if a Cow is there (unless capturing).
                        //    But capturing is exactly that condition.
                        //    Maybe it means H cannot pass through a square with a Cow?
                        //    Or H cannot land on a square that will be occupied by a Cow if it's NOT the capture minute?
                        //    Interpretation: H moves. If H lands on C1 or C2, capture.
                        //    If H wants to move to a square, and a Cow is there (at start of minute? End of minute?),
                        //    Let's assume standard rules: H and C move simultaneously. 
                        //    If they meet, capture.
                        //    "Restricted if occupied" usually means H cannot move to a square if a Cow is currently there (blocking).
                        //    But they move simultaneously. 
                        //    Let's assume H can move freely. 
                        //    The only restriction is: if H_new == C_new, we have capture.
                        //    If H_new != C_new, it's a valid state for the next minute.

                        //    Wait, "restricted if occupied" implies H cannot move to a spot occupied by a Cow if it's just moving through?
                        //    But the queue stores states at End of Minute.
                        //    Let's simplify: 
                        //    Generate all moves. 
                        //    If H_new == C1_new OR H_new == C2_new -> Capture. Record Time.
                        //    Else -> Add to next frontier.

                        //    What about "H cannot occupy Cow position"? 
                        //    If H_new == C1_new, it's capture. That's the goal.
                        //    If H_new == C1_new but H_new != C2_new, is it valid? 
                        //    Yes, it's capture.
                        //    What if H_new == C1_new and H_new == C2_new? (All meet).
                        //    Also capture.

                        //    So the logic is:
                        //    For every combination of moves (H', C1', C2'):
                        //       if (H' == C1' || H' == C2') -> Capture at time T+1. 
                        //          If this is the earliest capture, set result.
                        //          However, BFS goes level by level. So the first capture we find at T+1 is the answer.
                        //       else -> Add to next frontier (if not visited).

                        //    But we process states one by one. We might find multiple captures.
                        //    Since we iterate T=0, T=1, T=2... the first capture found is the minimum.

                        //    We need a global flag `capture_found`.
                        //    If `capture_found` is already set, we skip logic (or just stop).

                        //    Let's refine the FSM logic.

                        //    In CALCULATE state:
                        //      If `capture_found` (from previous cycle or comb logic): 
                        //          We should transition to FINISHED.

                        //      If `scan_ptr` reached end of array (4096): 
                        //          We finished the current frontier.
                        //          If `frontier_next` is empty (all 0), no capture possible (or limit reached).
                        //          Else, 
                        //             frontier_current <= frontier_next;
                        //             frontier_next <= 0;
                        //             visited <= visited | frontier_next; // Mark new frontier as visited
                        //             current_time <= current_time + 1;
                        //             scan_ptr <= 0;
                        //             // Check limit
                        //             if (current_time + 1 > 15) // Or L? Limit 16 steps.
                        //                result <= 0; error? Or limit. Prompt says "output limit".

                        //      Else (scanning):
                        //         If frontier_current[scan_ptr] is set:
                        //            Expand.
                        //            If capture found in expansion -> Set result, go to FINISHED.
                        //            Else -> OR into frontier_next.
                        //         scan_ptr <= scan_ptr + 1;

                        //    To implement the expansion efficiently:
                        //    We will use a generate-style unrolling or nested loops in a combinational block.
                        //    Since we are in a clocked block, let's use a combinational block to calculate the 'hits'.

                        //    Let's define a combinational block that takes 'scan_ptr' and 'visited' and outputs:
                        //    - next_mask_to_add
                        //    - is_capture

                        //    But we need to be careful: 'visited' is a large vector. Reading it is fine.

                        //    Let's write the combinational block outside (or use a function).
                        //    We'll use a function for bit manipulation if possible, but indexing 4096 bit vector in a function might be tricky for synthesis.
                        //    Let's do it inline with loops. Verilog synthesizes loops into MUX chains.

                        //    We will implement the expansion logic inside the clocked block using a loop.
                        //    Since we process ONE scan_ptr per cycle, the loop runs 3*3*5 = 45 iterations per cycle.
                        //    This is small enough.

                        //    Wait, we can't have loops inside an always block that updates registers if we want to update 'scan_ptr' at the end of the loop.
                        //    The loop must execute fully in one cycle.
                        //    So we need a combinational calculation of the result of the expansion.

                        //    Let's define:
                        //    reg [4095:0] expansion_mask;
                        //    reg expansion_capture;
                        //    reg [3:0] expansion_time;

                        //    Always @(*) begin
                        //       expansion_mask = 0;
                        //       expansion_capture = 0;
                        //       // Get current positions from scan_ptr
                        //       h = scan_ptr[11:8]; c1 = scan_ptr[7:4]; c2 = scan_ptr[3:0];
                        //       // Loop C1
                        //       for (int i=-1; i<=1; i++) begin
                        //          // Loop C2
                        //          for (int j=-1; j<=1; j++) begin
                        //             // Loop H
                        //             for (int k=-2; k<=2; k++) begin
                        //                // Skip k=0 (stay)? No, include it.
                        //                // Filter bounds
                        //                // Filter "restricted if occupied". 
                        //                // Let's assume "restricted" means H cannot land on C position IF it's not capturing?
                        //                // But if H lands on C, it IS capturing.
                        //                // So we allow H on C. 
                        //                // Maybe "restricted" means H cannot land on a square if a Cow is there and H is NOT moving there? 
                        //                // No, H moves there.
                        //                // Let's assume H moves freely.
                        //                // Wait, "restricted if occupied" likely means H cannot jump *over* an occupied square?
                        //                // Or H cannot occupy the square *unless* it's the target capture?
                        //                // Let's assume H cannot land on a square occupied by a Cow at the *start* of the minute?
                        //                // "Horse moves 0, 1, or 2, restricted if occupied".
                        //                // If Cow A is at 5, and Horse wants to jump from 3 to 5, is it allowed? 
                        //                // Standard BFS usually allows moving to target if it's capture.
                        //                // Let's assume H cannot move to a spot occupied by a Cow at the *start* of the minute unless it's a 0-step move? No.
                        //                // Let's assume the restriction is: H cannot jump *over* a Cow if Cow is in between.
                        //                // This is hard to implement without simulation.
                        //                // Let's implement the simplest interpretation: 
                        //                // H can move 1 or 2 steps. 
                        //                // If |step| == 2, the intermediate square (H + step/2) must be empty? 
                        //                // The prompt says "restricted if occupied" without details.
                        //                // Let's assume H cannot occupy the same square as a Cow unless it's the end state (capture).
                        //                // But BFS explores states. 
                        //                // If H moves to 5, and Cows move to 5, it's capture.
                        //                // If H moves to 5, and Cows move away, it's valid.
                        //                // If H moves to 5, and Cows stay at 5, it's capture.
                        //                // So, we generate states (H', C1', C2').
                        //                // IF (H' == C1' or H' == C2') -> Capture.
                        //                // ELSE -> Valid state.
                        //                // There is no "blocking" in simultaneous movement unless they block the path.
                        //                // Let's ignore blocking for simplicity, as it's not explicitly defined.

                        //                // Logic:
                        //                // h' = h + k
                        //                // c1' = c1 + i
                        //                // c2' = c2 + j
                        //                // Check bounds 0 <= x' <= L
                        //                // Check (h' == c1' || h' == c2')
                        //                // If yes: expansion_capture = 1; expansion_time = current_time + 1;
                        //                // If no: expansion_mask[{h', c1', c2'}] = 1;

                        //    But we must respect "visited" to avoid cycles.
                        //    So only add to expansion_mask if !visited[...].
                        //    And if we find a capture, we ignore visited (though if visited, we wouldn't get here).

                        //    One nuance: BFS level by level. 
                        //    We are expanding states at T. 
                        //    We generate T+1.
                        //    If capture happens, T+1 is the answer.

                        //    So, if expansion_capture is true, we don't care about expansion_mask.

                        //    However, we need to update the clocked block.
                        //    In the clocked block:
                        //      if (expansion_capture) begin
                        //         result <= current_time + 1;
                        //         done <= 1;
                        //         current_state <= FINISHED;
                        //      end else begin
                        //         frontier_next <= frontier_next | expansion_mask;
                        //         scan_ptr <= scan_ptr + 1;
                        //      end

                        //    Wait, `expansion_mask` is 4096 bits wide. ORing it 4096 times (once per scan_ptr) is correct.

                        //    What if scan_ptr reaches 4095?
                        //    We need to detect "end of scan".
                        //    `scan_ptr == 4095` and we are done with this bit.

                        //    Let's refine the scanning loop.
                        //    We need to skip `scan_ptr` if `frontier_current[scan_ptr]` is 0.
                        //    We can use a `while` loop in the combinational block to find the next set bit?
                        //    No, combinational loops are bad.
                        //    Instead, we iterate scan_ptr from 0 to 4095.
                        //    If frontier_current[scan_ptr] is 0, do nothing (mask = 0, capture = 0).
                        //    If 1, process.

                        //    End of scan condition:
                        //    When scan_ptr == 4095, after processing (or skipping), we transition.

                        //    What if we found capture earlier? We stop immediately.

                        //    Let's write the code.

                        // We need to define the combinational logic.
                        // But we are already in an always block.
                        // Let's restructure: 
                        // 1. Combinational block calculates `expansion_result` based on `scan_ptr`.
                        // 2. Clocked block updates registers based on `expansion_result` and state.

                        // Let's define the combinational block explicitly outside the main FSM always block.

                        // --- Combinational Logic for Expansion ---
                    end else begin
                        // If frontier_current[scan_ptr] is 0, just increment scan_ptr
                        // (Unless we are at the end)
                    end
                end
            endcase
        end
    end

    // To make this work as a single synthesizable module without sub-modules, 
    // let's implement the logic cleanly.
    
    // We will use `reg` variables for intermediate calculations inside the combinational block.
    // But since we are in SystemVerilog, we can use always_comb.
    
    // Let's put the combinational logic inside the module.
    
    // Wires for combinational logic
    wire [4095:0] next_mask_calc;
    wire capture_detected_calc;
    wire [3:0] capture_time_calc;
    wire scan_done_calc; // High if scan_ptr is at end
    
    // Helper variables for the loops
    integer i_c1, i_c2, i_h;
    reg [3:0] h_curr, c1_curr, c2_curr;
    reg [3:0] h_next, c1_next, c2_next;
    reg [11:0] next_idx_temp;
    reg capture_flag_temp;
    reg [4095:0] mask_temp;
    
    always @(*) begin
        // Decode current scan_ptr
        h_curr = scan_ptr[11:8];
        c1_curr = scan_ptr[7:4];
        c2_curr = scan_ptr[3:0];
        
        mask_temp = 0;
        capture_flag_temp = 0;
        
        // If this position is not in current frontier (should be checked before calling, but safe to check)
        // Actually, the FSM checks frontier_current[scan_ptr]. If it is 0, we don't use these outputs.
        // So we assume it is 1.
        
        // Nested loops for moves
        // Cow 1 moves: -1, 0, +1
        for (i_c1 = -1; i_c1 <= 1; i_c1 = i_c1 + 1) begin
            if (i_c1 == -1 && c1_curr == 0) continue;
            if (i_c1 == 1 && c1_curr == current_bound) continue;
            c1_next = c1_curr + i_c1;
            
            // Cow 2 moves
            for (i_c2 = -1; i_c2 <= 1; i_c2 = i_c2 + 1) begin
                if (i_c2 == -1 && c2_curr == 0) continue;
                if (i_c2 == 1 && c2_curr == current_bound) continue;
                c2_next = c2_curr + i_c2;
                
                // Horse moves: -2, -1, 0, +1, +2
                for (i_h = -2; i_h <= 2; i_h = i_h + 1) begin
                    if (i_h == -2 && h_curr < 2) continue;
                    if (i_h == -1 && h_curr == 0) continue;
                    if (i_h == 1 && h_curr == current_bound) continue;
                    if (i_h == 2 && h_curr > current_bound - 2) continue;
                    h_next = h_curr + i_h;
                    
                    // Check Capture
                    if (h_next == c1_next || h_next == c2_next) begin
                        capture_flag_temp = 1;
                        // We found a capture. 
                        // In BFS, we don't need to continue searching for *this* state if we found *any* capture.
                        // However, to keep logic simple, we let the loop run. 
                        // But we must prioritize capture. 
                        // If capture_flag_temp is set, we ignore mask_temp.
                    end else begin
                        // Check if visited
                        next_idx_temp = {h_next, c1_next, c2_next};
                        if (!visited[next_idx_temp]) begin
                            mask_temp[next_idx_temp] = 1;
                        end
                    end
                end
            end
        end
    end
    
    // Assign outputs of combinational block
    assign capture_detected_calc = capture_flag_temp;
    assign capture_time_calc = current_time + 1;
    assign next_mask_calc = (capture_flag_temp) ? 0 : mask_temp;
    
    // --- Clock Domain Logic ---
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            frontier_current <= 0;
            frontier_next <= 0;
            visited <= 0;
            current_time <= 0;
            scan_ptr <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        current_bound <= L;
                        current_time <= 0;
                        
                        // Initial State Check
                        if (P == A || P == B) begin
                            result <= 0;
                            done <= 1;
                            current_state <= FINISHED;
                        end else begin
                            // Initialize BFS
                            // We use a single bit vector for frontier.
                            // Since L <= 15 (0-15), we need 4 bits.
                            // P is 4 bits, A is 4, B is 4. Total 12.
                            
                            frontier_current <= (1'b1 << {P, A, B});
                            frontier_next <= 0;
                            visited <= 0;
                            visited[{P, A, B}] <= 1; // Mark start as visited
                            
                            scan_ptr <= 0;
                            current_state <= CALCULATE;
                        end
                    end
                end
                
                CALCULATE: begin
                    // We iterate scan_ptr from 0 to 4095.
                    // If frontier_current[scan_ptr] is 1, we use combinational logic to generate moves.
                    
                    if (capture_detected_calc) begin
                        // Found a capture state in the expansion of the current state
                        result <= capture_time_calc;
                        done <= 1;
                        current_state <= FINISHED;
                        // Clear frontiers to save power
                        frontier_current <= 0;
                        frontier_next <= 0;
                    end else if (scan_ptr == 12'hFFF) begin
                        // We have scanned all possible states for the current time step.
                        // Check if we have any valid states for the next time step.
                        if (frontier_next == 0) begin
                            // No states generated for next level -> Capture not found within limit (or impossible)
                            // According to prompt: "If capture time exceeds limit, output limit (or 0)"
                            // We will output 0 (or current_time+1 if we want to be strict about steps taken)
                            // Let's output 0 to indicate error/not found within 16 steps.
                            result <= 0;
                            done <= 1;
                            current_state <= FINISHED;
                        end else begin
                            // Move to next time step
                            // frontier_next becomes frontier_current
                            frontier_current <= frontier_next;
                            // Reset scan pointer
                            scan_ptr <= 0;
                            // Update time
                            if (current_time >= 15) begin
                                // Hit max depth limit (16 steps total: t=0 to t=15)
                                // Prompt says "Limit maximum time to 16".
                                // If we are at t=15, we just finished expanding it. Next is t=16.
                                // If we don't find capture by t=15, we stop.
                                result <= 0;
                                done <= 1;
                                current_state <= FINISHED;
                            end else begin
                                current_time <= current_time + 1;
                                // Update visited: Mark all states in new frontier as visited
                                // This prevents revisiting states in future levels
                                visited <= visited | frontier_next;
                                // Clear next buffer for accumulation
                                frontier_next <= 0;
                                // Stay in CALCULATE to process the new frontier
                            end
                        end
                    end else begin
                        // We are scanning. 
                        // If frontier_current[scan_ptr] is 0, just increment.
                        // If 1, combinational logic handles expansion (it updates 'frontier_next' implicitly via reg update? No, must register it here).
                        
                        // Note: The combinational block calculates the mask for the CURRENT scan_ptr.
                        // We need to OR it into frontier_next ONLY if frontier_current[scan_ptr] is 1.
                        // But the combinational block assumes valid input.
                        
                        if (frontier_current[scan_ptr]) begin
                            // Accumulate the generated states into frontier_next
                            frontier_next <= frontier_next | next_mask_calc;
                        end
                        
                        // Move to next bit
                        scan_ptr <= scan_ptr + 1;
                    end
                end
                
                FINISHED: begin
                    // Stay here until reset or start
                    // 'done' is already high.
                    if (start) begin
                        // Restart if start is pulsed again
                        // We need to handle 'start' assertion properly to reset the logic.
                        // Usually, 'start' should be pulsed high for one cycle.
                        // If it stays high, we might restart immediately.
                        // Let's allow restart if in FINISHED state.
                        done <= 0;
                        current_state <= IDLE; // Re-use IDLE logic or just jump to IDLE entry
                        // Let's jump to IDLE logic by setting state to IDLE and pulsing logic.
                        // But the IDLE state checks 'start'. If start is still high, we will jump immediately.
                        // To be safe, we stay in FINISHED until start goes low? 
                        // Or we just restart. Let's restart.
                        
                        // Re-init (duplicated from IDLE for clean restart)
                        if (P == A || P == B) begin
                            result <= 0;
                            done <= 1;
                        end else begin
                            current_bound <= L;
                            current_time <= 0;
                            frontier_current <= (1'b1 << {P, A, B});
                            frontier_next <= 0;
                            visited <= 0;
                            visited[{P, A, B}] <= 1;
                            scan_ptr <= 0;
                            current_state <= CALCULATE;
                        end
                    end
                end
            endcase
        end
    end

endmodule
