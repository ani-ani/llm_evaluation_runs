module card_game_dp(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [4:0] k,
    input [4:0] d_init,
    input [4:0] g_init,
    output reg [4:0] result,
    output reg done
);

    // Parameters for max dimensions
    parameter MAX_VAL = 16;

    // State encoding
    localparam IDLE = 3'b001;
    localparam COMPUTE_DP = 3'b010;
    localparam FETCH_RESULT = 3'b100;

    // Registers for DP state
    // We use a BRAM-like storage for DP values. 
    // DP[round][d][g][k] -> Max coins Donald can get. 
    // However, round and k vary, while d and g are state variables.
    // Given constraints (<=16), we can fit the table in logic or distributed RAM.
    // To save space and simplify, we compute iteratively.
    // The problem asks for max certain coins. The recurrence is:
    // DP[r][d][g][k] = min over bets B of:
    //   Distraction: DP[r+1][d+2B][g-2B][k-1]
    //   No Distraction: DP[r+1][d-2B][g+2B][k]
    // Base case: if r==n or d==0 or g==0 -> return d.
    // We need to store values for round r+1 to compute round r.
    // We iterate rounds from n-1 down to 0.
    // State variables: cur_round, cur_d, cur_g, cur_k.
    // Since we need to update state based on bets, we need to handle multiple cycles.

    reg [2:0] state;
    
    // Iteration variables
    reg [4:0] round;
    reg [4:0] k_left;
    reg [4:0] d_val;
    reg [4:0] g_val;
    reg [4:0] bet;
    
    // Computation registers
    reg [4:0] min_val;
    reg [4:0] next_val;
    reg [4:0] dp_read_val; // Simulating read from DP table
    reg [4:0] dp_write_val;
    reg dp_write_en;
    
    // Storage for DP table
    // Address: {round, d, g, k} -> 5+5+5+5 = 20 bits. 
    // Too big for full storage (2^20 x 5 bits). 
    // Optimization: We only need the previous round to compute the current round.
    // But the recurrence depends on d and g changing (bets).
    // Let's use the described iterative solver approach from prompt.
    // We simulate the game tree or use a sparse DP table.
    // Given small constraints, we can use a direct approach:
    // Iterate rounds from n down to 0.
    // For each round, iterate all possible (d, g, k).
    // Since d, g <= 16, k <= 16, we can use a LUT for current round.
    // Let's define a memory module for current and next round.
    // Actually, since d and g change in transitions, we need a full table lookup or simulation.
    // Let's implement a state machine that calculates DP values for specific states on demand.
    // Or simpler: A brute force state machine that fills a DP table for rounds.
    // Since 16*16*16 is small, we can iterate D=0..16, G=0..16, K=0..16.
    // But the prompt suggests `DP[round][d][g][k]`.
    // Let's use a dual-port RAM approach. 
    // However, to be purely synthesizable without inferred RAMs (unless asked), we use registers.
    // Let's assume we can store DP values for all (d, g, k) for the CURRENT round being computed.
    // That is 17*17*17 ~ 5000 entries. 5000 * 5 bits = 25kbits. This is large but possible in FPGA BRAM.
    // But let's follow the "simplified iterative solver" hint.
    // We will iterate round by round. 
    // We store the DP values for the current round in a register array or memory.
    // Actually, we can just use a Combinational Logic approach for the whole tree if small.
    // But the prompt asks for a State Machine.
    
    // Let's define the logic:
    // We need to compute DP[0][d_init][g_init][k].
    // We start from round = n. Base case: if round == n, result is d.
    // So, we fill the table for round n-1, then n-2, ..., 0.
    // We need storage for DP values of the *previous* round (r+1) to compute current round (r).
    // Since r+1 is fully determined by (d, g, k), we can use a memory.
    // Let's instantiate a memory for the "Next Round" values (which are actually the "Previous" in iteration).
    // We will iterate round from n-1 down to 0.
    // Inside each round, we iterate d, g, k.
    
    // Memory interface
    // Depth 17*17*17 = 4913. 
    // We'll map (d, g, k) to an address: d * (17*17) + g * 17 + k.
    // We need 13 bits for address (2^13 = 8192).
    
    wire [12:0] addr;
    wire [4:0] din;
    wire we;
    reg [4:0] mem [0:4912];
    reg [4:0] mem_read_reg;
    
    assign addr = d_val * 17'd289 + g_val * 17'd17 + k_left;
    assign din = dp_write_val;
    assign we = dp_write_en;

    // Memory logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_read_reg <= 0;
        end else begin
            if (we) begin
                mem[addr] <= din;
            end
            // Read happens on next cycle or combinational if we want speed, 
            // but let's do registered to be safe/slow.
            mem_read_reg <= mem[addr];
        end
    end

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            dp_write_en <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize iteration variables
                        // If n == 0, result is d_init immediately
                        if (n == 0) begin
                            result <= d_init;
                            done <= 1;
                            state <= IDLE;
                        end else begin
                            // Start filling DP table from round = n-1 down to 0
                            round <= n - 1;
                            d_val <= 0;
                            g_val <= 0;
                            k_left <= 0;
                            state <= COMPUTE_DP;
                            // Clear memory (or rather, we will fill it. Base case is implicit? No, we need base values for round n)
                            // Actually, round n acts as base. We can preload base case logic or handle it in transitions.
                            // It's easier to handle the base case in the transitions or just use a flag.
                            // Let's preload the memory with base case values? 
                            // We can't iterate and write everything before starting. 
                            // We will handle round == n implicitly in the calculation.
                        end
                    end
                end

                COMPUTE_DP: begin
                    // Logic to compute DP value for current (round, d_val, g_val, k_left)
                    // and write it to memory.
                    // Then increment (d_val, g_val, k_left) to next state.
                    
                    // Optimization: We don't need to store DP for round n. 
                    // The recurrence checks round + 1. 
                    // If round + 1 == n, result is d.
                    
                    // We need to iterate all bets B from 0 to min(d, g).
                    // Since we are in a state machine, we can do this in sub-states or sequential logic.
                    // Let's use a 'bet' counter.
                    
                    // Wait for memory read (if we need it)?
                    // We need to calculate min over B.
                    // This looks complex for a single state.
                    // Let's add a sub-state for calculating min.
                    // Actually, let's implement the "update" logic here.
                    
                    // We need to handle the loop over B inside COMPUTE_DP.
                    // We can use the 'bet' register.
                    
                    // Initial entry into COMPUTE_DP for new (d,g,k):
                    if (bet == 0 && d_val == 0 && g_val == 0 && k_left == 0 && round == n-1) begin
                        // First time setup or reset for the triple loop
                        min_val <= 5'd31; // Max value for min
                        bet <= 0;
                    end

                    // Calculate limit: min(d_val, g_val)
                    // (We can do this combinational)
                    // Limit logic:
                    // if (d_val < g_val) limit = d_val; else limit = g_val;
                    // Since B is integer, and 2*B <= min(D, G), max B is floor(min/2).
                    // Actually prompt says "0 < B <= min(D, G)". Wait, usually bets are amounts.
                    // If B is coins, and 2*B is pot, then B <= min(D, G) is correct constraint for betting.
                    // But B must be integer. 
                    // Let's assume B can be 0, 1, 2...
                    
                    // Let's refine the state flow:
                    // We need to iterate rounds, d, g, k. That's 3 nested loops.
                    // And inside, we iterate B.
                    // This is very deep. 
                    // To keep it flat, we can use the clock to advance the counters.
                    
                    // Let's define the loops:
                    // Loop1: round (outermost, controlled by state machine hierarchy? No, just variable)
                    // Loop2: d (0 to 16)
                    // Loop3: g (0 to 16)
                    // Loop4: k (0 to 16)
                    // Loop5: B (0 to min(d,g))
                    
                    // We need to update min_val for each B.
                    // Then when B finishes, we write min_val to memory.
                    // Then move to next (k, g, d, round).
                    
                    // Let's implement the B loop logic.
                    
                    // Calculate next state values based on B
                    // Distraction (if k > 0): 
                    //   new_d = d + 2*B, new_g = g - 2*B, new_k = k-1
                    //   if new_g < 0 or round+1 == n, value = new_d (or current d? No, base case is d at round n).
                    //   Actually, if round+1 == n, the value is new_d.
                    //   Else, read from memory at round+1.
                    // Not distracted:
                    //   new_d = d - 2*B, new_g = g + 2*B, new_k = k
                    //   Similarly.
                    
                    // We need to determine if we are distracted or not. 
                    // The DP definition is "Max certain coins". 
                    // Donald wants to MAXIMIZE his outcome. The opponent (luck) decides distraction.
                    // "If distracted... If not distracted..."
                    // The prompt says: "Let DP[d][g][round][distractions] be the max certain coins".
                    // Then transitions: 
                    //   If distracted: min over bets... -> This implies we are looking for worst case (min) over bets, 
                    //   given the opponent acts adversarially or randomly? 
                    //   "Max certain coins" implies we want to maximize the guaranteed outcome.
                    //   So Donald chooses B to maximize the result. 
                    //   So Donald picks B to maximize the value.
                    //   The opponent (distracted vs not) chooses the scenario that MINIMIZES Donald's result.
                    //   Wait. "If distracted Donald wins... If not distracted Donald loses".
                    //   Donald does not control distraction. Distraction happens K times total.
                    //   This is usually a probability or adversarial setting.
                    //   "Certain coins" -> we assume worst case for distraction timing? 
                    //   Or we assume exactly K distractions happen, but we don't know when.
                    //   Usually "Max Certain" means Donald plays to maximize the minimum possible outcome.
                    //   So Donald chooses B to maximize ( min(Outcome_Distracted, Outcome_NotDistracted) ).
                    //   Wait, the prompt's recurrence is confusing:
                    //   "If distracted: DP = min over bets B of DP[...]" -> This implies the value is the minimum of future values?
                    //   And "If not distracted: DP = min over bets B of DP[...]".
                    //   Let's re-read carefully.
                    //   "The core logic is: Let DP be max certain coins."
                    //   Transitions:
                    //     If distracted: DP = min over B of DP[next].
                    //     If not distracted: DP = min over B of DP[next].
                    //   This looks like Donald chooses B to minimize the value? No, that doesn't make sense.
                    //   Maybe the "min" comes from the opponent's perspective? No.
                    //   Let's look at the Example Trace:
                    //   d=2, g=10, n=3, k=2.
                    //   R1: Bet 1. Distraction -> d=4, g=8. (Donald wins +2)
                    //   R2: Bet 1. Distraction -> d=6, g=6.
                    //   R3: Bet 0. No distraction -> d=6, g=6. (Donald loses 0)
                    //   Result: 4. 
                    //   Wait, the trace says Result: 4. 
                    //   Why 4? If he ends with 6? 
                    //   "Result: 4" -> Maybe the function returns the GAIN? Or the prompt has a typo in trace explanation.
                    //   Let's re-read trace: "Result: 4".
                    //   Maybe the strategy is different. 
                    //   Let's assume the recurrence provided is correct as stated, even if counter-intuitive, and just implement it.
                    //   Recurrence: 
                    //   DP[r][d][g][k] = min( 
                    //       min_{B} DP[r+1][d+2B][g-2B][k-1], 
                    //       min_{B} DP[r+1][d-2B][g+2B][k] 
                    //   )
                    //   No, the prompt says: "If distracted: DP = min over bets B..." and "If not distracted: ...".
                    //   It does NOT say "DP = min(Distracted, NotDistracted)". It says "DP = ..." for each case.
                    //   Wait, the recurrence is ambiguous.
                    //   "Transitions: If distracted: DP[d][g][r][k] = min over bets B of DP[d+2B][g-2B][r+1][k-1]. If not distracted: DP[d][g][r][k] = min over bets B of DP[d-2B][g+2B][r+1][k]."
                    //   This implies that the value depends on whether we are distracted or not.
                    //   But k indicates the *total* distractions remaining (or used? "If distracted (K rounds total)" -> K is total).
                    //   Usually, we define state by remaining distractions.
                    //   Let `k_rem` be distractions remaining. 
                    //   If `k_rem > 0`, the opponent can choose to distract. 
                    //   But "Max certain coins" implies Donald must guarantee a minimum regardless of when distractions happen.
                    //   Actually, "If distracted (K rounds total)" -> K is fixed total.
                    //   So we have `k_used` vs `n - round - 1` rounds left.
                    //   If `k_used < k`, distractions can still happen.
                    //   Usually in these games: 
                    //   Donald chooses B. 
                    //   Then "Nature" (distraction) happens or not.
                    //   To be "certain", we take the MIN of the two outcomes (Distraction vs Not) because the opponent (luck) is adversarial.
                    //   Wait, the prompt defines DP for specific distraction states? 
                    //   "DP[d][g][round][distractions]" -> `distractions` is likely `distractions_remaining`.
                    //   If `distractions > 0`:
                    //     Donald chooses B to MAXIMIZE his outcome.
                    //     Nature chooses distraction to MINIMIZE Donald's outcome.
                    //     So Value = max_B ( min( Case_Distracted, Case_NotDistracted ) )
                    //   If `distractions == 0`:
                    //     Nature cannot distract.
                    //     Value = max_B ( Case_NotDistracted )
                    //   Let's check the prompt's formula again.
                    //   "If distracted: DP = min over bets B of DP[...]"
                    //   "If not distracted: DP = min over bets B of DP[...]"
                    //   This looks like a typo in the prompt description, maybe swapping min/max or the variable.
                    //   Given the "Example Trace" shows Donald picking specific bets to maximize his coins, 
                    //   the logic should be: Donald maximizes his result, considering the worst case (min) of distraction.
                    //   Let's stick to the standard interpretation of "Max Certain Coins" game theory:
                    //   Val(d, g, r, k_rem) = 
                    //     if r == n or d==0 or g==0: d
                    //     else if k_rem == 0:
                    //       max_B { Val(d-2B, g+2B, r+1, 0) }  (Wait, if Donald loses, he loses 2B? Prompt: "Not distracted -> loses pot (2B)" -> d -= 2B, g += 2B)
                    //     else (k_rem > 0):
                    //       max_B { min( Val(d+2B, g-2B, r+1, k_rem-1), Val(d-2B, g+2B, r+1, k_rem) ) }
                    //   This is the standard formulation.
                    //   The prompt's "min over bets B" is likely a mistake and should be "max over bets B".
                    //   However, I must follow the prompt. 
                    //   Let's re-read carefully. "Let DP be the max certain coins Donald can get."
                    //   "Transitions: If distracted: DP = min over bets B of DP[...]"
                    //   Maybe the prompt describes the opponent's move? "If distracted" (condition) -> "DP = ..." (result).
                    //   And Donald wants to MAXIMIZE this "Certain Coins".
                    //   So Donald picks B to MAXIMIZE the value.
                    //   But the formula for the value at a specific state (where distraction is a specific scenario) is given by the min over B? No.
                    //   Let's try to implement the logic from the Example Trace to verify.
                    //   Trace: d=2, g=10, n=3, k=2 (distractions allowed).
                    //   Donald wants to maximize final D.
                    //   R1: Donald bets 1. 
                    //     If Distraction (D wins): D=4, G=8, k=1 left.
                    //     If No Distraction (D loses): D=0, G=12, k=2 left. 
                    //     Donald chooses B to maximize the WORST case.
                    //     B=1: min(4, 0) = 0.
                    //     B=2 (max bet): D=6, G=4 (win) -> 6; D=-2 (lose) -> -2 (or 0? game ends if D=0). 
                    //     So B=1 seems safer.
                    //   However, the trace says "Result: 4". Final coins 4.
                    //   Trace sequence: 
                    //   R1: Bet 1. Distraction. D=4, G=8.
                    //   R2: Bet 1. Distraction. D=6, G=6.
                    //   R3: Bet 0. (No distraction assumed?). D=6.
                    //   Result is 6? Or 4?
                    //   Wait, prompt says "Result: 4". 
                    //   Is 4 the "Gain"? (Final - Initial)
                    //   Initial 2, Final 6. Gain 4. Yes!
                    //   So Result = Final D - Initial D. 
                    //   Let's assume the module output is Final D (or Gain? Prompt says "Max certain coins Donald can end up with" -> usually total coins).
                    //   But Trace says Result 4. Maybe Trace result is Gain.
                    //   However, prompt Output: "Maximum certain coins Donald can have". 
                    //   If Input D=2, Output 4. This implies Gain.
                    //   Let's check: "Donald can end up with". If he ends up with 4, he gained 2. 
                    //   Let's check the Trace again. "Result: 4".
                    //   Okay, I will output the **Gain** (Final - Initial). 
                    //   Wait, "Result: 4" matches the Gain calculation (6-2=4).
                    
                    //   So, the DP function needs to return the Gain.
                    //   Let `val(d, g, r, k)` be the Max Guaranteed Final Coins (or Gain? Let's assume Final Coins first).
                    //   Base: if r==n: return d.
                    //   If d==0 or g==0: return d.
                    //   Donald chooses B to maximize the result.
                    //   Opponent chooses to distract (if k > 0) to minimize result.
                    //   So: 
                    //     If k > 0: result = max_B { min( val(d+2B, g-2B, r+1, k-1), val(d-2B, g+2B, r+1, k) ) }
                    //     If k == 0: result = max_B { val(d-2B, g+2B, r+1, 0) }
                    //   Wait, if k == 0, Donald loses (Not Distracted).
                    //   So he loses 2B.
                    //   If k > 0, he could win 2B (Distracted) or lose 2B (Not).
                    //   Donald wants to maximize the minimum.
                    //   This is the standard Maximin strategy.
                    
                    //   Now, back to implementation. 
                    //   We need to compute this DP.
                    //   Since we output Result = Final Coins - Initial Coins, we do (DP_val - d_init).
                    
                    //   Let's implement the loops.
                    //   We iterate Round from n-1 down to 0.
                    //   For each Round, we iterate all (d, g, k).
                    //   For each (d, g, k), we iterate B to find the best B.
                    
                    //   State logic for COMPUTE_DP:
                    //   We have loop variables: round, d_val, g_val, k_left, bet.
                    
                    //   Logic for B loop:
                    //   If we are at a new (d, g, k), start bet=0, max_val=0.
                    //   Calculate next states:
                    //     WinCase: d_w = d + 2*bet, g_w = g - 2*bet, k_w = k - 1
                    //     LoseCase: d_l = d - 2*bet, g_l = g + 2*bet, k_l = k
                    //   Note: If bet is 0, Win and Lose are same.
                    
                    //   We need to evaluate Val(Win) and Val(Lose).
                    //   These values come from DP table of Round+1 (or Base Case).
                    //   Since we are filling Round r, we need values from Round r+1.
                    //   We store Round r+1 in memory.
                    
                    //   So, in COMPUTE_DP state:
                    //   1. Set address to read WinCase from memory (next round values).
                    //   2. Wait 1 cycle? Or assume we read from memory in same cycle if we registered the read?
                    //      Actually, we need to read BOTH Win and Lose values to compute min.
                    //      But memory has 1 read port.
                    //      So we need to sequence the reads.
                    
                    //   Let's refine the sub-states or the flow.
                    //   We can use `state` for the main loop, but use a counter or variable for sub-steps.
                    //   Let's add a `sub_step` register.
                    
                    //   Sub-steps for COMPUTE_DP:
                    //   0: Calculate MaxBet. If bet > max_bet, go to step 4.
                    //   1: Read Win Value (Memory Access). Set address for Win. (Wait, need to wait for mem read).
                    //   2: Read Lose Value (Memory Access). Set address for Lose. Capture Win Value.
                    //   3: Compute min(Win, Lose). Update max_B_val. Increment bet. Go to step 0.
                    //   4: Write result to Memory. Increment indices (k, g, d, round).
                    
                    //   Wait, we need to handle base case (Round+1 == n) for Win/Lose values.
                    //   If Round + 1 == n, Win/Lose values are just d_w or d_l (final coins).
                    
                    //   Let's implement this logic.
                    //   We need a `best_B_val` register to store the max value found so far for current (d,g,k).
                    
                    //   Also, we need to handle the "k == 0" case (No distractions possible).
                    //   If k == 0, we only care about the Lose case (Not distracted).
                    //   So we can skip the Win case logic.
                    
                    //   Also, if bet == 0, Win and Lose are same, so we can optimize.
                    
                    //   Let's define the specific states for the computation loop.
                    //   We'll use `state` for the main structure, but maybe we need another variable for the B-loop.
                    //   Let's just use the `state` register to jump around.
                    
                    //   New States:
                    //   COMP_START_B: Prepare for bet iteration.
                    //   COMP_READ_WIN: Read Win value.
                    //   COMP_READ_LOSE: Read Lose value.
                    //   COMP_UPDATE: Calculate min, compare with best, update best_B_val.
                    //   COMP_WRITE: Write best_B_val to memory.
                    //   COMP_NEXT_INDEX: Increment indices.
                    
                    //   This makes the code long but clear.
                    
                    //   Let's update the main state machine to handle these sub-states.
                    //   We need to change the 'state' register to have more bits.
                    //   Let's define localparams for sub-states.
                    
                    //   To be safe with code length, I'll implement the logic inside the main state block.
                    //   But wait, the instructions say "strict chain of thought then code".
                    //   I will implement a simplified version inside COMPUTE_DP that handles the B loop sequentially.
                    
                    //   Revised Plan for COMPUTE_DP state:
                    //   We need to simulate the loops. 
                    //   We have variables: round, d_val, g_val, k_left, bet.
                    //   We need a `temp_val` to store the value of the current bet option.
                    //   We need `max_val_for_bet` to store the max value found so far for the current B iteration.
                    //   We need `best_val` to store the final value for (d,g,k) to be written to memory.
                    
                    //   Flow:
                    //   1. Check if we are done with all states (round == 255 or similar).
                    //   2. Check if we are done with current B loop. If yes, write to memory and advance indices.
                    //   3. Else, compute value for current B.
                    
                    //   Wait, the "min over B" in the prompt. 
                    //   If I follow the prompt literally: 
                    //   "If distracted: DP = min over bets B ..."
                    //   "If not distracted: DP = min over bets B ..."
                    //   And maybe the final DP is the min of these two? 
                    //   Let's assume the prompt's "min over B" means Donald chooses B to minimize his loss? 
                    //   No, "Max Certain Coins".
                    //   Let's stick to the standard Maximin: 
                    //   Value = max_B ( min( outcome_if_distracted, outcome_if_not ) ).
                    //   The prompt might have swapped "min" and "max" in the description.
                    //   I will implement the Maximin strategy.
                    
                    //   Let's define the computation steps clearly:
                    
                    //   If (state == COMPUTE_DP) begin
                    //     if (round == n) begin
                    //       // Should not be here if handled in IDLE. 
                    //       // If we iterate round from n-1 to 0, we don't compute round n.
                    //     end
                    //     
                    //     // Start of processing a specific (d, g, k)
                    //     // We need to check if we are starting a new (d, g, k) or continuing B loop.
                    //     // Let's use a flag or just check if bet == 0. 
                    //     // If bet == 0, we init best_val_for_state = 0.
                    //     
                    //     // Calculate Max Bet Limit: B_max = min(d, g).
                    //     // Note: Prompt says "0 < B <= min(D, G)". Is 0 allowed? Usually yes (checking options).
                    //     // If B=0, Win and Lose are 0.
                    //     // Let's iterate B from 0 to B_max.
                    //     
                    //     // Step 1: Determine Win and Lose values for current B.
                    //     // If k == 0: 
                    //     //   Only Lose case matters.
                    //     //   Value = LoseVal.
                    //     //   Since we want max over B, we compare LoseVal with best_val_for_state.
                    //     //   If k > 0:
                    //     //   Value = min(WinVal, LoseVal).
                    //     //   Compare with best_val_for_state.
                    //     
                    //     // Step 2: To get WinVal/LoseVal:
                    //     // We need to read from memory (round+1) or base case.
                    //     // Since memory is read-registered, we need to sequence.
                    //     // Let's add a state `CALCULATE_VALUE`.
                    //     // Or simply: In `COMPUTE_DP`, we calculate address, wait for next cycle to read.
                    //   end

                    //   Given the complexity and cycle limits, let's implement a very efficient state machine.
                    //   We will use `state` to manage the nested loops.
                    //   Let's expand the state bits to handle sub-states.
                    
                    //   New State Encodings:
                    //   IDLE = 0
                    //   SETUP_B = 1 (Check limits, init loop vars)
                    //   READ_WIN = 2 (Set address for Win, wait)
                    //   READ_LOSE = 3 (Set address for Lose, wait)
                    //   UPDATE_BEST = 4 (Compute min/max, update best val)
                    //   WRITE_MEM = 5 (Write result to memory)
                    //   NEXT_INDEX = 6 (Increment d, g, k, round)
                    //   FETCH_RESULT = 7
                    
                    //   But we have limited state bits. Let's keep 3 bits and pack logic.
                    //   Or just use the existing state and manage sub-steps with counters.
                    
                    //   Let's define sub_steps inside COMPUTE_DP.
                    //   sub_step 0: Init B loop.
                    //   sub_step 1: Read Win.
                    //   sub_step 2: Read Lose.
                    //   sub_step 3: Update Best.
                    //   sub_step 4: Write & Advance.
                    
                    //   Variables:
                    //   reg [2:0] sub_step;
                    //   reg [4:0] b_max;
                    //   reg [4:0] val_win;
                    //   reg [4:0] val_lose;
                    //   reg [4:0] best_val_for_b; // Best value found so far for this (d,g,k)
                    
                    //   Let's code this.

                end // end COMPUTE_DP block placeholder, we will split it
            endcase
        end
    end

    // Let's rewrite the logic block to handle the sub-states properly.
    // We need a separate block or integrate sub-states into the main state.
    // To make it synthesizable and readable, let's use a single always block with case statements on the sub-states.
    // We will use `state` as the major phase, and perhaps add a `sub_state` register.

    reg [2:0] sub_state;
    reg [4:0] b_limit;
    reg [4:0] val_win_reg;
    reg [4:0] val_lose_reg;
    reg [4:0] best_val_reg;
    reg [4:0] next_d;
    reg [4:0] next_g;
    reg [4:0] next_k;
    reg [4:0] next_bet;
    
    // Memory Read Address Helper
    always @(*) begin
        // Default to reading current state (for best_val_reg init or debug)
        // But usually we need Win or Lose address
    end

    // Main Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            dp_write_en <= 0;
            sub_state <= 0;
        end else begin
            dp_write_en <= 0; // Default
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (n == 0) begin
                            result <= d_init; // Or gain? 0 gain? Prompt says "max certain coins".
                            // If n=0, he ends with d_init. Gain = 0.
                            // Example trace shows result 4 for gain. 
                            // I'll output Gain. (Result - d_init).
                            // So if n=0, result=0.
                            result <= 0;
                            done <= 1;
                        end else begin
                            // Initialize iteration
                            round <= n - 1;
                            // We need to clear the memory? Or just overwrite.
                            // We'll overwrite as we go.
                            d_val <= 0;
                            g_val <= 0;
                            k_left <= 0;
                            sub_state <= 0;
                            state <= COMPUTE_DP;
                        end
                    end
                end

                COMPUTE_DP: begin
                    // Main loop logic
                    // We iterate: round, d, g, k, b
                    // We need to handle the nested loops.
                    // Since we can't do all in one cycle, we use `sub_state`.
                    
                    // Loop 1: Round (Outer)
                    // Loop 2: d (0 to 16)
                    // Loop 3: g (0 to 16)
                    // Loop 4: k (0 to 16)
                    // Loop 5: b (0 to min(d,g))
                    
                    // Let's define `sub_state` values:
                    // 0: Check boundaries, Init B loop, Read Win Case (if k > 0)
                    // 1: Read Lose Case (if k > 0) OR Process (if k == 0)
                    // 2: Update Best Value for B, Increment B, Loop back to 0
                    //3: Write to Memory, Advance (d, g, k) indices, Loop back
                    // 4: Advance Round
                    
                    // Note: Memory read is registered (1 cycle delay).
                    // So we need to set address in cycle X, read in cycle X+1.
                    
                    case (sub_state)
                        0: begin // Check loops, Start B iteration, Read Win
                            // First, check if we are done with current (d,g,k) B loop.
                            // Wait, we enter this sub_state when we are ready to process a new B or start.
                            // Let's assume we enter here to start a NEW B iteration.
                            
                            // Check if we finished all states
                            if (round == 255) begin // Should check round underflow or specific flag
                                // Done with all rounds? No, round goes n-1 -> 0.
                                // If round < 0 (underflow), done.
                            end
                            
                            // We need a counter for the outer loops.
                            // Let's just iterate d, g, k sequentially.
                            // Limit checks:
                            // if d_val > 16, d_val=0, g_val++
                            // if g_val > 16, g_val=0, k_left++
                            // if k_left > 16, k_left=0, round--
                            // if round underflows -> FETCH_RESULT
                            
                            // Wait, we need to check if we are starting a NEW (d,g,k) or just new B.
                            // Let's use a flag or check if bet == 0.
                            // Actually, let's reset `bet` to 0 when we finish a (d,g,k) group.
                            
                            if (bet == 0) begin
                                // Starting new (d,g,k) group
                                // Check base case for (d,g) ? No, we compute for all.
                                // Init best_val_reg for this state. 
                                // Since we want to MAXIMIZE (Min of Win/Lose), we start with 0.
                                best_val_reg <= 0;
                                
                                // Calculate B limit: min(d_val, g_val)
                                if (d_val < g_val) b_limit <= d_val;
                                else b_limit <= g_val;
                            end
                            
                            // Check if we finished B loop
                            if (bet > b_limit) begin
                                // Done with this (d,g,k)
                                // Write best_val_reg to memory
                                // But wait, we need to handle the output of the module.
                                // We only care about (d_init, g_init, k).
                                // We don't need to store the whole table if we just simulate?
                                // No, we need the table for recursion.
                                
                                dp_write_val <= best_val_reg;
                                dp_write_en <= 1;
                                // We can move to NEXT_INDEX in next cycle.
                                sub_state <= 3;
                            end else begin
                                // We have a valid bet.
                                // Calculate Next States: d', g', k' (Win), d'', g'', k'' (Lose)
                                // Win: d + 2*bet, g - 2*bet, k-1
                                // Lose: d - 2*bet, g + 2*bet, k
                                
                                // Next Step depends on k.
                                if (k_left == 0) begin
                                    // No distraction possible. Only Lose case matters.
                                    // We can skip Win read.
                                    // But we still need to read Lose value.
                                    // Let's set address for Lose.
                                    // d-2B must be >= 0. If < 0, game ends, value is 0 (or d? d becomes negative -> 0).
                                    // Actually, if d-2B < 0, Donald goes bankrupt. Value = 0.
                                    // But we check d==0 base case in recursion. 
                                    // So if new_d < 0, treat as 0.
                                    
                                    next_d <= (d_val > 2*bet) ? (d_val - 2*bet) : 0;
                                    next_g <= g_val + 2*bet;
                                    next_k <= k_left;
                                    
                                    // Set address for memory read (Round+1, new_d, new_g, new_k)
                                    // If Round+1 == n, we don't read memory, we use base case (new_d).
                                    if (round + 1 == n) begin
                                        // Base case: Value is new_d (since gain = new_d - d_init? No, DP stores final coins).
                                        // Wait, DP definition: "Max certain coins".
                                        // So DP stores Final Coins.
                                        // Base case: round == n -> return d.
                                        // So if round+1 == n, value is new_d.
                                        val_lose_reg <= next_d; // Combinational logic?
                                        // We need to go to step 2 to update best_val.
                                        sub_state <= 2;
                                    end else begin
                                        // Read from memory
                                        // We need to set the address.
                                        // Address uses: next_d, next_g, next_k.
                                        // We need to wait for memory read.
                                        // So we set address now, go to state 1 (which will be the "Wait for Read" or "Process Lose").
                                        // Since we only need Lose (k=0), we can jump to state 2 which handles the read result.
                                        // But memory needs a cycle.
                                        // So we need a state to wait.
                                        // Let's use state 1 as "Wait Read".
                                        // But we need to remember what we are waiting for.
                                        
                                        // Let's optimize: 
                                        // State 0: Setup. Set Address for Lose. Go to State 1.
                                        // State 1: Read Lose Value. Calculate Min. Update Best. Increment B. Go to 0.
                                        // (Repeat for k>0 case)
                                        
                                        // So in State 0:
                                        // Set address for Lose (or Win first).
                                        
                                        // Let's restructure State 0:
                                        // If k > 0: 
                                        //   Set Address for Win. Go to State 1.1 (Read Win).
                                        //   (Need sub-sub states or just add more bits)
                                        //   Let's keep it simple. 
                                        //   We need 2 reads for k > 0. 1 read for k == 0.
                                        //   Total cycles: 
                                        //   If k > 0: 2 reads + 1 update = 3 cycles per B.
                                        //   If k == 0: 1 read + 1 update = 2 cycles per B.
                                        
                                        // Let's use `sub_state` to count cycles.
                                        // 
                                        // We need to be careful with the logic flow.
                                        
                                        // Let's restart the logic for `COMPUTE_DP` state clearly.
                                    end
                                end else begin
                                    // k > 0. Need Win and Lose.
                                    // Read Win first.
                                    // Set address for Win.
                                    // Go to a sub-state to read Win.
                                end
                                
                                // Given the code complexity, let's assume we handle the memory read logic below.
                                // We will use `sub_state` to indicate if we are waiting for memory.
                                
                                // I will implement a more compact version to fit in the token limit.
                                // I will assume the memory read is instant for the sake of the state machine structure, 
                                // but then add a wait state if needed.
                                // Actually, since I defined `mem` as synchronous, I need a wait state.
                                
                                // Let's define `sub_state` 10, 11, 12 for reading.
                                // But let's just expand the logic.
                                
                                // To make it robust, let's assume we can only read one value per cycle.
                                
                                // Revised Logic for COMPUTE_DP:
                                // We will handle the B loop inside `COMPUTE_DP` state using `sub_state`.
                                // `sub_state` 0: Check limits, init B loop.
                                // `sub_state` 1: Set address for Win (if k>0). Wait.
                                // `sub_state` 2: Read Win, Set address for Lose. Wait.
                                // `sub_state` 3: Read Lose, Update Best. Increment B. -> Go to 0.
                                // `sub_state` 4: (If k==0) Set address for Lose. Wait.
                                // `sub_state` 5: Read Lose. Update Best. Increment B. -> Go to 0.
                                // `sub_state` 6: Write to memory. Advance indices.
                                
                                // This is too deep. 
                                // Let's try to bundle the logic.
                                
                                // Let's use `sub_state` 0, 1, 2, 3.
                                // 0: Setup/Check/Init.
                                // 1: Read Win (if needed) or Read Lose (if k=0). Wait state.
                                // 2: Read Lose (if k>0) or Process (if k=0). 
                                //    Combine here: Calculate Best. 
                                //    If k>0: Win from previous cycle, Lose from memory read (current).
                                // 3: Write & Advance.
                                
                                // Let's try this flow.
                                // Note: We need to store Win values from cycle 1 to use in cycle 2.
                                
                                // Detailed breakdown:
                                
                                // If sub_state == 0:
                                //   if bet > b_limit: go to sub_state 3 (Write/Adv). 
                                //   else: 
                                //     If k > 0:
                                //       Set address for Win. 
                                //       next_d = d + 2*bet; next_g = g - 2*bet; next_k = k - 1.
                                //       If round+1 == n: val_win_reg = next_d. Skip mem read? 
                                //       But we need to set address for read to be consistent.
                                //       Actually, if Base Case, we don't need memory. We can just use the value.
                                //       Let's handle Base Case by setting `val_win_reg` directly.
                                //       If not Base, Set Mem Address -> go to sub_state 1.
                                //     If k == 0:
                                //       Set address for Lose. Go to sub_state 4 (special path).
                                // 
                                // If sub_state == 1 (Read Win):
                                //   Read Win value from memory. Store in val_win_reg.
                                //   Set address for Lose. 
                                //   If Base Case for Lose: val_lose_reg = next_d. Go to sub_state 2.
                                //   Else: Set Mem Address -> go to sub_state 2.
                                // 
                                // If sub_state == 2 (Read Lose & Update):
                                //   Read Lose value.
                                //   If k > 0: 
                                //     Min = min(val_win_reg, val_lose_reg).
                                //     Update best_val_reg = max(best_val_reg, Min).
                                //   Else (k == 0):
                                //     Update best_val_reg = max(best_val_reg, val_lose_reg).
                                //   Increment bet. Go to sub_state 0.
                                // 
                                // If sub_state == 3 (Write/Advance):
                                //   Write best_val_reg to Memory at (d, g, k).
                                //   If this was the target (d_init, g_init, k), store in temp result.
                                //   Increment (d, g, k) indices.
                                //   If done with round (d>16, g>16, k>16):
                                //     Decrement round. Reset d, g, k. If round < 0, go to FETCH_RESULT.
                                //   Else go to sub_state 0.
                                
                                // This seems manageable.
                                
                                // Let's code this carefully.
                                
                                // Edge case: If Win or Lose ends the game (d'=0 or g'=0), the value is just d'.
                                // Actually, the recursion handles it. 
                                // But we need to be careful with d=0 base case.
                                // The base case is `if round == n`. 
                                // Also `if d==0 or g==0`, value is d.
                                // So when we read memory, we should have stored these values.
                                // Wait, if d=0, we stop. 
                                // In our loop, we iterate d=0..16.
                                // If d=0, B=0. Win=0, Lose=0. Value=0.
                                // Correct.
                                
                                // Implementation details:
                                // We need to compute `next_d`, `next_g` for Win and Lose.
                                // Win: d_w = d_val + 2*bet, g_w = g_val - 2*bet. 
                                // Lose: d_l = d_val - 2*bet, g_l = g_val + 2*bet.
                                // Note: If d_w > 16 or g_w < 0, we are out of bounds.
                                // Since D, G <= 16, and initial D, G <= 16, 
                                // Win: D increases, G decreases. G could go < 0.
                                // Lose: D decreases, G increases. D could go < 0.
                                // If D < 0 or G < 0, game ends. Value is 0 (since D=0).
                                
                                // Let's update the logic.
                                
                                if (sub_state == 0) begin
                                    // Check bet limit
                                    if (bet > b_limit) begin
                                        sub_state <= 3;
                                    end else begin
                                        // Prepare Next States
                                        // Win Case
                                        next_d <= d_val + (bet << 1); // d + 2*bet
                                        next_g <= g_val - (bet << 1); // g - 2*bet
                                        next_k <= (k_left > 0) ? k_left - 1 : 0;
                                        
                                        // Lose Case
                                        // (We compute these later to save registers, or compute now)
                                        // Let's compute them now.
                                        // We need d_l, g_l for address, or just d_val, g_val if B=0.
                                        
                                        // Check if k > 0
                                        if (k_left > 0) begin
                                            // Need Win Value
                                            if (round + 1 == n) begin
                                                // Base case for Win
                                                // If next_g < 0, game ends, D wins but G is negative? 
                                                // Usually D wins 2B, G loses 2B. If G goes < 0, G bankrupts. 
                                                // Rule: if G < 0, G loses, D gets G's money? Or D just gets 2B?
                                                // The prompt: "Donald wins the pot (2*B)". 
                                                // So D gets +2B, G gets -2B.
                                                // If G goes < 0, G loses. D gets the pot.
                                                // The game probably stops if D==0 or G==0.
                                                // So if next_g < 0, G==0 effectively. D gets its coins.
                                                // The value is next_d.
                                                val_win_reg <= (next_d > 16) ? 16 : next_d; // Clamp? No, prompt max 16.
                                                // Wait, if d > 16, it can happen. But result is clamped? 
                                                // Input constraints <= 16. Output max 16.
                                                // Let's clamp to 16.
                                                val_win_reg <= (next_d > 16) ? 16 : next_d;
                                            end else begin
                                                // Read from memory
                                                // Check bounds. If next_g < 0, treat as d=0 (val=0)
                                                if (next_g > 16 || next_d > 16 || next_g < 0) begin
                                                    // Out of bounds. 
                                                    // If next_g < 0, G bankrupts. D wins. Value is next_d (clamped).
                                                    // But next_d > d_val. 
                                                    // However, if G bankrupts, game ends. 
                                                    // The recursion at round+1 would return d (base case).
                                                    // So we can treat out of bounds as base case.
                                                    // If next_d > 16, clamp.
                                                    if (next_g < 0) val_win_reg <= (next_d > 16) ? 16 : next_d;
                                                    else if (next_d > 16) val_win_reg <= 16;
                                                    else val_win_reg <= 0; // Should not happen
                                                end else begin
                                                    // Valid range, Read memory
                                                    // We need to set address. 
                                                    // We can't set address here and read in same cycle.
                                                    // We need to go to a wait state.
                                                    // Let's use `sub_state == 1` as the state where we set address for Win.
                                                    // Then `sub_state == 2` reads Win and sets address for Lose.
                                                    // Then `sub_state == 3` reads Lose and updates.
                                                    // Wait, I used 3 for Write/Advance. 
                                                    // Let's rename sub_states.
                                                    // 0: Init/Start B. 
                                                    // 1: Set Address Win. 
                                                    // 2: Read Win, Set Address Lose.
                                                    // 3: Read Lose, Update Best.
                                                    // 4: Write/Advance.
                                                    // (We are in 0 now, jumping to 1).
                                                    
                                                    // Actually, we need to set address in 0 to be ready for 1? 
                                                    // Or set in 1.
                                                    // Let's set address in the state BEFORE the read.
                                                    // So:
                                                    // 0: Check limits. If fail -> 4. Else -> Setup Address Win. Go 1.
                                                    // 1: Read Win. Setup Address Lose. Go 2.
                                                    // 2: Read Lose. Update Best. Inc B. Go 0.
                                                    // 
                                                    // For k==0:
                                                    // 0: Check limits. If fail -> 4. Else -> Setup Address Lose. Go 3.
                                                    // 3: Read Lose. Update Best. Inc B. Go 0.
                                                    // 
                                                    // This covers it.
                                                    
                                                    // So in State 0:
                                                    // Just setup address.
                                                    
                                                    // Wait, in 0 we need to calculate next_d, next_g.
                                                    // We already did.
                                                    
                                                    // Set Address for Win (Round+1, next_d, next_g, next_k)
                                                    // We need to compute address.
                                                    // Address = {round+1, next_d, next_g, next_k} ? 
                                                    // We only store (d, g, k) for the CURRENT round being computed.
                                                    // Wait! The memory stores values for Round+1.
                                                    // So the address is simply based on (next_d, next_g, next_k).
                                                    // Round is implicit by which iteration we are on.
                                                    // Yes.
                                                    
                                                    // Set address here? No, state 1 sets address.
                                                    // So we just transition to 1.
                                                    sub_state <= 1;
                                                end
                                            end
                                        end else begin
                                            // k == 0. Only Lose case.
                                            // Setup Address Lose.
                                            // d_l = d_val - 2*bet, g_l = g_val + 2*bet.
                                            // If d_l < 0, val=0. 
                                            // If g_l > 16, it can grow, but we have space up to 16?
                                            // Max coins won't exceed ~16 if inputs are small.
                                            // We'll assume clamping or just valid range.
                                            
                                            next_d <= (d_val > (bet<<1)) ? d_val - (bet<<1) : 0;
                                            next_g <= g_val + (bet<<1);
                                            next_k <= 0; // k stays 0
                                            
                                            sub_state <= 3; // Go to Lose Read/Update path
                                        end
                                    end
                                end else if (sub_state == 1) begin
                                    // Setup Address for Win
                                    // We need to set dp_val_read (address) for Win.
                                    // This depends on next_d, next_g, next_k calculated in 0.
                                    // Wait, in 0 we calculated next_d, next_g for Win.
                                    // But we also need to check bounds for Win.
                                    // If next_g < 0 -> Win Case is base.
                                    // If we are here, we assumed we need to read memory.
                                    // But we need to check bounds again or handle it.
                                    // Actually, we can check in State 0 and jump to State 2 directly if base case.
                                    // Let's do that.
                                    // In State 0: if (next_g < 0) store val_win_reg = next_d, go to State 2.
                                    // else go to State 1.
                                    // State 1: Set Address, Wait.
                                    // State 2: Read Win, Set Address Lose, Wait.
                                    // State 3: Read Lose, Update.
                                    
                                    // Let's refine State 0 logic:
                                    // if (k > 0) begin
                                    //   if (round+1 == n || next_g < 0 || next_d > 16) begin
                                    //     val_win_reg = clamp(next_d); 
                                    //     sub_state <= 2; // Skip read, go to prepare Lose
                                    //   end else begin
                                    //     Set Address; sub_state <= 1;
                                    //   end
                                    // end else begin
                                    //   ... k=0 logic ...
                                    // end
                                    
                                    // In State 1: 
                                    // Read Win value (registered from previous cycle address).
                                    val_win_reg <= mem_read_reg; // mem_read_reg is updated in always block.
                                    
                                    // Prepare Lose
                                    if (d_val > (bet<<1)) begin
                                        next_d <= d_val - (bet<<1);
                                    end else begin
                                        next_d <= 0;
                                    end
                                    next_g <= g_val + (bet<<1);
                                    next_k <= k_left;
                                    
                                    // Check Lose bounds / Base case
                                    if (round + 1 == n || next_d == 0 || next_g > 16 || next_g < 0) begin
                                        // Base case for Lose
                                        val_lose_reg <= next_d;
                                        // We can skip to Update (State 3)? No, we need to combine with Win.
                                        // We have Win, we have Lose (computed). 
                                        // So we can go to Update.
                                        sub_state <= 3; // Update state (assuming k>0 path)
                                    end else begin
                                        // Read from memory
                                        // Set address.
                                        // We need to set address for Lose.
                                        // We can't change address and read in same cycle? 
                                        // We set address, wait for next cycle.
                                        // So we need another state.
                                        // Let's use State 2 as "Wait for Lose Read".
                                        sub_state <= 2;
                                    end
                                end else if (sub_state == 2) begin
                                    // Read Lose value
                                    val_lose_reg <= mem_read_reg;
                                    
                                    // Now Update Best
                                    // Min of Win and Lose
                                    // Max of Best and Min
                                    // Logic:
                                    // current_val = (val_win_reg < val_lose_reg) ? val_win_reg : val_lose_reg;
                                    // if (current_val > best_val_reg) best_val_reg <= current_val;
                                    
                                    // Wait, we need to do this for k>0.
                                    // If we came here from k=0 path, we handle differently.
                                    // Let's have two update paths or check k.
                                    // Actually, k=0 logic goes to State 3 directly? No, I said sub_state <= 3.
                                    // State 3 logic needs to know if it's k>0 or k==0.
                                    // Or we can handle k==0 in State 4?
                                    // Let's split State 3 logic.
                                    // State 3: Update Best (k>0).
                                    // State 4: Update Best (k=0).
                                    // State 5: Write/Advance.
                                    // Let's do this.
                                    
                                    // So:
                                    // State 0 -> State 1 (k>0, need read) OR State 4 (k==0, lose read).
                                    // State 1 -> State 2 (read win, prep lose, need read lose).
                                    // State 1 -> State 3 (read win, prep lose, base case).
                                    // State 2 -> State 3 (read lose).
                                    // State 3 -> State 5 (update k>0).
                                    // State 4 -> State 5 (read lose, update k=0).
                                    
                                    // This is getting messy with states. 
                                    // Let's try to consolidate Update logic into one state.
                                    // We can use `val_win_reg` as a flag? 
                                    // If k==0, we set `val_win_reg` to a sentinel? No.
                                    // Let's use `sub_state` 1, 2, 3, 4.
                                    // 0: Init/Start B.
                                    // 1: Read Win (or skip to 2 if base). Prep Lose. 
                                    // 2: Read Lose. 
                                    // 3: Update & Loop.
                                    // 4: Write & Advance.
                                    
                                    // Redoing State 0:
                                    // If bet > limit -> 4.
                                    // If k > 0:
                                    //   if Win is Base: val_win = next_d. Go to 2.
                                    //   else: Set Addr Win. Go to 1.
                                    // If k == 0:
                                    //   if Lose is Base: val_lose = next_d. Go to 3. (But need to handle update logic)
                                    //   else: Set Addr Lose. Go to 2. (But 2 expects Win read first?)
                                    
                                    // Okay, let's separate k paths completely.
                                    // This costs more states but is cleaner.
                                    // Let's use `sub_state` bits to encode states.
                                    // S0: Start/Check
                                    // S1: Read Win (k>0)
                                    // S2: Read Lose (k>0)
                                    // S3: Read Lose (k=0)
                                    // S4: Update & Loop (all)
                                    // S5: Write & Advance
                                    
                                    // Flow:
                                    // S0: 
                                    //   if end B: S5
                                    //   if k>0: if Win base: val_win = next_d, S2. else: Set Addr Win, S1.
                                    //   if k==0: if Lose base: val_lose = next_d, S4. else: Set Addr Lose, S3.
                                    // S1: Read Win, Prep Lose, Set Addr Lose (if not base), S2.
                                    // S2: Read Lose, S4.
                                    // S3: Read Lose, S4.
                                    // S4: Update best_val. inc bet. S0.
                                    // S5: Write memory. Advance indices. S0.
                                    
                                    // Let's implement this.
                                    
                                    // Variables needed:
                                    // val_win_reg, val_lose_reg, best_val_reg.
                                    // next_d, next_g, next_k (for Win calculation).
                                    // We also need next_d_l, next_g_l for Lose calculation (can reuse next_d/g if we save Win values).
                                    // Actually, we need to store Win values (d_w, g_w) to calculate Lose? No.
                                    // Lose depends on d_val, g_val, bet.
                                    
                                    // Let's code the case statement.
                                    
                                    case (sub_state)
                                        0: begin // S0: Start/Check B
                                            if (bet > b_limit) begin
                                                sub_state <= 5; // S5: Write/Advance
                                            end else begin
                                                // Calculate Win state (for k>0)
                                                // Win: d_w = d_val + 2*bet, g_w = g_val - 2*bet
                                                // We can store these in next_d, next_g temporarily.
                                                next_d <= d_val + (bet << 1);
                                                next_g <= g_val - (bet << 1);
                                                
                                                if (k_left > 0) begin
                                                    // Check Win Base
                                                    if (round + 1 == n || next_g > 16 || next_g < 0) begin
                                                        // Base case for Win (treat out of bounds as base too)
                                                        // If next_g < 0, G bankrupts, D gets its coins.
                                                        if (next_g < 0) val_win_reg <= (next_d > 16 ? 16 : next_d);
                                                        else val_win_reg <= next_d; // round==n or d>16
                                                        
                                                        // Prep Lose (don't set address yet, we jump to S2 which reads Lose)
                                                        // Actually, we need to set address for Lose in S2?
                                                        // No, S2 assumes address is already set or we set it in S2.
                                                        // Let's set address in S2.
                                                        // Wait, we need to calculate Lose params.
                                                        // Lose: d_l = d_val - 2*bet, g_l = g_val + 2*bet
                                                        // We need these for address.
                                                        // Let's calculate them now and store in next_d_l, next_g_l? 
                                                        // We can reuse next_d, next_g? No, we need Win params for address?
                                                        // We don't need Win params anymore if we have val_win_reg.
                                                        // So we can reuse next_d, next_g for Lose params.
                                                        next_d <= (d_val > (bet<<1)) ? d_val - (bet<<1) : 0;
                                                        next_g <= g_val + (bet<<1);
                                                        
                                                        sub_state <= 2; // Go to Read Lose (k>0 path)
                                                    end else begin
                                                        // Need to read Win from memory
                                                        // Set Address for Win
                                                        // We need to set address in the memory block.
                                                        // We can't set it from here directly if we want clean code.
                                                        // We can use `next_d`, `next_g` for address.
                                                        // The memory block always reads based on d_val, g_val, k_left?
                                                        // No, we need to control address.
                                                        // Let's add `mem_addr_d`, `mem_addr_g`, `mem_addr_k`.
                                                        // In S0, we set these for Win.
                                                        // Then go to S1.
                                                        // In S1, we read.
                                                         
                                                        // Let's refine the memory interface usage.
                                                        // The memory block I wrote earlier uses `d_val`, `g_val`, `k_left`.
                                                        // But here we need to read arbitrary (d, g, k) based on bet.
                                                        // So we need to override `d_val`, `g_val`, `k_left` for address?
                                                        // Or better, use separate address signals.
                                                        
                                                        // Let's assume we have `addr_d`, `addr_g`, `addr_k` for memory.
                                                        // And `d_val`, `g_val`, `k_left` are loop counters.
                                                        // I will add these signals.
                                                        // wire [4:0] addr_d, addr_g, addr_k;
                                                        // assign addr = (addr_d * 289) + (addr_g * 17) + addr_k;
                                                        
                                                        // In S0 for Win read:
                                                        // Assign addr_d = next_d, addr_g = next_g, addr_k = next_k (k-1).
                                                        // Wait, k address is (k-1) for Win?
                                                        // No, k in memory address is the k for the state we are reading.
                                                        // DP[d][g][r][k].
                                                        // We are reading DP[d_w][g_w][r+1][k_w].
                                                        // k_w = k - 1.
                                                        // So address k is k-1.
                                                        
                                                        // Let's add `addr_d`, `addr_g`, `addr_k`.
                                                        // In S0:
                                                        // addr_d <= next_d; addr_g <= next_g; addr_k <= k_left - 1;
                                                        // Then S1.
                                                        
                                                        // I will add these regs.
                                                        // addr_d, addr_g, addr_k.
                                                        // In memory block, use these for address.
                                                        
                                                        addr_d <= next_d;
                                                        addr_g <= next_g;
                                                        addr_k <= k_left - 1;
                                                        
                                                        sub_state <= 1;
                                                    end
                                                end else begin
                                                    // k == 0
                                                    // Prep Lose
                                                    next_d <= (d_val > (bet<<1)) ? d_val - (bet<<1) : 0;
                                                    next_g <= g_val + (bet<<1);
                                                    
                                                    // Check Lose Base
                                                    if (round + 1 == n || next_d == 0 || next_g > 16 || next_g < 0) begin
                                                        val_lose_reg <= next_d;
                                                        sub_state <= 4; // Update directly
                                                    end else begin
                                                        // Read Lose from memory
                                                        addr_d <= next_d;
                                                        addr_g <= next_g;
                                                        addr_k <= k_left;
                                                        sub_state <= 3; // S3: Read Lose (k=0)
                                                    end
                                                end
                                            end
                                        end
                                         
                                        1: begin // S1: Read Win (k>0)
                                            // Read Win value
                                            val_win_reg <= mem_read_reg;
                                             
                                            // Now Prep Lose for reading
                                            // Calculate Lose params
                                            next_d <= (d_val > (bet<<1)) ? d_val - (bet<<1) : 0;
                                            next_g <= g_val + (bet<<1);
                                             
                                            // Check Lose Base
                                            if (round + 1 == n || next_d == 0 || next_g > 16 || next_g < 0) begin
                                                val_lose_reg <= next_d;
                                                sub_state <= 4; // Update
                                            end else begin
                                                // Set Address for Lose
                                                addr_d <= next_d;
                                                addr_g <= next_g;
                                                addr_k <= k_left; // k stays same for lose
                                                sub_state <= 2; // S2: Read Lose (k>0)
                                            end
                                        end
                                         
                                        2: begin // S2: Read Lose (k>0)
                                            val_lose_reg <= mem_read_reg;
                                            sub_state <= 4;
                                        end
                                         
                                        3: begin // S3: Read Lose (k=0)
                                            val_lose_reg <= mem_read_reg;
                                            sub_state <= 4;
                                        end
                                         
                                        4: begin // S4: Update Best & Increment B
                                            // Calculate value for this bet
                                            // If k > 0: min(win, lose)
                                            // If k == 0: lose
                                            // Then max with best_val_reg
                                             
                                            // Logic:
                                            // effective_val = (k_left > 0) ? min(val_win_reg, val_lose_reg) : val_lose_reg;
                                            // if (effective_val > best_val_reg) best_val_reg <= effective_val;
                                             
                                            // Wait, the prompt said "min over bets B".  
                                            // If the prompt is literal, and Donald wants to MAXIMIZE "certain coins",
                                            // but the formula is "min over B", then Donald chooses B to MINIMIZE?
                                            // This contradicts "Max certain coins".
                                            // However, the example trace shows Donald winning 4 coins (gain).
                                            // If Donald minimized, he would bet 0.
                                            // B=0 -> d=2, g=10. Win-> 2, Lose-> 2.
                                            // Value = 2 (Gain 0).
                                            // So Donald does NOT minimize.
                                            // The prompt's text is likely swapped.
                                            // I will implement: Max_B ( Min(Win, Lose) ) if k>0.
                                            // And Max_B ( Lose ) if k==0.
                                            // This is standard Maximin.
                                             
                                            // Calculate value
                                            reg [4:0] current_val;
                                            if (k_left > 0) begin
                                                if (val_win_reg < val_lose_reg) current_val = val_win_reg;
                                                else current_val = val_lose_reg;
                                            end else begin
                                                current_val = val_lose_reg;
                                            end
                                             
                                            // Maximize
                                            if (current_val > best_val_reg) begin
                                                best_val_reg <= current_val;
                                            end
                                             
                                            // Increment B
                                            bet <= bet + 1;
                                             
                                            // Go back to start of B loop
                                            sub_state <= 0;
                                        end
                                         
                                        5: begin // S5: Write & Advance Indices
                                            // Write best_val_reg to memory at (d_val, g_val, k_left)
                                            dp_write_val <= best_val_reg;
                                            dp_write_en <= 1;
                                            // Address is already set by d_val, g_val, k_left (from the memory block reading current state)
                                            // Actually, we need to write to the address corresponding to (d_val, g_val, k_left).
                                            // The memory block logic uses `d_val`, `g_val`, `k_left` for address.
                                            // So we are good.
                                             
                                            // Check if this is the result we need (d_init, g_init, k)
                                            if (d_val == d_init && g_val == g_init && k_left == k) begin
                                                result <= best_val_reg; // Store final coins
                                            end
                                             
                                            // Advance Indices
                                            // Order: k -> g -> d -> round
                                            // We need to handle the loops.
                                            // k: 0 to 16
                                            // g: 0 to 16
                                            // d: 0 to 16
                                            // round: n-1 down to 0
                                             
                                            // Increment k
                                            if (k_left < 16) begin
                                                k_left <= k_left + 1;
                                                bet <= 0; // Reset B for new (d,g,k)
                                                sub_state <= 0;
                                            end else begin
                                                k_left <= 0;
                                                // Increment g
                                                if (g_val < 16) begin
                                                    g_val <= g_val + 1;
                                                    bet <= 0;
                                                    sub_state <= 0;
                                                end else begin
                                                    g_val <= 0;
                                                    // Increment d
                                                    if (d_val < 16) begin
                                                        d_val <= d_val + 1;
                                                        bet <= 0;
                                                        sub_state <= 0;
                                                    end else begin
                                                        d_val <= 0;
                                                        // Next Round
                                                        if (round > 0) begin // Round is 5-bit, 0 -> 255 if decremented
                                                            round <= round - 1;
                                                            bet <= 0;
                                                            sub_state <= 0;
                                                        end else begin
                                                            // All done
                                                            // We have the result (stored in 'result' or we need to fetch it?)
                                                            // We stored it in 'result' when we hit the specific state.
                                                            // But we need to calculate Gain = Final - Initial.
                                                            // Let's do that in FETCH_RESULT.
                                                            state <= FETCH_RESULT;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    endcase
                                end
                            end
                        end
                    endcase
                end // End COMPUTE_DP

                FETCH_RESULT: begin
                    // Compute Gain = Final Coins - Initial Coins
                    // Result register holds Final Coins (if we captured it).
                    // If we didn't capture it (e.g., if we processed that state earlier), we need to read it from memory.
                    // Given we iterate d,g,k, we likely captured it.
                    // But to be safe, or if we want to be pure, we read from memory.
                    // Since we finished the loop, the memory at (d_init, g_init, k) holds the answer.
                    // Wait, we wrote to memory in S5. 
                    // So we can just read from memory now.
                    // But we need to wait for the write to complete? 
                    // The write happens in S5. We transitioned to FETCH_RESULT after S5.
                    // So the value is in memory.
                    // We need to read it.
                    // Set address to (d_init, g_init, k).
                    // Wait 1 cycle.
                    // Then Subtract.
                     
                    if (sub_state == 0) begin
                        // Set address
                        // We need to use the memory address signals.
                        // Let's reuse the memory address logic.
                        // The memory block reads on clock edge.
                        // We need to set addr_d, addr_g, addr_k.
                        // Then go to sub_state 1.
                         
                        // Note: The memory block I wrote earlier uses `d_val`, `g_val`, `k_left` for address.
                        // Let's use those registers.
                        d_val <= d_init;
                        g_val <= g_init;
                        k_left <= k;
                         
                        // We need to wait for read.
                        // Let's use sub_state 1.
                        sub_state <= 1;
                    end else if (sub_state == 1) begin
                        // Read value
                        // mem_read_reg has the value.
                        // Calculate Gain.
                        // But wait, `mem_read_reg` is registered in memory block.
                        // It will update in next cycle.
                        // So we need to wait one more cycle? 
                        // My memory block does:
                        // always @(posedge clk) mem_read_reg <= mem[addr];
                        // So if I set address in T0, mem_read_reg updates in T1.
                        // So if sub_state 0 sets address, sub_state 1 (T1) reads.
                        // So here in sub_state 1, mem_read_reg is the value.
                         
                        // But wait, I need to handle the case where result was already stored in `result` register in S5.
                        // That is simpler. 
                        // If we did that, we just do subtraction here.
                         
                        // Let's check the S5 logic: 
                        // if (d_val == d_init ...) result <= best_val_reg;
                        // So `result` should hold the final coins.
                        // We need to subtract d_init.
                        // result <= result - d_init;
                         
                        // However, if we didn't hit that exact state in S5 (e.g. if we processed it earlier), we need to read.
                        // To be robust, let's read from memory.
                        // But I will assume we hit it.
                        // Let's just do the subtraction.
                        // Wait, `result` is an output register.
                        // I need a temp variable if I want to read from memory.
                        // Let's assume `result` captured the value.
                         
                        // If we didn't capture, we must read.
                        // Let's be safe and read from memory.
                        // But I need to update the logic in S5 to NOT capture, but rather rely on memory read.
                        // Let's modify S5: Remove the `result <= best_val_reg` line.
                        // And handle it in FETCH_RESULT.
                         
                        // So, in FETCH_RESULT:
                        // We set address in state 0.
                        // We read in state 1.
                        // We compute in state 2.
                         
                        sub_state <= 2;
                    end else if (sub_state == 2) begin
                        // Compute Gain
                        // Value is mem_read_reg (Final Coins).
                        // Gain = Final - d_init.
                        // Result register is 5 bits.
                        // Check if Final >= d_init.
                        // Since Donald plays to maximize, Final >= d_init (assuming he can't lose money if he plays optimally? No, he can).
                        // If Final < d_init, result is negative? We assume unsigned logic.
                        // The example trace shows gain.
                        // Let's output Gain.
                        // If Final < d_init, result 0? Or keep as is.
                        // Let's do subtraction. Verilog handles wrap-around. 
                        // We should probably saturate at 0 or handle signedness.
                        // But prompt doesn't specify negative handling.
                        // Let's just subtract.
                         
                        result <= mem_read_reg - d_init;
                        done <= 1;
                        state <= IDLE;
                        sub_state <= 0;
                    end
                end

            endcase
        end
    end

    // Memory Logic (Moved inside the module for synthesis)
    // We need to define addr_d, addr_g, addr_k for the memory.
    reg [4:0] addr_d;
    reg [4:0] addr_g;
    reg [4:0] addr_k;
     
    // Combinational address calculation
    wire [12:0] mem_addr;
    assign mem_addr = addr_d * 13'd289 + addr_g * 13'd17 + addr_k;
     
    // Memory Block
    // We need to handle Write Enable and Write Data.
    // In S5, dp_write_en is high.
    // Address for write should be the current state (d_val, g_val, k_left).
    // In S0, we set addr_d, addr_g, addr_k for reads.
     
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_read_reg <= 0;
        end else begin
            if (dp_write_en) begin
                // Write to address corresponding to current (d_val, g_val, k_left)
                // Note: In S5, we are iterating d_val, g_val, k_left.
                // So we use those for address.
                mem[ d_val * 13'd289 + g_val * 13'd17 + k_left ] <= dp_write_val;
            end
             
            // Read
            // If we are in FETCH_RESULT, we use d_val, g_val, k_left (which are set to d_init, g_init, k).
            // If we are in COMPUTE_DP (S0, S1, etc), we use addr_d, addr_g, addr_k.
            // But wait, in S5 we write. In S5 we don't read.
            // In S0 we read? No, S0 sets up address.
            // S1, S2, S3 read.
            // So we need a mux for the read address.
             
            // Let's define the current read address.
            // If state == FETCH_RESULT, read_addr = {d_init, g_init, k}
            // Else if state == COMPUTE_DP, read_addr = {addr_d, addr_g, addr_k}
            // Else 0.
             
            // Wait, in S5, we write. We shouldn't read in S5.
            // The read logic should only be active when we need it.
            // Actually, the read is always active.
            // We just need to make sure the address is correct.
             
            // In COMPUTE_DP:
            // S1, S2, S3 need reads. S0, S4, S5 do not.
            // In FETCH_RESULT:
            // Sub_state 0 sets address, Sub_state 1 reads.
             
            // Let's create a combinational signal for read address.
            wire [4:0] r_addr_d, r_addr_g, r_addr_k;
            assign r_addr_d = (state == FETCH_RESULT) ? d_init : addr_d;
            assign r_addr_g = (state == FETCH_RESULT) ? g_init : addr_g;
            assign r_addr_k = (state == FETCH_RESULT) ? k : addr_k;
             
            wire [12:0] r_addr;
            assign r_addr = r_addr_d * 13'd289 + r_addr_g * 13'd17 + r_addr_k;
             
            // Perform read
            // Note: We only read when we are in a state that expects a read.
            // But to keep it simple, we read always and latch it.
            // It's okay if we read garbage, as long as we don't use it.
             
            // However, if we are writing in the same cycle, we should prioritize write or handle carefully.
            // Standard verilog: write happens, read of same address returns new data in Verilog sim, 
            // but in synthesis it depends on RAM style. 
            // We are using logic array.
            // If we write and read same address in same cycle, we should read the OLD data or NEW data?
            // We want to read the data BEFORE update (for DP recursion).
            // In S5, we are writing. We are not reading.
            // So it's fine.
             
            mem_read_reg <= mem[r_addr];
             
            // Special handling for Base Case in logic?
            // The memory holds values for Round N? 
            // No, we don't write to memory for Round N.
            // The base case logic (round+1 == n) handles it.
            // So memory is only valid for Round 0 to N-1.
            // When we read Round N, we are out of bounds.
            // But we never set address for Round N.
            // Wait, in S1 we set address for Win.
            // If round + 1 == n, we jump to S2 (k>0) or S4 (k=0) directly.
            // So we don't set address for Round N.
            // Correct.
        end
    end

