module pebble_transform (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [3:0] K,
    input [7:0] target_circle,
    output reg [7:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE            = 5'b00001;
    localparam INIT_CANDIDATE  = 5'b00010;
    localparam APPLY_TRANSFORM = 5'b00100;
    localparam CHECK_EQUIVALENCE = 5'b01000;
    localparam NEXT_CANDIDATE  = 5'b10000;
    localparam DONE_STATE      = 5'b00000; // Decoded as 0 for implicit default, mapped explicitly

    // Additional states to separate logic and ensure sequential FSM
    // We will use a more granular state machine to fit the 2^N * K * N latency
    // States: IDLE -> INIT -> LOOP_START -> TRANSFORM -> TRANSFORM_WAIT -> CHECK_START -> CHECK_LOOP -> CHECK_DONE -> NEXT -> DONE

    // Redefining states for clear sequential flow
    localparam S_IDLE           = 4'd0;
    localparam S_INIT           = 4'd1;    // Initialize counters and flags
    localparam S_GET_CANDIDATE  = 4'd2;    // Load initial circle from counter or memory logic
    localparam S_TRANS_WAIT     = 4'd3;    // Wait state for K loop
    localparam S_APPLY_STEP     = 4'd4;    // Perform single transformation
    localparam S_ROT_WAIT       = 4'd5;    // Wait state for rotation loop
    localparam S_CHECK_ROT      = 4'd6;    // Perform rotation check
    localparam S_MATCH_FOUND    = 4'd7;    // Increment result
    localparam S_NEXT_CAND      = 4'd8;    // Increment candidate counter
    localparam S_FINISHED       = 4'd9;    // Signal done

    reg [3:0] state, next_state;

    // Internal Registers
    reg [7:0] current_circle;      // Current circle during transformation
    reg [7:0] temp_circle;         // Result of one transformation step
    reg [7:0] candidate_start;     // The starting circle for current trial (for canonical check)
    
    reg [7:0] target_canonical;    // Pre-computed canonical form of target
    
    // Counters
    reg [7:0] candidate_idx;       // 0 to 2^N - 1
    reg [3:0] k_counter;           // 0 to K - 1
    reg [2:0] rotation_counter;    // 0 to N - 1
    reg [2:0] bit_counter;         // For iterating bits (0 to N-1) within transformation or rotation
    
    // Flags
    reg match_flag;                // Indicates if current rotation matches target
    reg k_done_flag;               // K transformations done
    reg rot_done_flag;             // All rotations checked
    reg candidate_done_flag;       // All candidates processed

    // Logic to generate initial circle from candidate_idx
    // N dictates how many bits of candidate_idx are valid
    wire [7:0] initial_circle_wire;
    assign initial_circle_wire = candidate_idx & ((1 << N) - 1);

    // Helper logic for transformation: C'[i] = (C[i] == C[(i+1)%N]) ? 1 : 0
    // We compute this combinationaly to be loaded into temp_circle
    // Since N is variable, we need a loop or bit-wise logic dependent on N
    // We will compute the whole 8-bit vector, but only relevant bits are considered
    
    integer i;
    reg [7:0] transformed_val;
    
    always @(*) begin
        transformed_val = 8'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
                // Check wrapping
                if (i == N - 1) begin
                    // Last bit compares with bit 0
                    transformed_val[i] = (current_circle[i] == current_circle[0]) ? 1'b1 : 1'b0;
                end else begin
                    transformed_val[i] = (current_circle[i] == current_circle[i+1]) ? 1'b1 : 1'b0;
                end
            end
        end
    end

    // Helper logic for rotation check
    // Rotate current_candidate by rotation_counter and compare with target_circle
    // Rotated[i] = candidate_start[(i + rotation_counter) % N]
    reg [7:0] rotated_val;
    always @(*) begin
        rotated_val = 8'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
                int idx;
                idx = (i + rotation_counter);
                if (idx >= N) idx = idx - N; // Modulo N
                rotated_val[i] = candidate_start[idx];
            end
        end
    end

    // Canonical representation of target (min rotation)
    // We calculate this once at initialization or assume target is provided in canonical form.
    // The problem asks to count starting circles that produce the same result as target.
    // If we apply transformations to a start circle, we get a result.
    // The result is compared to target.
    // "Rotation equivalence handled by canonical representation".
    // We compare rotated candidate result (or simply check all rotations of candidate against target).
    // Let's pre-compute target canonical form to make comparison easier.
    // Or, simpler: Check if candidate (after K transforms) matches ANY rotation of target.
    // Wait, the prompt says: "Two circles are equivalent if one can be rotated to match the other".
    // This usually implies we are checking equivalence, not just matching target.
    // It says: "Compare result with target_circle (considering rotation equivalence)".
    // This implies: Result is equivalent to Target if there exists a shift S such that they match.
    // So we check Result against Shifts of Target.
    // Let's pre-compute Target Canonical to save logic during loop, but standard way is checking rotations of Result against Target.
    // Actually, checking rotations of Result against Target is more correct if we want to know if Result is equivalent to Target.
    // But the prompt says: "Increment result counter" if "equivalent".
    // Let's assume we compare Result (from K steps) to Target (canonical or rotated).
    // To be safe and symmetric, we will check if `Result` rotated matches `Target`, or `Target` rotated matches `Result`.
    // Let's just rotate `Result` (which is `current_circle` after K steps) and compare to `Target`.
    
    // State Machine Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default non-state updates
            done <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    result <= 8'd0;
                    // wait for start
                end

                S_INIT: begin
                    candidate_idx <= 8'd0;
                    // result is already 0 from IDLE or Reset
                    // Pre-calculate target canonical? 
                    // Let's just compare in CHECK_EQUIVALENCE state.
                end

                S_GET_CANDIDATE: begin
                    // Load initial circle from index (mask with N bits)
                    // Actually, initial_circle_wire handles masking.
                    // We load current_circle with initial.
                    current_circle <= initial_circle_wire;
                    k_counter <= 4'd0;
                end

                S_TRANS_WAIT: begin
                    // Check if K transformations done
                    if (k_counter >= K) begin
                        // Done transforming, move to check
                        // current_circle holds the result
                    end else begin
                        // Next is to apply transform
                    end
                end

                S_APPLY_STEP: begin
                    // Apply transformation: current_circle = transformed_val
                    // But we must only apply to valid N bits. transformed_val computes this.
                    current_circle <= transformed_val;
                    k_counter <= k_counter + 1'b1;
                end

                S_ROT_WAIT: begin
                    // Initialize rotation check
                    rotation_counter <= 3'd0;
                    match_flag <= 1'b0;
                end

                S_CHECK_ROT: begin
                    // Check if current_circle rotated matches target
                    // Here we perform the actual check logic
                    // Logic: Compare rotated_val with target_circle
                    // rotated_val is current_circle rotated by rotation_counter
                    // We need to compare only N bits.
                    // If rotated_val (masked) == target_circle (masked), then match.
                    
                    // However, we need to mask N bits.
                    // rotated_val is computed in comb logic based on candidate_start (which is actually what we are checking).
                    // Wait, in the loop, `current_circle` is the result after K steps.
                    // `candidate_start` is the starting circle (used for canonical ID or something? No).
                    // Actually, `candidate_start` is just to keep track of the starting circle for debug or canonical ID.
                    // We need to rotate `current_circle`.
                    // Let's pass `current_circle` to the rotation logic instead of `candidate_start`.
                    // Let's create a dedicated wire for Rotating Result.
                    // wire [7:0] rotated_result = (current_circle >> rotation_counter) | (current_circle << (N - rotation_counter));
                    // Logic in comb block:
                    // rotated_val[i] = current_circle[(i + rotation_counter) % N];
                    // Then check: if ( (rotated_val & mask) == (target_circle & mask) ) match.
                    
                    // Let's perform this check in the FSM block explicitly.
                    // To save combinational logic depth, we can do bit by bit in a loop if needed, 
                    // but here we assume synthesis handles the array well or we do a combinational check.
                    
                    // Increment rotation counter
                    rotation_counter <= rotation_counter + 1'b1;
                    
                    // Check Match
                    // We need a mask for N bits
                    // mask = (1 << N) - 1;
                    // rotated_val is computed based on current_circle and rotation_counter (comb logic)
                    // Wait, the comb logic `rotated_val` uses `candidate_start`. We need to fix that or use a new wire.
                    // Let's assume `rotated_val` is generic. We'll map `current_circle` to the rotation input in the comb block logic if we were parametric, 
                    // but here we can just reassign the logic or use a dedicated wire.
                    // Let's use a new wire `rotated_result_wire`.
                    // But for FSM sequential logic, we can compute the check in the state or comb logic.
                    // Let's do it in the state body to be clear.
                    
                    // Wait, we are in S_CHECK_ROT. We need to check if `rotated` result matches `target`.
                    // Let's say we have a flag `rot_match`.
                    // But `rotated_val` in the comb block is based on `candidate_start`. 
                    // I will fix `rotated_val` to use `current_circle` inside the FSM check logic or create a separate block.
                    // Actually, let's just update `match_flag` if this rotation matches.
                    // We can do: if (rotation check passes) match_flag <= 1'b1;
                    // But the check needs to happen once per rotation. 
                    // Since `S_CHECK_ROT` iterates, we need to check the CURRENT rotation.
                    
                    // Re-eval rotation logic for `current_circle`:
                    // Rotate current_circle by rotation_counter -> R
                    // Compare (R & mask) vs (target & mask)
                end

                S_MATCH_FOUND: begin
                    result <= result + 1'b1;
                end

                S_NEXT_CAND: begin
                    candidate_idx <= candidate_idx + 1'b1;
                    // Check overflow done in next state logic
                end

                S_FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic for State Transition
    always @(*) begin
        case (state)
            S_IDLE: begin
                if (start) next_state = S_INIT;
                else next_state = S_IDLE;
            end
            
            S_INIT: begin
                // If K is 0? Inputs are 1-4. If N is 0? Inputs 3-8.
                // Check if K==0 or N<3, treat as done or immediate? 
                // Inputs assumed valid. 
                next_state = S_GET_CANDIDATE;
            end

            S_GET_CANDIDATE: begin
                next_state = S_TRANS_WAIT;
            end

            S_TRANS_WAIT: begin
                if (k_counter >= K) next_state = S_ROT_WAIT;
                else next_state = S_APPLY_STEP;
            end

            S_APPLY_STEP: begin
                next_state = S_TRANS_WAIT;
            end

            S_ROT_WAIT: begin
                next_state = S_CHECK_ROT;
            end

            S_CHECK_ROT: begin
                // We need to perform the check for the current rotation_counter.
                // But we are incrementing rotation_counter in the sequential block.
                // So in S_CHECK_ROT, we check the rotation index BEFORE increment (if we did it sequentially) 
                // OR we check the index AFTER increment (if we did it in prev state).
                // Let's check the rotation index (rotation_counter) as it was at entry of this state.
                // Wait, if we increment in sequential block, the value of rotation_counter in this state is the NEW value (incremented).
                // So we need to check `rotation_counter - 1`? No, that's messy.
                // Let's move the increment to the NEXT state or handle it carefully.
                
                // Correction: In S_CHECK_ROT (state code), we want to check rotation `rotation_counter`.
                // If we increment `rotation_counter` in the sequential block for S_CHECK_ROT, then inside the block `rotation_counter` becomes R+1.
                // So the logic `rotated_val` which uses `rotation_counter` will use R+1.
                // We want to check R. 
                // Let's do: In S_CHECK_ROT, we don't increment. 
                // We check R. Then go to a state to increment or stay.
                // But to save states, we can do: In S_CHECK_ROT, we check R. Then in transition we check if R == N-1.
                // If we increment in S_CHECK_ROT, we check R-1 in the logic.
                // Let's keep it simple: In S_CHECK_ROT, we increment `rotation_counter` in the sequential block. 
                // Then we check `(rotation_counter - 1)`th rotation.
                // Or, easier: Do the increment in the NEXT state (S_ROT_INCR).
                // Given state limit preference, let's combine.
                // Let's define S_CHECK_ROT as: Check rotation at `rotation_counter`, then Increment. If done, go next candidate.
                // So we do logic in comb block dependent on `rotation_counter`, and the sequential block increments.
                // But we need to check the OLD value.
                // Let's use a separate logic block or just verify carefully.
                
                // Let's just perform the check in S_CHECK_ROT based on `rotation_counter` value.
                // Then transition. 
                // But we need to know if we matched. So we need to set `match_flag`.
                // `match_flag` accumulates (OR) over rotations.
                // We perform check on `rotation_counter`. If match, set `match_flag`.
                // Then increment `rotation_counter`.
                // Then if `rotation_counter` < N, loop back to S_CHECK_ROT.
                // Else go to S_NEXT_CAND.
                
                // Logic for checking:
                // We need a wire for Rotated Current Circle (mask N bits) vs Target (mask N bits).
                // Let's assume `rotated_val` (comb logic) is updated to use `current_circle` and `rotation_counter`.
                // I'll make `rotated_val_comb` based on `current_circle` and `rotation_counter`.
                
                // Check logic:
                // mask = (1 << N) - 1;
                // if ( (rotated_val_comb & mask) == (target_circle & mask) ) match = 1.
                
                // Transition:
                if (rotation_counter < N - 1) begin
                    next_state = S_CHECK_ROT; // Stay to check next rotation
                end else begin
                    // We checked last rotation (index N-1). 
                    // Now we need to move to next candidate or match found.
                    // But wait, if we are in S_CHECK_ROT, we just checked index N-1.
                    // We should increment rotation_counter to N (exit condition).
                    // Then go to a state to decide next action.
                    next_state = S_NEXT_CAND; // Placeholder, logic below handles result increment.
                end
            end

            S_MATCH_FOUND: begin
                next_state = S_NEXT_CAND;
            end

            S_NEXT_CAND: begin
                // Check if all candidates done.
                // 2^N candidates.
                // If N=8, 256 candidates (idx 0..255).
                // If N<8, say 3, 2^3=8 (idx 0..7).
                // mask = (1<<N)-1. Max idx = mask.
                // If candidate_idx == mask -> DONE.
                // Else -> INIT_CANDIDATE (or GET_CANDIDATE)
                if (candidate_idx == ((1 << N) - 1)) begin
                    next_state = S_FINISHED;
                end else begin
                    next_state = S_GET_CANDIDATE;
                end
            end

            S_FINISHED: begin
                if (start) next_state = S_FINISHED; // Stay done until reset or new start?
                else next_state = S_IDLE; // Fall back on start low? Or wait for reset.
                // Usually we wait for reset. Let's wait for reset (go to IDLE on reset, not here).
                // If start goes low, we stay DONE. Wait for Reset.
                next_state = S_FINISHED;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Adjusted Sequential Logic for S_CHECK_ROT to handle the logic correctly
    // The previous always block assumed we did logic there. 
    // Let's refine the state actions.
    
    // Re-implementing the Sequential Block with refined logic for S_CHECK_ROT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        state <= S_INIT;
                        result <= 8'd0;
                        done <= 1'b0;
                    end
                end

                S_INIT: begin
                    candidate_idx <= 8'd0;
                    state <= S_GET_CANDIDATE;
                end

                S_GET_CANDIDATE: begin
                    current_circle <= candidate_idx & ((1 << N) - 1); // Load initial circle (right aligned)
                    k_counter <= 4'd0;
                    state <= S_TRANS_WAIT;
                end

                S_TRANS_WAIT: begin
                    if (k_counter >= K) begin
                        state <= S_ROT_WAIT;
                    end else begin
                        state <= S_APPLY_STEP;
                    end
                end

                S_APPLY_STEP: begin
                    // Apply transform: C'[i] = (C[i] == C[(i+1)%N])
                    // This logic is in the comb block 'transformed_val'
                    current_circle <= transformed_val;
                    k_counter <= k_counter + 1'b1;
                    state <= S_TRANS_WAIT;
                end

                S_ROT_WAIT: begin
                    // Reset rotation loop variables
                    rotation_counter <= 3'd0;
                    match_flag <= 1'b0; // Reset match flag for this candidate
                    state <= S_CHECK_ROT;
                end

                S_CHECK_ROT: begin
                    // Check rotation index 'rotation_counter'
                    // Compare 'rotated_val' (computed based on current_circle and rotation_counter) with target_circle.
                    // Mask N bits.
                    // If match, set match_flag.
                    // Note: 'rotated_val' in comb block needs to depend on 'current_circle' and 'rotation_counter'.
                    // The 'rotated_val' defined earlier depends on 'candidate_start'.
                    // Let's fix that: We will use a separate wire or localparam logic here.
                    // To keep it clean, we will write the logic explicitly here using a for-loop or bit manipulation.
                    
                    // Logic to rotate current_circle by rotation_counter:
                    // R[i] = current_circle[(i + rotation_counter) % N]
                    // Compare R[0:N-1] with target_circle[0:N-1]
                    
                    // Since we are in sequential block, we can use a local integer loop if we want, 
                    // but synthesis prefers combinational assignments.
                    // Let's use the `rotated_val` wire but we need to route `current_circle` to it.
                    // Since `rotated_val` is defined as depending on `candidate_start`, let's just redefine the check logic.
                    
                    // Check logic:
                    // We need to check if for all i in 0..N-1, current_circle[(i + rotation_counter)%N] == target_circle[i]
                    // This is: (current_circle rotated by -rotation_counter) == target_circle.
                    // Let's compute: Rotated = (current_circle >> rotation_counter) | (current_circle << (N - rotation_counter))
                    // Mask with (1<<N)-1. Compare with target_circle masked.
                    
                    // Let's do bitwise extraction in the loop or just use a standard rotate trick.
                    // Warning: N is 3..8. We must handle masking.
                    // Rotated = {current_circle, current_circle} >> rotation_counter; // 16-bit concat
                    // Then mask lower N bits.
                    // Then compare with target.
                    
                    // Let's assume we calculate this in a wire for clarity, but here it is:
                    // Wire [15:0] double = {current_circle, current_circle};
                    // Wire [15:0] rot_shift = double >> rotation_counter;
                    // Wire [7:0] rotated = rot_shift[7:0] & mask;
                    // Wire match = (rotated == (target_circle & mask));
                    
                    // We will do the check:
                    // In this state, we check the CURRENT rotation_counter value.
                    
                    // Check Logic:
                    begin // begin block for local variables
                        integer i;
                        reg check_match;
                        reg [7:0] mask;
                        mask = (1 << N) - 1;
                        check_match = 1'b1;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < N) begin
                                int idx;
                                idx = i + rotation_counter;
                                if (idx >= N) idx = idx - N;
                                if (current_circle[idx] != target_circle[i]) check_match = 1'b0;
                            end
                        end
                        
                        if (check_match) begin
                            match_flag <= 1'b1;
                        end
                    end
                    
                    // Increment rotation_counter logic or transition
                    if (rotation_counter < N - 1) begin
                        rotation_counter <= rotation_counter + 1'b1;
                        state <= S_CHECK_ROT;
                    end else begin
                        // Checked all rotations (0 to N-1)
                        // Now decide next step based on match_flag
                        if (match_flag) begin // Or if we just found a match now? 
                             // match_flag is updated immediately in this block.
                             // Since sequential, match_flag will be updated at end of cycle.
                             // But next state decision is combinational based on `state`.
                             // Wait, if I update match_flag here, it's valid for the next clock cycle.
                             // But I need to decide NOW if I go to MATCH_FOUND or NEXT_CAND.
                             // I need to know if we matched. 
                             // I can use the `check_match` variable.
                             
                             // So:
                             // if (check_match) -> go to MATCH_FOUND (and increment result later)
                             // else -> go to NEXT_CAND
                             // BUT, what if a PREVIOUS rotation matched? We set match_flag=1.
                             // So we should check: if (check_match || match_flag). 
                             // Actually, if we are here, we just checked N-1. 
                             // If any previous check set match_flag, we keep it. 
                             // If this check is match, we set it.
                             
                             // Since we are in sequential, we can't see future values of match_flag.
                             // But we can OR `check_match` with `match_flag` (which holds value from previous rotations).
                             
                             if (check_match || match_flag) begin
                                 state <= S_MATCH_FOUND;
                                 // Also update result here or in S_MATCH_FOUND? 
                                 // Let's go to S_MATCH_FOUND.
                             end else begin
                                 state <= S_NEXT_CAND;
                             end
                        end else begin
                             // Wait, `match_flag` is the value BEFORE this state execution.
                             // `check_match` is value from THIS rotation.
                             // If previous was match, we are done.
                             // If current is match, we are done.
                             // We need to capture "any match".
                             if (check_match) state <= S_MATCH_FOUND;
                             else state <= S_NEXT_CAND;
                        end
                    end
                end

                S_MATCH_FOUND: begin
                    result <= result + 1'b1;
                    state <= S_NEXT_CAND;
                end

                S_NEXT_CAND: begin
                    if (candidate_idx == ((1 << N) - 1)) begin
                        state <= S_FINISHED;
                    end else begin
                        candidate_idx <= candidate_idx + 1'b1;
                        state <= S_GET_CANDIDATE;
                    end
                end

                S_FINISHED: begin
                    done <= 1'b1;
                    // Wait for reset or restart logic?
                    // If start goes low, stay here. 
                    // If start goes high again, maybe restart? 
                    // Usually IDLE -> INIT on start. So if here, and start=0, stay.
                    // If start=1, stay (or if we want to restart, we need start to toggle low->high).
                    // We will stay in S_FINISHED until reset.
                end
            endcase
        end
    end

    // State Transition Logic (Combinational)
    // This duplicates the state transitions from above if they weren't explicit in sequential.
    // To be robust, we define next_state.
    always @(*) begin
        case (state)
            S_IDLE:           next_state = start ? S_INIT : S_IDLE;
            S_INIT:           next_state = S_GET_CANDIDATE;
            S_GET_CANDIDATE:  next_state = S_TRANS_WAIT;
            S_TRANS_WAIT:     next_state = (k_counter >= K) ? S_ROT_WAIT : S_APPLY_STEP;
            S_APPLY_STEP:     next_state = S_TRANS_WAIT;
            S_ROT_WAIT:       next_state = S_CHECK_ROT;
            S_CHECK_ROT:      begin
                // Determine if we should stay or leave based on rotation counter update
                // BUT rotation_counter update happens in sequential block.
                // Here, we use the current value.
                // We handled the "Done with all rotations" logic in the sequential block for state transition?
                // No, I put the logic in sequential block for S_CHECK_ROT which sets `state` directly.
                // That is valid (Mealy-like logic in sequential block), but combining with combinational next_state is messy.
                
                // Let's strictly use combinational next_state.
                // In S_CHECK_ROT, we check `rotation_counter`.
                // 1. If rotation_counter < N-1: Next state = S_CHECK_ROT.
                // 2. If rotation_counter == N-1: 
                //    Check if (match_flag OR current_check_match).
                //    If match: Next = S_MATCH_FOUND.
                //    Else: Next = S_NEXT_CAND.
                
                // Calculate current_check_match (combinational)
                reg check_match;
                integer i;
                check_match = 1'b1;
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < N) begin
                        int idx;
                        idx = i + rotation_counter;
                        if (idx >= N) idx = idx - N;
                        if (current_circle[idx] != target_circle[i]) check_match = 1'b0;
                    end
                end
                
                if (rotation_counter < N - 1) begin
                    next_state = S_CHECK_ROT;
                end else begin
                    // Last rotation checked
                    if (match_flag || check_match) begin
                        next_state = S_MATCH_FOUND;
                    end else begin
                        next_state = S_NEXT_CAND;
                    end
                end
            end
            S_MATCH_FOUND:    next_state = S_NEXT_CAND;
            S_NEXT_CAND:      begin
                if (candidate_idx == ((1 << N) - 1)) next_state = S_FINISHED;
                else next_state = S_GET_CANDIDATE;
            end
            S_FINISHED:       next_state = S_FINISHED;
            default:           next_state = S_IDLE;
        endcase
    end

    // Logic updates for S_CHECK_ROT sequential block were defined above.
    // We need to make sure `match_flag` update logic in sequential block covers all cases.
    // In S_CHECK_ROT (sequential):
    // We check `rotation_counter`. 
    // We update `match_flag` if check_match is true.
    // We increment `rotation_counter` if `rotation_counter < N-1`.
    // We transition state in combinational block.
    
    // Let's refine the S_CHECK_ROT part of the sequential block to match the combinational decision.
    // Actually, the previous implementation in the sequential block mixed state transition logic.
    // Let's rewrite the sequential block cleanly with explicit state actions and rely on `next_state`.

    // Final Refinement of Sequential Logic for S_CHECK_ROT and others:
    // We will remove the manual `state <= ...` assignments inside the case items (except maybe S_FINISHED), 
    // and strictly assign state = next_state at the end.
    // We will handle `match_flag` and `rotation_counter` updates in S_CHECK_ROT.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 8'd0;
            done <= 1'b0;
            // Reset other regs if needed
            match_flag <= 1'b0;
            rotation_counter <= 3'd0;
            current_circle <= 8'd0;
            candidate_idx <= 8'd0;
            k_counter <= 4'd0;
        end else begin
            state <= next_state;
            
            // Default assignments
            done <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    if (start) begin
                        result <= 8'd0;
                    end
                end
                
                S_INIT: begin
                    candidate_idx <= 8'd0;
                end
                
                S_GET_CANDIDATE: begin
                    current_circle <= candidate_idx & ((1 << N) - 1);
                    k_counter <= 4'd0;
                end
                
                S_TRANS_WAIT: begin
                    // No action, waiting for combinational next_state to switch
                end
                
                S_APPLY_STEP: begin
                    current_circle <= transformed_val;
                    k_counter <= k_counter + 1'b1;
                end
                
                S_ROT_WAIT: begin
                    rotation_counter <= 3'd0;
                    match_flag <= 1'b0;
                end
                
                S_CHECK_ROT: begin
                    // Calculate check_match for CURRENT rotation_counter
                    // We do this in combinational logic to avoid loops in seq block, 
                    // but since we need to update match_flag, we can do it here.
                    // Let's use the wire `rotated_val` if we fix it, or use a local variable.
                    
                    // Re-using the logic block:
                    begin
                        reg check_match;
                        integer i;
                        check_match = 1'b1;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < N) begin
                                int idx;
                                idx = i + rotation_counter;
                                if (idx >= N) idx = idx - N;
                                if (current_circle[idx] != target_circle[i]) check_match = 1'b0;
                            end
                        end
                        if (check_match) begin
                            match_flag <= 1'b1;
                        end
                    end
                    
                    // Increment rotation_counter if not last
                    if (rotation_counter < N - 1) begin
                        rotation_counter <= rotation_counter + 1'b1;
                    end
                    // If we are at last rotation, we don't increment here; next_state decides where to go.
                    // But we are incrementing `rotation_counter` to N.
                    // Then in `next_state` logic (S_CHECK_ROT), if rotation_counter < N-1, we loop.
                    // If we just incremented to N-1, we loop one more time? 
                    // Let's trace: 
                    // 1. Start: rot=0. S_CHECK_ROT. check. if (0 < N-1) -> inc rot=1. State next = S_CHECK_ROT (if logic says < N-1).
                    // Wait, combinational `next_state` logic for S_CHECK_ROT checks `rotation_counter`.
                    // If we update `rotation_counter` in sequential block, it becomes 1. 
                    // Combinational block sees 1. If 1 < N-1, next is S_CHECK_ROT.
                    // This works.
                    
                    // When rot = N-1. S_CHECK_ROT. check. if (N-1 < N-1) -> false. 
                    // Combinational block sees N-1. Logic: else -> if match -> MATCH_FOUND -> NEXT_CAND.
                    // So we don't increment rot when rot == N-1 (in the `if` statement above).
                    // Correct.
                end
                
                S_MATCH_FOUND: begin
                    result <= result + 1'b1;
                end
                
                S_NEXT_CAND: begin
                    // Increment candidate index if not done
                    // We check done condition in combinational next_state logic.
                    // If we are in NEXT_CAND, we assume we aren't done yet (unless next_state goes to DONE).
                    // But we should only increment if we are NOT at the last candidate.
                    // Wait, if candidate_idx == 255 (N=8), we transition to S_FINISHED.
                    // If we transition to S_FINISHED, we don't execute S_NEXT_CAND code.
                    // So we can safely increment here, assuming we only enter this state if not done.
                    // But we entered this state. We need to increment candidate_idx to prepare for next loop.
                    // Actually, we just finished candidate `candidate_idx`. We want to start candidate `candidate_idx + 1`.
                    // So we increment here. 
                    // But we need to handle the edge case: If we just finished the LAST candidate (idx max), we should NOT increment, go to DONE.
                    // The combinational logic handles the transition to DONE.
                    // If we are in S_NEXT_CAND and `candidate_idx` was max, `next_state` is S_FINISHED.
                    // So we will transition to S_FINISHED without executing this code? No, `state` becomes S_NEXT_CAND, we execute this code, then next cycle `state` becomes S_FINISHED.
                    // We must prevent incrementing `candidate_idx` if we are about to finish.
                    
                    // Logic: if candidate_idx < max, increment.
                    if (candidate_idx < ((1 << N) - 1)) begin
                        candidate_idx <= candidate_idx + 1'b1;
                    end
                end
                
                S_FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
