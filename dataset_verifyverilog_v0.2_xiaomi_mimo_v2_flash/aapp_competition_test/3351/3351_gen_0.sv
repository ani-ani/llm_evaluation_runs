module yahtzee_solver(
    input clk,
    input rst_n,
    input start,
    input [5:0] num_rolls,
    input [2:0] dice_in [0:64],
    output reg [11:0] max_score,
    output reg done
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam RESET_DP = 4'd1;
    localparam ROUND_LOOP = 4'd2;
    localparam ROLL_STRATEGY = 4'd3;
    localparam ROLL_COMPUTE = 4'd4;
    localparam SCORE_CALC = 4'd5;
    localparam UPDATE_DP = 4'd6;
    localparam NEXT_ROUND = 4'd7;
    localparam DONE_STATE = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;

    // Constants
    localparam NUM_ROUNDS = 4'd13;
    localparam MAX_DICE_INDEX = 6'd64;

    // DP Memory: 13 rounds x 65 dice indices
    // Stores max score achievable starting at specific round and dice index
    reg [11:0] dp [0:12][0:64];
    
    // Registers for iteration
    reg [3:0] round_idx; // 0-12
    reg [6:0] dice_idx;  // 0-64
    reg [3:0] keep_mask_1; // First re-roll keep mask (0-15, 4 bits enough for 5 dice logic, though we iterate 0-31)
    reg [3:0] keep_mask_2; // Second re-roll keep mask
    reg [5:0] roll_offset; // Tracks position in dice_in array
    
    // Intermediate computation registers
    reg [2:0] hand [0:4]; // Current hand being evaluated
    reg [2:0] current_die_val; // For extracting dice
    reg [4:0] best_score_current; // Best score for current round strategy
    reg [11:0] next_dp_score; // Calculated score to update DP
    reg [5:0] best_idx_next; // Best dice index for next round
    
    // Temporary storage for re-roll simulation
    reg [2:0] temp_hand_1 [0:4];
    reg [2:0] temp_hand_2 [0:4];
    reg [2:0] final_hand [0:4];
    
    // Counters for re-roll loops
    reg [5:0] mask_iter_1; // 0-31
    reg [5:0] mask_iter_2; // 0-31
    reg [5:0] sim_roll_cnt; // 0-2 (0: start, 1: first re-roll, 2: second re-roll)
    
    // Score Calculation Registers
    reg [2:0] die_counts [1:6]; // Count of 1s, 2s, ... 6s
    reg [3:0] distinct_count;
    reg has_3_kind, has_4_kind, has_5_kind;
    reg [5:0] score_val;
    reg [2:0] max_consecutive;
    reg [2:0] i, j; // General purpose indices
    reg [2:0] cat_type; // 0-5: ones to sixes, 6-12: special

    // Helper logic for DP access
    reg [11:0] dp_read_val;
    reg [11:0] dp_write_val;
    
    // Combination logic for DP read
    always @(*) begin
        if (state == UPDATE_DP) begin
            // Reading from dp[round_idx][dice_idx] to add score
            dp_read_val = dp[round_idx][dice_idx];
        end else if (state == ROUND_LOOP) begin
            // Reading from dp[round_idx][dice_idx] to check validity
            dp_read_val = dp[round_idx][dice_idx];
        end else begin
            dp_read_val = 0;
        end
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main FSM Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = RESET_DP;
                else next_state = IDLE;
            end
            RESET_DP: next_state = ROUND_LOOP;
            ROUND_LOOP: begin
                if (round_idx < NUM_ROUNDS) begin
                    // Check if valid starting point for this round
                    // A round uses up to 15 rolls (initial 5 + 5 + 5)
                    // But we are iterating all dice indices
                    // If current dice_idx allows a full round (needs at least 5 rolls)
                    // Actually, we process specific paths. 
                    // Algorithm: For every valid (round, dice_idx), try all strategies.
                    // If dice_idx + 5 > num_rolls, impossible, skip.
                    if (dice_idx + 5 > num_rolls) begin
                        next_state = NEXT_ROUND; // Skip this index
                    end else begin
                        next_state = ROLL_STRATEGY;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end
            ROLL_STRATEGY: begin
                // We iterate mask_iter_1 (0-31) and mask_iter_2 (0-31)
                // and sim_roll_cnt (0, 1, 2)
                // This state sets up initial hand
                next_state = ROLL_COMPUTE;
            end
            ROLL_COMPUTE: begin
                // Simulates one step of re-roll
                // If more steps needed, back to ROLL_COMPUTE, else to SCORE_CALC
                if (sim_roll_cnt < 2) begin
                    next_state = ROLL_COMPUTE; // Continue simulation chain
                end else begin
                    next_state = SCORE_CALC;
                end
            end
            SCORE_CALC: next_state = UPDATE_DP;
            UPDATE_DP: next_state = NEXT_ROUND;
            NEXT_ROUND: begin
                if (mask_iter_2 < 31) begin
                    next_state = ROLL_STRATEGY; // Next second re-roll mask
                end else if (mask_iter_1 < 31) begin
                    next_state = ROLL_STRATEGY; // Next first re-roll mask
                end else if (dice_idx < num_rolls - 5) begin
                    next_state = ROUND_LOOP; // Next dice index (loop nest order: inner masks, then dice_idx, then round)
                end else begin
                    next_state = ROUND_LOOP; // Next round (will trigger round increment logic below)
                end
            end
            DONE_STATE: next_state = DONE_STATE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            max_score <= 0;
            round_idx <= 0;
            dice_idx <= 0;
            mask_iter_1 <= 0;
            mask_iter_2 <= 0;
            sim_roll_cnt <= 0;
            best_score_current <= 0;
            // Clear DP (partially)
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                end
                RESET_DP: begin
                    // Initialize DP table to 0 (or invalid)
                    // Since we can't clear 13*65 regs in one cycle easily without blocking logic,
                    // we will rely on the fact that we only read valid data.
                    // Better: Initialize round_idx=0, dice_idx=0.
                    // We will use a flag or just rely on the max score accumulation logic.
                    // Actually, we must clear DP. 
                    // We'll use a separate counter for reset if strictly needed, 
                    // but here we can lazily reset or assume external reset.
                    // Let's use a clear loop disguised as iteration 0.
                    // For synthesis, we will explicitly clear the memory.
                    // Since we can't iterate 13*65 cycles here (latency constraint), 
                    // we will assert that DP is cleared at start of every round iteration.
                    // We will track reset status.
                    round_idx <= 0;
                    dice_idx <= 0;
                    mask_iter_1 <= 0;
                    mask_iter_2 <= 0;
                    best_score_current <= 0;
                    // Special flag to handle DP clear inside ROUND_LOOP or a separate state
                    // Let's add a helper variable to manage clearing.
                end
                
                ROUND_LOOP: begin
                    // If we just entered a new round, or finished all dice indices for a round
                    if (dice_idx >= num_rolls - 5) begin
                        round_idx <= round_idx + 1;
                        dice_idx <= 0;
                        mask_iter_1 <= 0;
                        mask_iter_2 <= 0;
                    end else begin
                        // Prepare for strategy evaluation
                        // Check validity: if dp[round_idx][dice_idx] is valid (or 0 if round 0)
                        // For round 0, dp is 0. For round > 0, we need valid value.
                        // We will rely on sequential execution order.
                        // Reset accumulators for this specific (round, dice_idx)
                        best_score_current <= 0; 
                    end
                    
                    // Handle clearing DP table logic implicitly here if needed
                    // Actually, to be safe with synthesizable block RAM inference:
                    // We will assume DP values are preserved from previous iterations.
                    // We start iteration from round 0, dice 0.
                end

                ROLL_STRATEGY: begin
                    // Reset simulation counters
                    sim_roll_cnt <= 0;
                    
                    // Extract initial 5 dice based on dice_idx
                    // Use 'i' as index for extraction
                    i <= 0;
                    // We need to setup the loop for extraction or do it combinatorially.
                    // Let's do extraction in a combinational block triggered by this state.
                end

                ROLL_COMPUTE: begin
                    // Logic depends on sim_roll_cnt
                    // 0: Initial hand loaded (handled by trigger)
                    // 1: Apply mask_iter_1
                    // 2: Apply mask_iter_2
                    
                    if (sim_roll_cnt == 0) begin
                        // Initial hand loaded (from combinational logic)
                        sim_roll_cnt <= 1;
                    end else if (sim_roll_cnt == 1) begin
                        // Apply mask_iter_1 to update temp_hand_1 from hand
                        // We use combinational logic to update 'hand' registers
                        sim_roll_cnt <= 2;
                    end else if (sim_roll_cnt == 2) begin
                        // Apply mask_iter_2 to update final_hand from temp_hand_1
                        // sim_roll_cnt increment happens in NEXT_STATE or here? 
                        // In NEXT_ROUND we handle loops.
                        // Here we just advance the simulation step.
                        sim_roll_cnt <= 3; // Mark as finished for NEXT_ROUND logic
                    end
                end

                SCORE_CALC: begin
                    // Calculate score for 'final_hand' for category 'round_idx'
                    // Logic is complex, we will do it here or delegate to combinational block
                    // We rely on combinational always block to compute 'score_val'
                    // If score_val > best_score_current, update best_score_current
                    if (score_val > best_score_current) begin
                        best_score_current <= score_val;
                    end
                end

                UPDATE_DP: begin
                    // Update dp[round_idx][dice_idx] with best_score_current + dp[round_idx-1][best_idx_prev]
                    // Wait, DP definition: dp[r][d] = max score from round r onwards starting with dice d?
                    // OR: dp[r][d] = max score from round 0 to r ending with dice d? 
                    // Standard DP for sequential tasks: dp[r][d] = max_score up to round r, consuming d rolls.
                    // But we iterate forward.
                    // Let's define: 
                    // For round k, we calculate the best score for this round.
                    // Then we need to add it to the best score of round k-1.
                    // In UPDATE_DP, we look back at previous round's best ending states.
                    // To simplify: We iterate all strategies for Round R.
                    // Each strategy consumes N rolls (5 to 15).
                    // We look at dp[R-1][start_idx] (where start_idx is dice_idx).
                    // Wait, the problem says: dp[round][dice_index] = max_score achievable.
                    // Usually means: dp[r][d] = max score for rounds 0..r using exactly d rolls? No, using dice up to d.
                    // Let's use: dp[r][d] = max score for rounds 0..r, ending with exactly d rolls used? 
                    // Or simpler: Since the input array is fixed, we are looking for the best path through the array.
                    // We are at Round R. We try all strategies starting at `dice_idx`.
                    // A strategy consumes X rolls (5 to 15).
                    // It produces a score S.
                    // The total score is S + dp[R-1][some_previous_idx].
                    // But we are iterating forward. 
                    // Let's refine the DP approach for synthesis:
                    // We are at state ROUND_LOOP for Round R.
                    // We iterate `dice_idx` (starting point of round R).
                    // For each `dice_idx`, we try all mask strategies.
                    // These strategies use rolls. They end at some `next_dice_idx`.
                    // We want to update: dp[R][next_dice_idx] = max(dp[R][next_dice_idx], dp[R-1][dice_idx] + score).
                    // This is a forward DP. 
                    // BUT, the requirement says: "dp[round][dice_index] = max_score achievable".
                    // And "Move to next round".
                    // Usually, this implies backward DP is cleaner: 
                    // dp[round][dice_idx] = max score from round 'round' to 13, starting at 'dice_idx'.
                    // Then answer is dp[0][0].
                    // Let's do Forward DP because we iterate round 0 -> 12.
                    // Let `dp[round][index]` be the max score to complete rounds 0..round ending exactly at 'index' rolls used.
                    // But we don't need exact index, just a starting point.
                    // Let's stick to: We want to compute `max_score` after processing all rounds.
                    // We need a buffer `prev_dp` and `curr_dp`.
                    // `prev_dp[d]` = max score for rounds 0..R-1 ending at usage d.
                    // `curr_dp[d]` = max score for rounds 0..R ending at usage d.
                    // We iterate d from 0 to num_rolls.
                    // If `prev_dp[d]` is valid (or 0 for R=0), we try all strategies starting at d.
                    // A strategy consumes k rolls (5 to 15). Result usage = d + k.
                    // Score = `prev_dp[d]` + hand_score.
                    // Update `curr_dp[d+k]`.
                    // This requires 2 DP arrays. Since we only need the final max score, we can optimize.
                    // However, to keep it simple and within 2000 cycles:
                    // Let's use: 
                    // dp[round][dice_idx] = max score for rounds 0..round-1, using dice up to dice_idx.
                    // No, that's confusing.
                    // Let's use the "backtracking" idea but forward execution:
                    // We are in Round R. 
                    // We want to know: if we start round R at `dice_idx`, what is the best total score?
                    // This requires knowing the best score of previous rounds.
                    // Let's store `best_score_so_far[dice_idx]` for the current round processing.
                    // Let `best_prev[dice_idx]` be the max score for rounds 0..R-1 that end exactly at `dice_idx`.
                    // For Round 0, `best_prev[0] = 0` (score 0, usage 0).
                    // For Round 0, usage `u`, score `s`, `best_curr[u] = s`.
                    // For Round 1, usage `u`, we look at `best_curr` from previous round.
                    // 
                    // Implementation Plan:
                    // Use a 1D array `score_dp[0:64]` initialized to 0 (or invalid).
                    // For round 0 to 12:
                    //   Use a temp array `next_score_dp` initialized to invalid.
                    //   Iterate `start_idx` 0 to 64:
                    //     If `score_dp[start_idx]` is valid (or 0 for round 0):
                    //       Try all strategies. (start_idx -> end_idx).
                    //       `total_score = score_dp[start_idx] + hand_score`.
                    //       `next_score_dp[end_idx] = max(next_score_dp[end_idx], total_score)`.
                    //   `score_dp = next_score_dp`.
                    // End.
                    // Result = max over `score_dp`.
                    
                    // Wait, the prompt asks for `dp[round][dice_index]`. 
                    // Let's use a memory `dp_mem[0:64]` to store the best scores for the *previous* round.
                    // And a `dp_next_mem[0:64]` for the current round.
                    // This fits synthesizeable logic.
                    // 
                    // So, in UPDATE_DP state:
                    // We have just computed `best_score_current` (hand score) for a specific strategy.
                    // We need to add this to the previous round's best score at `dice_idx`.
                    // Where is the previous round's score stored? 
                    // We need to read `dp_prev[dice_idx]`.
                    // Then write `dp_curr[next_idx] = max(dp_curr[next_idx], dp_prev[dice_idx] + best_score_current)`.
                    // 
                    // Constraint: We iterate `dice_idx` (start) inside `round_idx`.
                    // We need to know `next_idx` (end) of the strategy.
                    // `next_idx` = `dice_idx` + rolls consumed.
                    // 
                    // In UPDATE_DP:
                    // `val_add = dp_prev[dice_idx]`.
                    // If round_idx == 0, `val_add = 0`.
                    // `new_score = val_add + best_score_current`.
                    // `target_idx = dice_idx + rolls_consumed`.
                    // `dp_curr[target_idx] = max(dp_curr[target_idx], new_score)`.
                    // 
                    // We need `rolls_consumed`. We calculate it during simulation.
                    // Initial 5 dice always used (dice_idx to dice_idx+4).
                    // Re-rolls: we need to fetch new dice from `dice_in`.
                    // The array `dice_in` is provided.
                    // We need to track which indices are used for re-rolls.
                    // For a strategy (mask1, mask2):
                    // Initial: dice_idx ... dice_idx+4.
                    // Re-roll 1: keep some. Need to fill 5-kept. Fetch from `dice_in` starting `dice_idx+5`.
                    // Re-roll 2: keep some. Fetch from `dice_in` starting `dice_idx+5 + kept_count_1`.
                    // 
                    // Total rolls used = 5 + (5 - popcount(mask1)) + (5 - popcount(mask2)).
                    // Wait, mask bits: 1=keep, 0=replace.
                    // popcount(mask) = kept.
                    // rolls_added_1 = 5 - popcount(mask1).
                    // rolls_added_2 = 5 - popcount(mask2).
                    // Total used = 5 + rolls_added_1 + rolls_added_2.
                    // But we must ensure we don't exceed `num_rolls`.
                    // 
                    // In UPDATE_DP:
                    // Calculate `used = 5 + (5 - pc1) + (5 - pc2)`.
                    // `target_idx = dice_idx + used`.
                    // Only update if `target_idx <= num_rolls`.
                    // 
                    // We need `dp_prev` and `dp_curr` arrays.
                    // We will infer 2 memories.
                    // However, we need to initialize `dp_curr` to invalid (e.g. 13'h1FFF) at start of each round.
                    // And `dp_prev` needs to be read.
                    // 
                    // We'll handle array management in IDLE/RESET_DP/ROUND_LOOP.
                    // In UPDATE_DP, we perform the update.
                    // 
                    // So, `dp_prev` is the result of the previous round. `dp_curr` is being built.
                    // 
                    // Revisions to UPDATE_DP:
                    // 1. Calculate `popcount` of `mask_iter_1` and `mask_iter_2`.
                    // 2. `rolls_used = 5 + (5 - pc1) + (5 - pc2)`.
                    // 3. `start_score = (round_idx == 0) ? 0 : dp_prev[dice_idx]`.
                    //    (Assuming dp_prev is initialized to invalid except `dp_prev[0]=0` for round 0? No, dp_prev is result of round r-1).
                    //    Actually, dp_prev stores max score ending at that index.
                    //    So `start_score = dp_prev[dice_idx]`.
                    //    For round 0, `dp_prev` should be initialized so that `dp_prev[0] = 0` (score 0, usage 0). Others invalid.
                    // 4. `total_score = start_score + best_score_current`.
                    // 5. `target = dice_idx + rolls_used`.
                    // 6. `dp_curr[target] = max(dp_curr[target], total_score)`.
                    // 
                    // We need a way to read `dp_prev[dice_idx]`. 
                    // We can use a combinational block to read `dp_prev` whenever `dice_idx` changes or state is ROLL_STRATEGY.
                    // 
                    // Memory Implementation:
                    // `reg [11:0] dp_prev [0:64];`
                    // `reg [11:0] dp_curr [0:64];`
                    // `reg [11:0] dp_temp [0:64];` for swapping.
                    // 
                    // To initialize `dp_curr` to invalid for new round:
                    // We can use a `clear_dp_curr` flag in `ROUND_LOOP` state.
                    // Since we iterate `dice_idx` sequentially in `ROUND_LOOP`, we can clear `dp_curr[dice_idx]` just before we start processing strategies for that `dice_idx`.
                    // Wait, `dp_curr` accumulates. We might write to `target` indices that are far ahead.
                    // So we must clear `dp_curr` entirely before starting a new round.
                    // We can do this by having a dedicated reset cycle for `dp_curr`.
                    // Or, we can use a `valid` bit for each entry. 
                    // `reg [12:0] dp_curr [0:64];` where MSB is valid bit.
                    // 
                    // Let's refine the ROUND_LOOP and UPDATE_DP logic.
                    // 
                    // ROUND_LOOP:
                    // If we start a new round (flag `new_round_flag`), we need to clear `dp_curr`.
                    // We can do this by iterating a counter `clear_idx` from 0 to 64 in `ROUND_LOOP` or a separate state.
                    // Given 2000 cycles, we can afford some overhead.
                    // Let's add a state `INIT_ROUND` between `RESET_DP` and `ROUND_LOOP`.
                    // 
                    // Okay, let's adjust the state machine slightly.
                    // 
                    // NEW STATES:
                    // 0: IDLE
                    // 1: RESET_DP (Init dp_prev[0]=0, others invalid)
                    // 2: INIT_ROUND (Clear dp_curr for current round_idx)
                    // 3: ROUND_LOOP (Iterate dice_idx)
                    // 4: ROLL_STRATEGY (Setup masks)
                    // 5: ROLL_COMPUTE (Simulate rolls)
                    // 6: SCORE_CALC
                    // 7: UPDATE_DP (Update dp_curr)
                    // 8: NEXT_ROUND (Swap buffers, inc round)
                    // 9: DONE
                    
                    // Let's implement this logic.
                end
                
                NEXT_ROUND: begin
                    // Swap dp_curr to dp_prev for next round
                    // We can do this by swapping pointers or copying.
                    // Since we can't easily swap arrays in SV without loops, we might need to copy.
                    // Or just use `dp_valid_curr` and `dp_valid_prev` flags.
                    // Actually, let's use a single array `dp_score[0:64]`.
                    // For Round N, we read from `dp_score` (which holds results for Round N-1).
                    // We calculate new scores `val = dp_score[dice_idx] + ...`.
                    // We need to store these new scores somewhere before updating `dp_score`.
                    // Because we might update an index that we haven't read yet (forward dependency).
                    // Example: read index 0, update index 10. Read index 5, update index 10.
                    // We can't overwrite `dp_score` in place if we iterate forward.
                    // 
                    // Solution: 
                    // We iterate `dice_idx` from 0 to 64.
                    // We accumulate updates into `dp_next[0:64]` (cleared at start of round).
                    // At the end of the round (when `dice_idx` finishes), we copy `dp_next` back to `dp_score`.
                    // OR, we just treat `dp_score` as `dp_prev` and `dp_next` as `dp_curr`.
                    // At `NEXT_ROUND` state: `dp_score = dp_next`. Clear `dp_next`.
                    // 
                    // So, we need `dp_score` (the persistent DP table) and `dp_buffer` (accumulator for current round).
                    // 
                    // In `UPDATE_DP` (inside Round N loop):
                    // Read `dp_score[dice_idx]`. (This holds result of Round N-1).
                    // Compute `new_val = dp_score[dice_idx] + score`.
                    // Write to `dp_buffer[target_idx] = max(dp_buffer[target_idx], new_val)`.
                    // 
                    // In `NEXT_ROUND`:
                    // Copy `dp_buffer` to `dp_score`.
                    // Clear `dp_buffer`.
                    // Move to next round.
                    // 
                    // This is robust.
                    // 
                    // We need to handle the copying of `dp_buffer` to `dp_score`. 
                    // Since we have 65 entries, we can do it in 1 cycle if we write to `dp_score` in `UPDATE_DP`? No.
                    // We must copy at the end of the round.
                    // We can add a `COPY_DP` state after `NEXT_ROUND` or combine them.
                    // 
                    // State Sequence:
                    // `NEXT_ROUND` (end of inner loops): 
                    //   `copy_idx <= 0;` 
                    //   `next_state = COPY_DP;`
                    // `COPY_DP`:
                    //   `dp_score[copy_idx] <= dp_buffer[copy_idx];`
                    //   `dp_buffer[copy_idx] <= 0;` (or invalid)
                    //   `copy_idx++`. If `copy_idx <= 64`, repeat. Else go to `ROUND_LOOP` (which handles round increment).
                    // 
                    // But wait, `dp_score` is the memory we read from in `UPDATE_DP`.
                    // If we update `dp_score` at the end of the round, it's ready for Round N+1.
                    // 
                    // Handling `start` signal: `dp_score[0] = 0` initially.
                    // 
                    // 
                end

                DONE_STATE: begin
                    // Final max score extraction
                    // We need to find max over `dp_score` (which holds result of Round 12).
                    // We can do this during `COPY_DP` for the last round or add a specific state.
                    // Let's add a `FINAL_MAX` state.
                    done <= 1;
                    // `max_score` is updated in a combinational block or a dedicated state.
                    // Let's use a state `EXTRACT_MAX` before `DONE_STATE`.
                end
            endcase
        end
    end

    // --- Combinational Logic for Hand Evaluation & Score ---
    // This block computes score_val for `final_hand` and `round_idx`.
    // It also computes `rolls_consumed` for UPDATE_DP.
    // It also handles DP memory reads.
    
    // Registers for combinational extraction
    reg [11:0] dp_score_read_val;
    reg [11:0] dp_buffer_read_val;
    reg [11:0] current_prev_score;
    reg [4:0] pop1, pop2;
    reg [4:0] rolls_used;
    reg [4:0] target_idx_temp;
    reg [11:0] new_total_score;
    reg [11:0] buffer_val_at_target;
    reg [11:0] best_max_score;
    
    // We need to infer block RAMs for `dp_score` and `dp_buffer`.
    // `dp_score` is read in UPDATE_DP based on `dice_idx`.
    // `dp_buffer` is read in UPDATE_DP based on `target_idx_temp` (to do max).
    // `dp_buffer` is written in UPDATE_DP.
    // `dp_score` is written in COPY_DP (or initial setup).
    
    // Memory Instances (Inferred)
    reg [11:0] dp_score [0:64];
    reg [11:0] dp_buffer [0:64];
    
    // Memory Read Logic (Combinational or Registered)
    // To read dp_score[dice_idx], we need to trigger read.
    // Let's use registered outputs for memory reads to be safe.
    reg [11:0] dp_score_rdata;
    reg [11:0] dp_buffer_rdata;
    
    always @(posedge clk) begin
        // Read dp_score
        if (state == ROLL_STRATEGY || state == UPDATE_DP) begin
            // We need to read `dp_score[dice_idx]` for Round > 0.
            dp_score_rdata <= dp_score[dice_idx];
        end
        // Read dp_buffer for max check
        if (state == UPDATE_DP) begin
            dp_buffer_rdata <= dp_buffer[target_idx_temp];
        end
    end
    
    // Memory Write Logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine logic mainly
        end else begin
            // Write dp_score (from COPY_DP or Initialization)
            if (state == COPY_DP) begin
                dp_score[copy_idx] <= dp_buffer[copy_idx];
                dp_buffer[copy_idx] <= 0; // Clear buffer at same time? Or separate clear.
            end else if (state == RESET_DP) begin
                // Initialize dp_score[0] = 0, others invalid (e.g. 13'h1FFF)
                dp_score[0] <= 0;
                // We can clear others lazily or explicitly. 
                // Let's rely on valid bit or explicit clearing.
                // To be safe, we should clear all.
                // We'll use a clear loop in RESET_DP state.
            end else if (state == UPDATE_DP) begin
                // Write to dp_buffer[target_idx] = max(dp_buffer[target_idx], new_total_score)
                if (new_total_score > dp_buffer_rdata) begin
                    dp_buffer[target_idx_temp] <= new_total_score;
                end
            end
        end
    end
    
    // Helper logic for Clearing and Copying
    reg [6:0] copy_idx;
    always @(posedge clk) begin
        if (!rst_n) begin
            copy_idx <= 0;
        end else begin
            if (state == RESET_DP) begin
                // Start clearing dp_score and dp_buffer
                copy_idx <= 0;
            end else if (state == CLEAR_MEMORY) begin
                if (copy_idx <= 64) begin
                    dp_score[copy_idx] <= 13'h1FFF; // Invalid (max score is 1000)
                    dp_buffer[copy_idx] <= 13'h1FFF;
                    copy_idx <= copy_idx + 1;
                end
            end else if (state == INIT_ROUND) begin
                // Clear dp_buffer for the new round
                // We can reuse copy_idx logic or dedicated counter
                if (copy_idx <= 64) begin
                    dp_buffer[copy_idx] <= 13'h1FFF;
                    copy_idx <= copy_idx + 1;
                end
            end else if (state == COPY_DP) begin
                // We just handled the write in the combinational block above?
                // No, we need a counter for COPY_DP.
                // Let's use `copy_idx` for COPY_DP too.
                // If we are in COPY_DP, we are updating one index per cycle.
                // But `NEXT_ROUND` triggers COPY_DP. 
                // Wait, `UPDATE_DP` updates `dp_buffer`.
                // At the end of round, we need to move `dp_buffer` -> `dp_score`.
                // We can add a `COPY_STATE`.
            end else if (state == FINAL_MAX) begin
                 // Max extraction logic (comb or seq)
                 // We will update `max_score` in the FINAL_MAX state logic below.
            end
        end
    end

    // Re-defining states to be cleaner for the implementation
    // State encoding (revised)
    localparam S_IDLE = 0;
    localparam S_RESET = 1;
    localparam S_CLEAR = 2; // Clear memories
    localparam S_INIT_ROUND = 3; // Prepare dp_buffer for new round
    localparam S_ROUND_LOOP = 4; // Iterate dice_idx
    localparam S_STRATEGY = 5; // Setup masks
    localparam S_SIMULATE = 6; // Simulate rolls (step by step)
    localparam S_SCORE = 7; // Calc score
    localparam S_UPDATE = 8; // Update dp_buffer
    localparam S_NEXT_IDX = 9; // Increment dice_idx or strategy masks
    localparam S_COPY = 10; // Copy dp_buffer -> dp_score
    localparam S_FINAL = 11; // Extract max score
    localparam S_DONE = 12;

    // Update state registers (re-mapped)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else case (state)
            S_IDLE: if (start) state <= S_RESET;
            S_RESET: state <= S_CLEAR;
            S_CLEAR: if (copy_idx > 64) state <= S_INIT_ROUND;
            S_INIT_ROUND: if (copy_idx > 64) state <= S_ROUND_LOOP;
            S_ROUND_LOOP: begin
                if (round_idx >= NUM_ROUNDS) state <= S_FINAL; // All rounds done
                else if (dice_idx + 5 > num_rolls) state <= S_NEXT_IDX; // Skip invalid start
                else state <= S_STRATEGY;
            end
            S_STRATEGY: state <= S_SIMULATE;
            S_SIMULATE: begin
                // sim_roll_cnt: 0->1 (setup), 1->2 (apply mask1), 2->3 (apply mask2)
                // Actually, logic is:
                // 0: Load Initial. Then go to SIMULATE (or separate state). 
                // Let's keep it simple: 
                // S_STRATEGY sets up `hand` from `dice_in`. 
                // Then S_SIMULATE steps.
                // If sim_cnt == 0: Apply Mask1 -> sim_cnt 1. If mask1 is 'all keep', maybe skip? No, we iterate all masks.
                // We'll do: S_STRATEGY prepares `work_hand`. 
                // S_SIMULATE executes one re-roll step.
                // If sim_cnt < 2, stay in S_SIMULATE (or loop). 
                // Let's use sim_cnt as steps: 0 (initial), 1 (re-roll 1), 2 (re-roll 2).
                // When we enter S_STRATEGY, we load initial.
                // Then we go to S_SIMULATE.
                // In S_SIMULATE: if sim_cnt == 1, apply mask1. If sim_cnt == 2, apply mask2.
                // But we need to iterate masks.
                // Sequence: 
                // 1. S_STRATEGY: Load initial hand. Set mask_iter_1, mask_iter_2. Reset sim_cnt=1.
                // 2. S_SIMULATE: 
                //    - If sim_cnt == 1: Apply mask_iter_1. Update hand. Increment sim_cnt. Stay in S_SIMULATE? No, go to S_SIMULATE for next step.
                //    - If sim_cnt == 2: Apply mask_iter_2. Update hand. Then go to S_SCORE.
                //    - Wait, we need to handle the "Initial" state vs "Re-roll" state.
                //    - Let's use `sim_roll_cnt`: 0 (Initial), 1 (1st re-roll), 2 (2nd re-roll).
                //    - In S_STRATEGY: `sim_roll_cnt` = 0. We prepare `hand` from `dice_in` (dice_idx offset). Then we immediately transition to next state to apply re-rolls.
                //    - In S_SIMULATE: `sim_roll_cnt` increments.
                //      - If `sim_roll_cnt` == 1: Apply `mask_iter_1`. Fetch new dice.
                //      - If `sim_roll_cnt` == 2: Apply `mask_iter_2`. Fetch new dice.
                //    - When `sim_roll_cnt` reaches 3, we are done. 
                //    - So, S_STRATEGY sets up initial `hand` and `sim_roll_cnt = 0`.
                //    - Then S_SIMULATE increments `sim_roll_cnt`.
                //      - If `sim_roll_cnt` == 1 or 2: Apply mask. Update hand. Stay in S_SIMULATE.
                //      - If `sim_roll_cnt` > 2: Go to S_SCORE.
                //      - Wait, we need to handle the loop.
                //      - Let's just use S_SIMULATE to increment `sim_roll_cnt` and perform update.
                //      - If `sim_roll_cnt` <= 2, go back to S_SIMULATE. Else S_SCORE.
                //      - But we need to fetch dice. 
                //      - Let's do: S_STRATEGY -> S_SIMULATE.
                //      - S_SIMULATE: `sim_roll_cnt` increments. 
                //        - If `sim_roll_cnt` == 1: Apply mask 1.
                //        - If `sim_roll_cnt` == 2: Apply mask 2.
                //        - If `sim_roll_cnt` == 3: Go to S_SCORE.
                //        - Else go to S_SIMULATE.
                //      - BUT, we must fetch dice for re-rolls. We need offset.
                //      - Offset calculation: 
                //        - Initial: dice_idx + 0 to +4.
                //        - Re-roll 1: dice_idx + 5. (Fixed start? No, usually variable).
                //        - Wait, "Maximum 65 input dice rolls available". "Parse input dice array sequentially".
                //        - It seems `dice_in` is a big stream.
                //        - Round 1 uses `dice_in[0..14]` (max). 
                //        - Round 2 uses `dice_in[15..]`? No.
                //        - The problem implies we pick a subset of the `dice_in` stream.
                //        - "For each round, consider all possible re-roll strategies".
                //        - This implies we look at the `dice_in` stream.
                //        - Initial roll: `dice_in[dice_idx]` to `dice_idx+4`.
                //        - Re-roll 1: We need `dice_in` to provide replacements. Where from?
                //        - Usually, the next available rolls. 
                //        - So, if we keep `k` dice, we need `5-k` new ones.
                //        - They come from `dice_idx + 5 + (previous replacements used)`.
                //        - This makes the indexing complicated for a simple DP.
                //        - Let's assume: 
                //          - Initial: `dice_idx` to `dice_idx+4`.
                //          - Re-roll 1: always takes from `dice_idx+5` to `dice_idx+9` (if needed).
                //          - Re-roll 2: always takes from `dice_idx+10` to `dice_idx+14`.
                //        - This fixes the maximum usage to 15 per round.
                //        - And allows us to calculate target index easily: `dice_idx + 15`.
                //        - But the prompt says "sequential" and "up to 3 rolls". 
                //        - Usually, you don't waste rolls if you don't use them. 
                //        - If you keep all 5 in first re-roll, you don't consume extra rolls.
                //        - So, `rolls_consumed = 5 + (5 - kept1) + (5 - kept2)`.
                //        - Where do the new dice come from? 
                //        - They come from the stream after the initial 5.
                //        - So: 
                //          - Initial: idx, idx+1, idx+2, idx+3, idx+4.
                //          - If we replace `r1` dice in re-roll 1: we use `idx+5` to `idx+4+r1`.
                //          - If we replace `r2` dice in re-roll 2: we use `idx+5+r1` to `idx+4+r1+r2`.
                //        - This is the "Sequential" constraint.
                //        - This means we cannot just assume fixed offsets for re-rolls. We must track how many we consumed.
                //        - In `S_STRATEGY`: we know `mask_iter_1` and `mask_iter_2`. We can compute `kept1`, `kept2`. 
                //        - `r1 = 5 - kept1`, `r2 = 5 - kept2`.
                //        - Total used = 5 + r1 + r2.
                //        - So `target_idx = dice_idx + 5 + r1 + r2`.
                //        - For simulation, we need to know where to fetch dice.
                //        - Let's pre-calculate the fetch indices or offsets.
                //        - We can compute `r1` and `r2` combinatorially.
                //        - `offset_1 = 5`.
                //        - `offset_2 = 5 + r1`.
                //        - In `S_SIMULATE`: 
                //          - If `sim_cnt` == 1: we need `r1` dice. We fetch them from `dice_in[dice_idx+5 ... dice_idx+4+r1]`.
                //          - But we need to map these to the 5 dice positions.
                //          - Positions to fill are where mask bit is 0.
                //          - This is getting complex to do in a single state.
                //        - Let's add a helper combinational block that computes the "Simulated Hand".
                //        - Given `base_idx`, `mask1`, `mask2`, `sim_step` (0,1,2), output the 5 dice values.
                //        - 
                //        - We can do this sequentially:
                //          - `sim_hand` starts as `dice_in[base_idx ... base_idx+4]`.
                //          - `curr_idx = base_idx + 5`.
                //          - Step 1: Apply `mask1`. For bits 0, fetch `dice_in[curr_idx]`. Increment `curr_idx`.
                //          - Step 2: Apply `mask2`. For bits 0, fetch `dice_in[curr_idx]`.
                //        - 
                //        - In `S_STRATEGY`: 
                //          - `hand_sim[0..4] <= dice_in[dice_idx .. dice_idx+4]`.
                //          - `fetch_ptr <= dice_idx + 5`.
                //          - `mask_work <= mask_iter_1`.
                //          - `sim_cnt <= 0`.
                //        - In `S_SIMULATE`: 
                //          - `sim_cnt++`.
                //          - If `sim_cnt == 1`: 
                //             - Update `hand_sim` using `mask_iter_1` and `dice_in[fetch_ptr ..]`.
                //             - Count replaced dice `r1`.
                //             - `fetch_ptr += r1`.
                //             - Stay in `S_SIMULATE`.
                //          - If `sim_cnt == 2`: 
                //             - Update `hand_sim` using `mask_iter_2` and `dice_in[fetch_ptr ..]`.
                //             - Stay in `S_SIMULATE`.
                //          - If `sim_cnt == 3`: Go to `S_SCORE`.
                //        - This works! 
                //        - We need `r1` count (popcount of `~mask_iter_1`).
                //        - 
                state <= S_SIMULATE;
            end
            S_SIMULATE: begin
                // Logic depends on sim_roll_cnt
                // sim_roll_cnt is incremented in this block or next state?
                // Let's increment it here.
                if (sim_roll_cnt < 2) begin
                    sim_roll_cnt <= sim_roll_cnt + 1;
                    state <= S_SIMULATE;
                end else begin
                    state <= S_SCORE;
                end
            end
            S_SCORE: state <= S_UPDATE;
            S_UPDATE: state <= S_NEXT_IDX;
            S_NEXT_IDX: begin
                // Handle loop nesting: Masks -> dice_idx -> Round
                if (mask_iter_2 < 31) begin
                    mask_iter_2 <= mask_iter_2 + 1;
                    state <= S_STRATEGY;
                end else if (mask_iter_1 < 31) begin
                    mask_iter_1 <= mask_iter_1 + 1;
                    mask_iter_2 <= 0;
                    state <= S_STRATEGY;
                end else begin
                    mask_iter_1 <= 0;
                    mask_iter_2 <= 0;
                    if (dice_idx < num_rolls - 5) begin
                        dice_idx <= dice_idx + 1;
                        state <= S_ROUND_LOOP;
                    end else begin
                        dice_idx <= 0;
                        round_idx <= round_idx + 1;
                        state <= S_INIT_ROUND; // Prepare for next round
                    end
                end
            end
            S_INIT_ROUND: begin
                // Clear dp_buffer for next round accumulation
                if (copy_idx > 64) begin
                    copy_idx <= 0;
                    state <= S_ROUND_LOOP;
                end else begin
                    copy_idx <= copy_idx + 1;
                end
            end
            S_COPY: begin
                // Copy dp_buffer to dp_score after round finishes? 
                // No, we do this in S_INIT_ROUND or a separate step.
                // Wait, we need to preserve `dp_score` (results of R-1) while building `dp_buffer` (results of R).
                // At the end of Round R (when dice_idx loops finish), we need to swap.
                // So, `S_NEXT_IDX` when `dice_idx` loop finishes, we go to `S_SWAP`.
                // `S_SWAP` (which is `S_INIT_ROUND` maybe?) copies `dp_buffer` to `dp_score`.
                // But `S_INIT_ROUND` is called at the *start* of round N to clear `dp_buffer`.
                // We need: 
                // 1. Copy `dp_buffer` -> `dp_score` (End of Round N-1).
                // 2. Clear `dp_buffer` (Start of Round N).
                // 3. Process Round N.
                // This suggests a `S_FINALIZE_ROUND` state.
                // Let's modify `S_NEXT_IDX` logic.
                // 
                // Revised `S_NEXT_IDX`:
                // ...
                // `else` (dice_idx finished): 
                //   `state <= S_SWAP`.
                // 
                // `S_SWAP`: 
                //   `dp_score[copy_idx] <= dp_buffer[copy_idx]`.
                //   `dp_buffer[copy_idx] <= 13'h1FFF`.
                //   `copy_idx++`. Loop until 64.
                //   Then go to `S_INIT_ROUND`? No, `S_INIT_ROUND` was for clearing `dp_buffer` *before* we start.
                //   Here, `S_SWAP` does the copy AND clear in one go.
                //   Wait, if we `copy_idx` loop, we can't do it in 1 cycle. 
                //   So we need a state `S_COPY_LOOP`.
                //   
                //   Sequence for Round 0 -> 1:
                //   Finish Round 0 iteration (dice_idx). Go to `S_COPY_LOOP`.
                //   `S_COPY_LOOP`: Copy `dp_buffer` to `dp_score` (and clear `dp_buffer`).
                //   Once done, go to `S_ROUND_LOOP` (Round 1).
                //   
                //   What about Round 0 start? `dp_score` initialized with `dp_score[0]=0`.
                //   `dp_buffer` needs to be cleared. 
                //   `S_RESET`: Init `dp_score`. `dp_score[0]=0`. Others invalid.
                //   `S_INIT_ROUND`: Clear `dp_buffer` (or `S_CLEAR` does it).
                //   
                //   Let's refine:
                //   `S_RESET`: `dp_score[0] <= 0`. `dp_score[1..64] <= invalid`.
                //   `S_CLEAR`: Clear `dp_buffer` (all invalid).
                //   `S_ROUND_LOOP` (Round 0): Process strategies. Update `dp_buffer`.
                //   `S_NEXT_IDX` (Loop finish): `state <= S_COPY`.
                //   `S_COPY`: 
                //     `dp_score[copy_idx] <= dp_buffer[copy_idx]`.
                //     `dp_buffer[copy_idx] <= invalid` (prepare for next round).
                //     `copy_idx++`. If <=64, repeat `S_COPY`. Else `round_idx++`, `dice_idx=0`, `state <= S_ROUND_LOOP`.
                //     Note: `S_COPY` clears `dp_buffer` simultaneously as it copies to `dp_score`.
                //     This prepares `dp_score` for Round N+1 (read) and `dp_buffer` for Round N+1 (write).
                //     Wait, `dp_score` is read in `S_UPDATE` (inside round). 
                //     In Round N, we read `dp_score` (which holds results of Round N-1).
                //     So `S_COPY` happens *after* Round N-1 finishes, and *before* Round N starts.
                //     
                //     But we are iterating Round 0. 
                //     Round 0: Reads `dp_score` (initialized). Writes `dp_buffer`.
                //     Round 0 ends. `S_COPY`: `dp_score = dp_buffer`. `dp_buffer = clear`.
                //     Round 1: Reads `dp_score` (results of 0). Writes `dp_buffer` (results of 1).
                //     
                //     Yes, this works.
                state <= S_COPY;
                copy_idx <= 0;
            end
            S_COPY: begin
                if (copy_idx < 64) begin
                    copy_idx <= copy_idx + 1;
                end else begin
                    round_idx <= round_idx + 1;
                    dice_idx <= 0;
                    state <= S_ROUND_LOOP;
                end
            end
            S_FINAL: begin
                // Extract max from `dp_score` (which holds result of last round)
                // We need to iterate `dice_idx` to find max.
                // Let's use `copy_idx` as iterator.
                if (copy_idx == 0) begin
                    max_score <= 0;
                    copy_idx <= copy_idx + 1;
                end else if (copy_idx <= 64) begin
                    if (dp_score[copy_idx] < 13'h1FFF && dp_score[copy_idx] > max_score)
                        max_score <= dp_score[copy_idx];
                    copy_idx <= copy_idx + 1;
                end else begin
                    state <= S_DONE;
                end
            end
            S_DONE: begin
                done <= 1;
            end
        endcase
    end

    // --- Combinational Logic for Simulation, Score, Update ---
    
    // Simulation Logic
    // We need to maintain `hand_sim[0..4]` registers.
    // And `fetch_ptr` register.
    reg [2:0] hand_sim [0:4];
    reg [6:0] fetch_ptr;
    reg [4:0] kept1, kept2;
    
    // Combinational calculation of new hand based on mask
    // We need to know `sim_roll_cnt` to know which mask to use.
    // We need `mask_iter_1` and `mask_iter_2`.
    // We need to know `kept1` (popcount of mask_iter_1) to advance `fetch_ptr`.
    
    always @(*) begin
        kept1 = 0;
        kept2 = 0;
        // Calculate popcounts
        for (int k = 0; k < 5; k++) begin
            if (mask_iter_1[k]) kept1 = kept1 + 1;
            if (mask_iter_2[k]) kept2 = kept2 + 1;
        end
    end

    // Hand Update Logic (Sequential)
    // Since we need to update `hand_sim` based on `fetch_ptr`, we do this in sequential logic.
    // We trigger this update in `S_STRATEGY` (initial) and `S_SIMULATE` (re-rolls).
    always @(posedge clk) begin
        if (state == S_STRATEGY) begin
            // Load Initial Hand
            hand_sim[0] <= dice_in[dice_idx];
            hand_sim[1] <= dice_in[dice_idx+1];
            hand_sim[2] <= dice_in[dice_idx+2];
            hand_sim[3] <= dice_in[dice_idx+3];
            hand_sim[4] <= dice_in[dice_idx+4];
            fetch_ptr <= dice_idx + 5;
            sim_roll_cnt <= 0; // 0 means "Initial Hand Loaded"
        end else if (state == S_SIMULATE) begin
            // Increment step
            // sim_roll_cnt was 0 (initial), now becomes 1 (apply mask1)
            // or was 1 (mask1 applied), now becomes 2 (apply mask2)
            if (sim_roll_cnt == 0) begin
                // Apply Mask 1 (mask_iter_1)
                if (!mask_iter_1[0]) begin hand_sim[0] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                if (!mask_iter_1[1]) begin hand_sim[1] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                if (!mask_iter_1[2]) begin hand_sim[2] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                if (!mask_iter_1[3]) begin hand_sim[3] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                if (!mask_iter_1[4]) begin hand_sim[4] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                sim_roll_cnt <= 1;
            end else if (sim_roll_cnt == 1) begin
                // Apply Mask 2 (mask_iter_2)
                if (!mask_iter_2[0]) begin hand_sim[0] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                if (!mask_iter_2[1]) begin hand_sim[1] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                if (!mask_iter_2[2]) begin hand_sim[2] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                if (!mask_iter_2[3]) begin hand_sim[3] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                if (!mask_iter_2[4]) begin hand_sim[4] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                sim_roll_cnt <= 2;
            end
        end
    end

    // Score Calculation Combinational Block
    // Input: `hand_sim`, `round_idx`
    // Output: `score_val` (6-bit internal, 12-bit external)
    // Registers for counting
    reg [3:0] cnt [1:6];
    reg [2:0] val;
    reg [4:0] total_sum;
    
    always @(*) begin
        // Reset counters
        for (int i = 1; i <= 6; i++) cnt[i] = 0;
        total_sum = 0;
        
        // Count dice
        for (int i = 0; i < 5; i++) begin
            val = hand_sim[i];
            if (val >= 1 && val <= 6) begin
                cnt[val] = cnt[val] + 1;
                total_sum = total_sum + val;
            end
        end
        
        score_val = 0;
        
        // Categories
        if (round_idx < 6) begin
            // Ones to Sixes
            score_val = cnt[round_idx + 1] * (round_idx + 1);
        end else begin
            case (round_idx)
                6: // 3 of a kind
                    if (cnt[1] >= 3 || cnt[2] >= 3 || cnt[3] >= 3 || cnt[4] >= 3 || cnt[5] >= 3 || cnt[6] >= 3)
                        score_val = total_sum;
                7: // 4 of a kind
                    if (cnt[1] >= 4 || cnt[2] >= 4 || cnt[3] >= 4 || cnt[4] >= 4 || cnt[5] >= 4 || cnt[6] >= 4)
                        score_val = total_sum;
                8: // Full House
                    if ((cnt[1]==3||cnt[2]==3||cnt[3]==3||cnt[4]==3||cnt[5]==3||cnt[6]==3) &&
                        (cnt[1]==2||cnt[2]==2||cnt[3]==2||cnt[4]==2||cnt[5]==2||cnt[6]==2))
                        score_val = 25;
                9: // Small Straight
                    // Check 4 consecutive
                    if ((cnt[1]>=1 && cnt[2]>=1 && cnt[3]>=1 && cnt[4]>=1) ||
                        (cnt[2]>=1 && cnt[3]>=1 && cnt[4]>=1 && cnt[5]>=1) ||
                        (cnt[3]>=1 && cnt[4]>=1 && cnt[5]>=1 && cnt[6]>=1))
                        score_val = 30;
                10: // Long Straight
                    if ((cnt[1]==1 && cnt[2]==1 && cnt[3]==1 && cnt[4]==1 && cnt[5]==1) ||
                        (cnt[2]==1 && cnt[3]==1 && cnt[4]==1 && cnt[5]==1 && cnt[6]==1))
                        score_val = 40;
                11: // Chance
                    score_val = total_sum;
                12: // Yahtzee
                    if (cnt[1]==5 || cnt[2]==5 || cnt[3]==5 || cnt[4]==5 || cnt[5]==5 || cnt[6]==5)
                        score_val = 50;
            endcase
        end
    end

    // Update Logic (S_UPDATE state calculations)
    // We need to calculate target index and new score.
    always @(posedge clk) begin
        if (state == S_UPDATE) begin
            // 1. Calculate rolls consumed
            // kept1, kept2 already combinational
            // rolls_consumed = 5 + (5 - kept1) + (5 - kept2)
            rolls_used <= 5 + (5 - kept1) + (5 - kept2);
            
            // 2. Get Previous Score from dp_score
            // `dp_score_rdata` is registered read of `dp_score[dice_idx]`
            // If round_idx == 0, prev score is 0 (unless we initialized dp_score[0] = 0)
            // For round 0, dp_score holds init value (0 at 0, invalid elsewhere). 
            // For round > 0, dp_score holds results of round-1.
            current_prev_score <= (round_idx == 0) ? ((dice_idx == 0) ? 0 : 13'h1FFF) : dp_score_rdata;
        end
    end
    
    // Combinational logic for S_UPDATE (to be ready for write in S_NEXT_IDX or similar)
    always @(*) begin
        target_idx_temp = dice_idx + rolls_used;
        
        if (current_prev_score < 13'h1FFF && target_idx_temp <= num_rolls) begin
            new_total_score = current_prev_score + score_val;
            // We need to read dp_buffer[target_idx_temp] to do max check.
            // But reading dp_buffer is sequential (registered) in the memory block.
            // So we rely on the sequential read `dp_buffer_rdata`.
            // However, `dp_buffer_rdata` is read at `state == UPDATE_DP`.
            // We need to perform `max(dp_buffer_rdata, new_total_score)`.
            // We can't write `dp_buffer` immediately in comb logic.
            // So we do the comparison in comb logic and write in seq logic.
            // BUT, we are in `S_UPDATE` state (sequential). 
            // We want to write in `S_UPDATE` or `S_NEXT_IDX`?
            // Let's write in `S_UPDATE`.
            // 
            // Wait, `dp_buffer_rdata` is registered. It reflects `dp_buffer[target_idx]` from *previous* cycle.
            // If we want to update `dp_buffer[target]` based on current calculation, we need to:
            // 1. Read `dp_buffer[target]` (done via `dp_buffer_rdata` in `S_UPDATE` or previous).
            // 2. Compare `new_total_score` vs `dp_buffer_rdata`.
            // 3. Write max to `dp_buffer[target]`.
            // 
            // In `S_UPDATE`:
            // We calculate `target_idx`. 
            // We need `dp_buffer[target_idx]`. 
            // We can't read it immediately in the same cycle for update without bypass logic.
            // Since `dp_buffer` is a standard array, it has 1 cycle read latency.
            // We need to delay the calculation or use a bypass.
            // 
            // Easier approach:
            // Do the read in `S_STRATEGY` or `S_SCORE` for the *target* index.
            // But we don't know target index until we calculate `rolls_used`.
            // `rolls_used` depends on `kept1`, `kept2`.
            // 
            // Let's modify `S_SCORE` to calculate `rolls_used` and `target_idx`.
            // Then in `S_UPDATE`, we have `target_idx`. 
            // We need to read `dp_buffer[target_idx]`. 
            // We can perform the read in `S_UPDATE` (state active) and latch the result.
            // But we want to write in `S_UPDATE` too.
            // 
            // Let's do this:
            // `S_SCORE`: Calculate `score_val`. Calculate `rolls_used`. Calculate `target_idx`. 
            // `S_UPDATE`: 
            //   Read `dp_buffer[target_idx]` (if we can do async read) OR 
            //   Use a register `buffer_read_val` that was loaded in previous cycle.
            //   
            //   Since `target_idx` changes every cycle (if iterating fast), we can't easily prefetch.
            //   
            //   However, we iterate `mask_iter_1` and `mask_iter_2`. 
            //   The `rolls_used` depends on these.
            //   
            //   Let's assume we do the update in `S_UPDATE` using comb logic.
            //   We need `dp_buffer[target_idx]` value. 
            //   If `dp_buffer` is standard BRAM, we can't read and write same address in same cycle easily if we don't have write-forwarding.
            //   
            //   But wait, we are writing to `dp_buffer` in `UPDATE_DP` (my previous logic). 
            //   `dp_buffer` is a `reg [11:0] dp_buffer [0:64];`. 
            //   In SystemVerilog, this implies an array of registers. 
            //   Read is asynchronous (combinational). 
            //   Write is synchronous.
            //   So we can do:
            //   `val = dp_buffer[target_idx];`
            //   `dp_buffer[target_idx] <= max(val, new_score);`
            //   
            //   So, we need `target_idx` and `new_score` ready in `S_UPDATE`.
            //   
            //   Calculation:
            //   `S_STRATEGY`: Set `sim_roll_cnt`.
            //   `S_SIMULATE`: Update `hand_sim`.
            //   `S_SCORE`: 
            //     Calculate `score_val` (comb).
            //     Calculate `rolls_used` (comb).
            //     Calculate `target_idx` (comb).
            //     Calculate `new_total_score` (comb). 
            //     Wait, `new_total_score` needs `dp_score[dice_idx]`. 
            //     We can read `dp_score[dice_idx]` in `S_SCORE` (registered read triggered in `S_STRATEGY` or `S_ROUND_LOOP`).
            //     Let's trigger `dp_score` read in `S_ROUND_LOOP` based on `dice_idx`.
            //     So in `S_SCORE`, `dp_score_rdata` holds `dp_score[dice_idx]`.
            //     Then `new_total_score = (round_idx==0 ? 0 : dp_score_rdata) + score_val`.
            //   
            //   `S_UPDATE`: 
            //     Read `dp_buffer[target_idx]` (comb). 
            //     If `new_total_score > dp_buffer[target_idx]`, write `new_total_score`.
            //     
            //   This works if `dp_buffer` is async read.
            //   
            //   One issue: `target_idx` calculation might be too slow?
            //   It's just adders. Should be fine.
            //   
            //   Let's implement `S_SCORE` to compute `new_total_score` and `target_idx`.
            //   And `S_UPDATE` to write.
        end else begin
            new_total_score = 13'h1FFF;
        end
    end

    // Implementing the Write Logic in S_UPDATE (Sequential)
    // We need to handle the case where `new_total_score` is invalid.
    always @(posedge clk) begin
        if (state == S_UPDATE && new_total_score < 13'h1FFF) begin
            // Asynchronous read of dp_buffer[target_idx_temp]
            // Since dp_buffer is reg array, it's combinational read.
            // We need to capture the value or compare directly.
            // Since we are in always @(posedge clk), we can use the current value.
            // 
            // However, if we write to the same address in the same cycle, we need to ensure we read the OLD value.
            // `dp_buffer[target_idx_temp]` gives the old value until we update it.
            // So:
            if (new_total_score > dp_buffer[target_idx_temp]) begin
                dp_buffer[target_idx_temp] <= new_total_score;
            end
        end
    end

    // Final Max Extraction Logic (S_FINAL)
    // We iterate `copy_idx` (0 to 64) in S_FINAL state.
    // In `S_FINAL`, we read `dp_score[copy_idx]`.
    // Since `dp_score` is async read, we can do it in comb logic or seq.
    // Let's do it in the sequential block for `S_FINAL`.
    
    // --- Cleaned up State Machine Implementation (Reconciling with logic above) ---
    
    // Let's refine the `always @(posedge clk)` block to be clear.
    // We'll rely on `dp_buffer` being async read/write registers.
    
    // Additional registers for loop control
    reg [6:0] clear_cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            max_score <= 0;
            round_idx <= 0;
            dice_idx <= 0;
            mask_iter_1 <= 0;
            mask_iter_2 <= 0;
            sim_roll_cnt <= 0;
            copy_idx <= 0;
            clear_cnt <= 0;
            // Reset memories? They will be cleared in S_CLEAR.
        end else begin
            case (state)
                S_IDLE: if (start) state <= S_RESET;
                
                S_RESET: begin
                    // Initialize dp_score[0] = 0, others invalid
                    dp_score[0] <= 0;
                    // We need to clear dp_score[1..64] and dp_buffer[0..64]
                    // Let's use clear_cnt for that
                    clear_cnt <= 1;
                    state <= S_CLEAR;
                end
                
                S_CLEAR: begin
                    if (clear_cnt <= 64) begin
                        dp_score[clear_cnt] <= 13'h1FFF;
                        dp_buffer[clear_cnt] <= 13'h1FFF;
                        clear_cnt <= clear_cnt + 1;
                    end else begin
                        // Also clear dp_buffer[0]
                        dp_buffer[0] <= 13'h1FFF;
                        state <= S_INIT_ROUND; // Prepare for round 0
                        round_idx <= 0;
                        dice_idx <= 0;
                        clear_cnt <= 0; // reuse for init round
                    end
                end
                
                S_INIT_ROUND: begin
                    // We need to ensure dp_buffer is cleared for new round accumulation.
                    // But wait, S_CLEAR already cleared it.
                    // For subsequent rounds (after S_COPY), dp_buffer is cleared by S_COPY logic.
                    // So S_INIT_ROUND is just a pass-through for Round 0, and handled by S_COPY for others.
                    // Wait, we need to distinguish Round 0 init vs Round N init.
                    // Let's simplify:
                    // S_CLEAR cleans everything.
                    // Then go to S_ROUND_LOOP (Round 0).
                    // For Round > 0, S_COPY will clean dp_buffer.
                    // So we don't need S_INIT_ROUND for Round 0.
                    // But we need S_INIT_ROUND for Round > 0? No, S_COPY handles it.
                    // Let's just go to S_ROUND_LOOP.
                    state <= S_ROUND_LOOP;
                end
                
                S_ROUND_LOOP: begin
                    if (round_idx >= NUM_ROUNDS) begin
                        state <= S_FINAL;
                        copy_idx <= 0; // For final extraction
                    end else if (dice_idx + 5 > num_rolls) begin
                        state <= S_NEXT_IDX; // Skip this dice_idx
                    end else begin
                        // Start Strategy evaluation
                        // No need to do anything here, just transition
                        state <= S_STRATEGY;
                    end
                end
                
                S_STRATEGY: begin
                    // Setup for simulation
                    // Load initial hand from dice_in[dice_idx ...]
                    hand_sim[0] <= dice_in[dice_idx];
                    hand_sim[1] <= dice_in[dice_idx+1];
                    hand_sim[2] <= dice_in[dice_idx+2];
                    hand_sim[3] <= dice_in[dice_idx+3];
                    hand_sim[4] <= dice_in[dice_idx+4];
                    fetch_ptr <= dice_idx + 5;
                    sim_roll_cnt <= 0;
                    
                    // Trigger read from dp_score[dice_idx] for later use
                    // (dp_score is async, but we can latch it if we want, or just use it in S_SCORE)
                    state <= S_SIMULATE;
                end
                
                S_SIMULATE: begin
                    if (sim_roll_cnt == 0) begin
                        // Apply mask_iter_1
                        if (!mask_iter_1[0]) begin hand_sim[0] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        if (!mask_iter_1[1]) begin hand_sim[1] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        if (!mask_iter_1[2]) begin hand_sim[2] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        if (!mask_iter_1[3]) begin hand_sim[3] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        if (!mask_iter_1[4]) begin hand_sim[4] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        sim_roll_cnt <= 1;
                        // Stay in S_SIMULATE if we need more steps? 
                        // No, we need 2 re-roll steps max. 
                        // So: 0 -> 1 -> 2. 
                        // State transition logic: 
                        // If sim_roll_cnt was 0, now 1. Need to go back to S_SIMULATE to process step 2? 
                        // Or just loop inside state?
                        // Let's loop inside state.
                        // But we need to decide when to leave.
                        // If we just updated to step 1, we should stay in S_SIMULATE to process step 2.
                        // So, no `state <=` here. Just keep state S_SIMULATE.
                        // Wait, we need a flag to know we are done.
                        // Let's use a counter `sim_step`.
                        // When `sim_step` == 2, go to S_SCORE.
                        // `sim_step` increments inside S_SIMULATE.
                    end else if (sim_roll_cnt == 1) begin
                        // Apply mask_iter_2
                        if (!mask_iter_2[0]) begin hand_sim[0] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        if (!mask_iter_2[1]) begin hand_sim[1] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        if (!mask_iter_2[2]) begin hand_sim[2] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        if (!mask_iter_2[3]) begin hand_sim[3] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        if (!mask_iter_2[4]) begin hand_sim[4] <= dice_in[fetch_ptr]; fetch_ptr <= fetch_ptr + 1; end
                        sim_roll_cnt <= 2;
                    end else begin
                        // sim_roll_cnt is 2. 
                        // We are done with simulation. Go to Score.
                        state <= S_SCORE;
                    end
                end
                
                S_SCORE: begin
                    // Hand is ready in hand_sim.
                    // Calculate score (done in comb block).
                    // We need rolls_used for S_UPDATE.
                    // We need to calculate it here to pass to S_UPDATE.
                    // We can calculate it in comb block and latch it in S_UPDATE.
                    // Or calculate it here.
                    
                    // Let's compute rolls_used here.
                    // kept1/2 are comb logic based on mask_iter_1/2.
                    // So we latch them now or use comb output.
                    // 
                    // We also need to read dp_score[dice_idx] for previous score.
                    // Let's latch it now.
                    // 
                    // Transition to S_UPDATE.
                    state <= S_UPDATE;
                end
                
                S_UPDATE: begin
                    // Perform the DP update to dp_buffer
                    // Logic is in the sequential block above (triggered by state S_UPDATE)
                    // We need to make sure the logic works.
                    // 
                    // Then transition to S_NEXT_IDX.
                    state <= S_NEXT_IDX;
                end
                
                S_NEXT_IDX: begin
                    // Iterate loops
                    if (mask_iter_2 < 31) begin
                        mask_iter_2 <= mask_iter_2 + 1;
                        state <= S_STRATEGY;
                    end else if (mask_iter_1 < 31) begin
                        mask_iter_1 <= mask_iter_1 + 1;
                        mask_iter_2 <= 0;
                        state <= S_STRATEGY;
                    end else begin
                        // Finished all masks for this dice_idx
                        mask_iter_1 <= 0;
                        mask_iter_2 <= 0;
                        if (dice_idx < num_rolls - 5) begin
                            dice_idx <= dice_idx + 1;
                            state <= S_ROUND_LOOP;
                        end else begin
                            // Finished all dice_idx for this round
                            // Go to S_COPY to swap buffers
                            dice_idx <= 0;
                            copy_idx <= 0;
                            state <= S_COPY;
                        end
                    end
                end
                
                S_COPY: begin
                    // Copy dp_buffer to dp_score, clear dp_buffer
                    // dp_score[copy_idx] <= dp_buffer[copy_idx];
                    // dp_buffer[copy_idx] <= 13'h1FFF;
                    // We do this for all 65 entries.
                    if (copy_idx < 64) begin
                        dp_score[copy_idx] <= dp_buffer[copy_idx];
                        dp_buffer[copy_idx] <= 13'h1FFF; // Clear as we copy
                        copy_idx <= copy_idx + 1;
                    end else begin
                        // Last entry
                        dp_score[64] <= dp_buffer[64];
                        dp_buffer[64] <= 13'h1FFF;
                        
                        round_idx <= round_idx + 1;
                        state <= S_ROUND_LOOP;
                    end
                end
                
                S_FINAL: begin
                    // Find max in dp_score
                    if (copy_idx == 0) begin
                        max_score <= 0;
                        copy_idx <= 1;
                    end else if (copy_idx <= 64) begin
                        if (dp_score[copy_idx] < 13'h1FFF && dp_score[copy_idx] > max_score)
                            max_score <= dp_score[copy_idx];
                        copy_idx <= copy_idx + 1;
                    end else begin
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Combinational block for S_UPDATE calculations
    // Used to drive the sequential write logic in S_UPDATE state
    always @(*) begin
        // Defaults
        // We need to compute `rolls_used` and `target_idx_temp` and `new_total_score`.
        // These depend on `mask_iter_1`, `mask_iter_2`, `dice_idx`, `round_idx`, `score_val`.
        
        // Calculate kept counts
        kept1 = 0; kept2 = 0;
        for (int k=0; k<5; k++) begin
            if (mask_iter_1[k]) kept1 += 1;
            if (mask_iter_2[k]) kept2 += 1;
        end
        
        rolls_used = 5 + (5 - kept1) + (5 - kept2);
        target_idx_temp = dice_idx + rolls_used;
        
        // Previous score
        // If round 0, we rely on the fact that we initialized dp_score[0]=0 and others invalid.
        // So we can just use dp_score[dice_idx].
        // BUT, in `S_SCORE`, we need to use this value.
        // Since `dp_score` is async read, we can use it directly here.
        // However, we are in comb logic. We need to be careful about dependencies.
        // 
        // Let's pass `dp_score[dice_idx]` to `S_UPDATE` logic.
        // In `S_SCORE` state, we should latch `dp_score[dice_idx]` and `score_val`.
        // 
        // So, here in `S_UPDATE` logic (which is effectively running during S_UPDATE state),
        // we need the values latched in S_SCORE.
        // 
        // Wait, `score_val` is combinational based on `hand_sim`. 
        // `hand_sim` is updated in `S_SIMULATE`.
        // So `score_val` is valid in `S_SCORE` and `S_UPDATE`.
        // 
        // `dp_score[dice_idx]` is valid async.
        // 
        // Let's assume we have registered values `latched_score_val` and `latched_prev_dp` from `S_SCORE`.
        // 
        // In `S_UPDATE` sequential block:
        // `if (state == S_UPDATE)`
        //   `new_total_score = latched_prev_dp + latched_score_val;`
        //   `target = latched_target_idx;`
        //   `if (new_total_score > dp_buffer[target]) update.`
        // 
        // So we need to latch everything in `S_SCORE`.
    end

    // Latching in S_SCORE
    reg [11:0] latched_prev_dp;
    reg [11:0] latched_score_val;
    reg [4:0] latched_rolls_used;
    reg [4:0] latched_target_idx;
    
    always @(posedge clk) begin
        if (state == S_SCORE) begin
            latched_score_val <= score_val;
            
            // Calculate rolls used and target
            kept1 = 0; kept2 = 0;
            for (int k=0; k<5; k++) begin
                if (mask_iter_1[k]) kept1 += 1;
                if (mask_iter_2[k]) kept2 += 1;
            end
            latched_rolls_used <= 5 + (5 - kept1) + (5 - kept2);
            latched_target_idx <= dice_idx + 5 + (5 - kept1) + (5 - kept2);
            
            // Latch previous dp
            // If round 0, we use 0. Else dp_score[dice_idx].
            if (round_idx == 0) begin
                if (dice_idx == 0) latched_prev_dp <= 0;
                else latched_prev_dp <= 13'h1FFF; // Invalid
            end else begin
                latched_prev_dp <= dp_score[dice_idx];
            end
        end
    end
    
    // Update Logic in S_UPDATE
    always @(posedge clk) begin
        if (state == S_UPDATE) begin
            // Check validity of previous score
            if (latched_prev_dp < 13'h1FFF && latched_target_idx <= num_rolls) begin
                // Calculate new score
                // Note: latched_score_val is 6-bit (max 50). 
                // latched_prev_dp is 12-bit.
                // Sum fits in 12-bit (max 1000+50).
                if (latched_prev_dp + latched_score_val > dp_buffer[latched_target_idx]) begin
                    dp_buffer[latched_target_idx] <= latched_prev_dp + latched_score_val;
                end
            end
        end
    end

    // Fix S_SIMULATE state transition
    // The logic `if (sim_roll_cnt == 0) ... else if (sim_roll_cnt == 1) ... else state <= S_SCORE` 
    // misses the intermediate step where we update hand_sim and need to stay in S_SIMULATE for the next check.
    // Actually, in the logic above:
    // S_SIMULATE enters. 
    // If sim_roll_cnt was 0 (initial), we update to 1 and apply mask1. 
    // Then what? We need to check sim_roll_cnt again for the mask2 part.
    // If we stay in S_SIMULATE, `if (sim_roll_cnt == 1)` will be true in the *next* cycle.
    // So we need to stay in S_SIMULATE until `sim_roll_cnt` reaches 2 (after mask2 applied).
    // But we need to decide when to leave S_SIMULATE.
    // 
    // Revised S_SIMULATE logic:
    // `if (sim_roll_cnt == 0)`:
    //   Apply mask1. 
    //   `sim_roll_cnt <= 1`. 
    //   `state <= S_SIMULATE`. (Stay for next step)
    // `else if (sim_roll_cnt == 1)`:
    //   Apply mask2.
    //   `sim_roll_cnt <= 2`.
    //   `state <= S_SCORE`. (Done)
    
    // We need to correct the sequential block for S_SIMULATE.
    // The `else` clause in my previous block handled `sim_roll_cnt == 1` as going to S_SCORE? 
    // Let's check:
    // `if (sim_roll_cnt == 0) begin ... end`
    // `else if (sim_roll_cnt == 1) begin ... end`
    // `else begin state <= S_SCORE; end`
    // If we enter with `sim_roll_cnt == 0`:
    //   We update it to 1. We fall through to the end of the `always` block without changing `state`. 
    //   Wait, `state` is not updated in `S_SIMULATE` block if we don't assign it.
    //   So `state` remains `S_SIMULATE`. Correct.
    //   Next cycle, `sim_roll_cnt == 1`. We enter `else if`, update to 2. 
    //   We fall through. `state` remains `S_SIMULATE`.
    //   Next cycle, `sim_roll_cnt == 2`. We hit `else`, `state <= S_SCORE`. Correct.
    //   
    //   Wait, in `S_STRATEGY`, we set `sim_roll_cnt <= 0`. 
    //   Next cycle is `S_SIMULATE`. `sim_roll_cnt` is 0.
    //   We update to 1. 
    //   Next cycle `S_SIMULATE`. `sim_roll_cnt` is 1.
    //   We update to 2.
    //   Next cycle `S_SIMULATE`. `sim_roll_cnt` is 2.
    //   We go to `S_SCORE`.
    //   This takes 3 cycles. Correct.

endmodule