endmodule

// Helper logic: We need to handle the loops in COMPUTE_DP correctly.
// The logic I sketched above needs to be fully integrated into the `always` block.
// I will write the full `always` block now to ensure consistency.

// Re-writing the always block to include the memory logic and state transitions correctly.

module card_game_dp(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [4:0] k,
    input [4:0] d_init,
    input [4:0] g_init,
    output reg [4:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam COMPUTE_DP = 3'b010;
    localparam FETCH_RESULT = 3'b100;

    reg [2:0] state;
    reg [2:0] sub_state;
     
    // Loop variables
    reg [4:0] round;
    reg [4:0] k_left;
    reg [4:0] d_val;
    reg [4:0] g_val;
    reg [4:0] bet;
     
    // Computation temp vars
    reg [4:0] b_limit;
    reg [4:0] val_win;
    reg [4:0] val_lose;
    reg [4:0] best_val;
     
    // Memory Address signals
    reg [4:0] addr_d;
    reg [4:0] addr_g;
    reg [4:0] addr_k;
    wire [12:0] mem_addr;
    assign mem_addr = addr_d * 13'd289 + addr_g * 13'd17 + addr_k;
     
    // Memory
    reg [4:0] mem [0:4912];
    reg [4:0] mem_read_reg;
     
    // Logic to determine read/write addresses
    wire [12:0] rw_addr;
    wire [4:0] rw_data;
    wire we;
     
    // We will write in COMPUTE_DP, sub_state 5.
    // We will read in COMPUTE_DP (sub_state 1, 2, 3) and FETCH_RESULT.
     
    assign we = (state == COMPUTE_DP && sub_state == 5);
    // Data to write
    assign rw_data = best_val;
     
    // Address Mux
    // In S5 (Write), we use current (d_val, g_val, k_left) for address.
    // In other states (Read), we use addr_d, addr_g, addr_k set by the logic.
    // In FETCH_RESULT, we use d_init, g_init, k.
     
    // Let's create a unified read address signal.
    wire [4:0] r_addr_d, r_addr_g, r_addr_k;
    assign r_addr_d = (state == FETCH_RESULT) ? d_init : addr_d;
    assign r_addr_g = (state == FETCH_RESULT) ? g_init : addr_g;
    assign r_addr_k = (state == FETCH_RESULT) ? k : addr_k;
    wire [12:0] r_addr = r_addr_d * 13'd289 + r_addr_g * 13'd17 + r_addr_k;
     
    // Write Address
    wire [12:0] w_addr = d_val * 13'd289 + g_val * 13'd17 + k_left;
     
    // Memory Instance (Inferred or manual)
    always @(posedge clk) begin
        if (we) begin
            mem[w_addr] <= rw_data;
        end
        // Read happens on every cycle
        // Note: If we write and read same address in same cycle, we get new data (Verilog semantics).
        // To get old data, we'd need to bypass or register write.
        // But here, we read, then write in the SAME state flow?
        // No, S1 reads, S5 writes. So cycles are separated.
        // S0 -> S1 (read) -> S2 (read) -> S3 (read) -> S4 (update) -> S0 -> ... -> S5 (write).
        // So no conflict.
        mem_read_reg <= mem[r_addr];
    end
     
    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            sub_state <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (n == 0) begin
                            result <= 0; // Gain
                            done <= 1;
                        end else begin
                            round <= n - 1;
                            d_val <= 0;
                            g_val <= 0;
                            k_left <= 0;
                            sub_state <= 0;
                            state <= COMPUTE_DP;
                        end
                    end
                end

                COMPUTE_DP: begin
                    case (sub_state)
                        0: begin // Start B Loop / Check Limits
                            // Check if we are done with all loops
                            // If round is 0 and we finish, we go to FETCH_RESULT.
                            // But we need to check if we finished all (d, g, k) for this round.
                             
                            // Wait, the loop order is round (outermost).
                            // We iterate round from n-1 down to 0.
                            // Inside round, we iterate d, g, k.
                            // The logic to advance round is in sub_state 5.
                             
                            // Check B limit
                            if (d_val < g_val) b_limit <= d_val;
                            else b_limit <= g_val;
                             
                            // Reset best_val for this (d,g,k)
                            best_val <= 0;
                             
                            // Check if we need to process B loop or skip (if B limit is 0 and we just want to write 0?)
                            // Actually, if b_limit < 0? No.
                            // We iterate B from 0 to b_limit.
                            bet <= 0;
                             
                            // We need to handle the case where B limit is negative (d=0 or g=0).
                            // If d==0 or g==0, B=0. Win=Lose=0. Best=0.
                             
                            // Logic flow for k:
                            if (k_left > 0) begin
                                // Check Win Base Case
                                // Win: d + 2*bet, g - 2*bet
                                // If bet=0, d+0, g-0.
                                // We need to handle bet=0.
                                // Actually, we need to jump to the read state.
                                // Let's handle the Read logic in sub_state 0, then jump to 1/2/3.
                                 
                                // Calculate Win next state for bet=0 (initial check)
                                // Wait, we should check if we need to read at all.
                                // If bet=0, we process.
                                 
                                // Let's go to a specific sub-state to handle the first B iteration.
                                // We can use sub_state 1 as the entry point for the B iteration logic.
                                // But we need to distinguish if it's the start of B loop or continuing.
                                // Let's just go to sub_state 1.
                                // Sub_state 1 will handle setting up address for Win.
                                sub_state <= 1;
                            end else begin
                                // k == 0
                                sub_state <= 3; // Go to Lose path for k=0
                            end
                        end

                        1: begin // Handle Win Read (k>0)
                            // Check if we are done with B loop
                            if (bet > b_limit) begin
                                sub_state <= 5; // Write & Advance
                            end else begin
                                // Calculate Win State
                                // d_win = d_val + 2*bet
                                // g_win = g_val - 2*bet
                                // k_win = k_left - 1
                                 
                                // Check Bounds for Win
                                // If Win is base case (round+1==n or g_win<0), we don't read memory.
                                // We can check this now.
                                // We need to use comb logic or store next state in registers.
                                 
                                // Let's use registers for next_d, next_g.
                                reg [4:0] next_d_w, next_g_w;
                                next_d_w = d_val + (bet << 1);
                                next_g_w = g_val - (bet << 1);
                                 
                                if (round + 1 == n || next_g_w < 0 || next_d_w > 16 || next_g_w > 16) begin
                                    // Base case for Win
                                    if (next_g_w < 0) val_win <= (next_d_w > 16 ? 16 : next_d_w);
                                    else val_win <= next_d_w; // Round n or clamped
                                     
                                    // Now prepare Lose for this bet
                                    // Go to state 2 (Prepare Lose)
                                    // We need to calculate Lose params for state 2.
                                    // Let's store them in registers or recalculate in state 2.
                                    // Let's recalculate in state 2 to save registers.
                                    sub_state <= 2;
                                end else begin
                                    // Need to read Win from memory
                                    // Set address
                                    addr_d <= next_d_w;
                                    addr_g <= next_g_w;
                                    addr_k <= k_left - 1;
                                     
                                    // Wait for memory read
                                    // Go to a state to capture read and prepare Lose
                                    // Let's call it sub_state 10 (to avoid conflict).
                                    // Actually, let's use bits.
                                    // Let's use `sub_state` 6 for "Capture Win & Prep Lose"
                                    sub_state <= 6;
                                end
                            end
                        end
                         
                        6: begin // Capture Win Value & Prep Lose
                            val_win <= mem_read_reg;
                             
                            // Calculate Lose State (for this bet)
                            reg [4:0] next_d_l, next_g_l;
                            next_d_l = (d_val > (bet << 1)) ? d_val - (bet << 1) : 0;
                            next_g_l = g_val + (bet << 1);
                             
                            // Check Bounds for Lose
                            if (round + 1 == n || next_d_l == 0 || next_g_l > 16 || next_g_l < 0) begin
                                val_lose <= next_d_l;
                                sub_state <= 4; // Update Best
                            end else begin
                                // Read Lose from memory
                                addr_d <= next_d_l;
                                addr_g <= next_g_l;
                                addr_k <= k_left;
                                sub_state <= 7; // Capture Lose
                            end
                        end
                         
                        7: begin // Capture Lose Value (from Win path)
                            val_lose <= mem_read_reg;
                            sub_state <= 4;
                        end

                        3: begin // Handle Lose Read (k=0)
                            // Check if we are done with B loop
                            if (bet > b_limit) begin
                                sub_state <= 5;
                            end else begin
                                // Calculate Lose State
                                reg [4:0] next_d_l, next_g_l;
                                next_d_l = (d_val > (bet << 1)) ? d_val - (bet << 1) : 0;
                                next_g_l = g_val + (bet << 1);
                                 
                                // Check Bounds
                                if (round + 1 == n || next_d_l == 0 || next_g_l > 16 || next_g_l < 0) begin
                                    val_lose <= next_d_l;
                                    sub_state <= 4; // Update Best
                                end else begin
                                    // Read Lose
                                    addr_d <= next_d_l;
                                    addr_g <= next_g_l;
                                    addr_k <= k_left;
                                    sub_state <= 8; // Capture Lose
                                end
                            end
                        end
                         
                        8: begin // Capture Lose Value (k=0 path)
                            val_lose <= mem_read_reg;
                            sub_state <= 4;
                        end

                        4: begin // Update Best & Increment B
                            // Calculate effective value
                            // If k > 0: min(val_win, val_lose). Else: val_lose
                            // Maximize effective value against best_val
                             
                            reg [4:0] current_eff;
                            if (k_left > 0) begin
                                current_eff = (val_win < val_lose) ? val_win : val_lose;
                            end else begin
                                current_eff = val_lose;
                            end
                             
                            if (current_eff > best_val) begin
                                best_val <= current_eff;
                            end
                             
                            // Increment B
                            bet <= bet + 1;
                             
                            // Loop back to start of B iteration
                            // We need to go to state 1 or 3 depending on k.
                            // But we can go to a unified state.
                            // Let's go to a state that checks k and branches.
                            // Or simply go to state 1 (which checks k).
                            // State 1 code: `if (bet > b_limit) ... else ... if (k_left > 0) ...`
                            // This works.
                            sub_state <= 1;
                        end

                        5: begin // Write to Memory & Advance Indices
                            // Write best_val to memory at (d_val, g_val, k_left)
                            // We don't need to set signals explicitly, `we` is controlled by sub_state == 5.
                            // `best_val` is used as data.
                            // `d_val, g_val, k_left` used as address.
                             
                            // Check if we need to capture result
                            if (d_val == d_init && g_val == g_init && k_left == k) begin
                                result <= best_val; // This stores Final Coins
                            end
                             
                            // Advance Indices
                            // k -> g -> d -> round
                            if (k_left < 16) begin
                                k_left <= k_left + 1;
                                bet <= 0;
                                sub_state <= 0;
                            end else begin
                                k_left <= 0;
                                if (g_val < 16) begin
                                    g_val <= g_val + 1;
                                    bet <= 0;
                                    sub_state <= 0;
                                end else begin
                                    g_val <= 0;
                                    if (d_val < 16) begin
                                        d_val <= d_val + 1;
                                        bet <= 0;
                                        sub_state <= 0;
                                    end else begin
                                        d_val <= 0;
                                        if (round > 0) begin
                                            round <= round - 1;
                                            bet <= 0;
                                            sub_state <= 0;
                                        end else begin
                                            // Finished all rounds
                                            state <= FETCH_RESULT;
                                            sub_state <= 0;
                                        end
                                    end
                                end
                            end
                        end
                    endcase
                end

                FETCH_RESULT: begin
                    // We need to read the value from memory for (d_init, g_init, k) because we might not have captured it
                    // in the result register (e.g. if we processed it and stored it, we need to read it).
                    // Wait, in S5 we did: `if (d_val == d_init...) result <= best_val;`
                    // So `result` holds the final coins.
                    // However, if we want to be 100% safe against register reset or logic errors, we read from memory.
                    // Also, we need to subtract d_init.
                     
                    if (sub_state == 0) begin
                        // Set address for read
                        // We can reuse d_val, g_val, k_left since we are done with loops (they are 0).
                        // Or just set them.
                        d_val <= d_init;
                        g_val <= g_init;
                        k_left <= k;
                        sub_state <= 1;
                    end else if (sub_state == 1) begin
                        // Read value
                        // mem_read_reg has the value
                        // Calculate Gain
                        result <= mem_read_reg - d_init;
                        done <= 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
