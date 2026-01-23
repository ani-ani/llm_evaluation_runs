module ivana_game_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_bits,
    input [2:0] N,
    output reg [3:0] result,
    output reg done
);

    // Parameters for states
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam COMPUTE_STATES = 3'b010;
    localparam EVALUATE_MOVES = 3'b011;
    localparam DONE = 3'b100;

    // Registers for state machine
    reg [2:0] current_state;
    reg [2:0] next_state;

    // Registers for computation
    reg [7:0] mask;
    reg [2:0] i; // loop variable
    reg [2:0] player; // 0 for Ivana (Max), 1 for Zvonko (Min)
    reg [7:0] state_addr;
    reg signed [7:0] outcome;
    reg signed [7:0] eval_outcome;
    reg signed [7:0] temp_outcome;
    reg [7:0] temp_mask;
    reg [2:0] move_idx;
    reg signed [7:0] best_outcome;
    reg [3:0] win_count;

    // Memory for state values (256 x 8-bit signed)
    // Address: mask (8-bit)
    // Data: outcome (8-bit signed)
    reg signed [7:0] state_mem [0:255];
    integer k;

    // Helper wires for adjacency and terminal checks
    wire [7:0] combined_mask;
    wire is_terminal;
    wire [7:0] bit_mask;
    wire [7:0] neighbors;
    wire [7:0] valid_moves;

    // Helper function to get bit from num_bits based on index
    // Since N <= 8, we only consider bits 0 to N-1
    function get_odd;
        input [2:0] idx;
        input [7:0] bits;
        input [2:0] N_val;
        begin
            if (idx < N_val)
                get_odd = bits[idx];
            else
                get_odd = 0;
        end
    endfunction

    // Adjacency logic (indices i-1 and i+1 mod N must be in mask or be the move)
    // We check if a move is valid for a specific mask (potential intermediate state)
    // This logic runs combinational based on current mask and i (move index)
    // Adjacency: move i is valid if (i-1 in mask) OR (i+1 in mask)
    // Special rule: if mask is empty, move i is valid if i-1 or i+1 is also i (conceptually only if N=1? No, must be adjacent)
    // The problem says: "indices i-1 and i+1 (mod N) must be within taken set or be the move itself"
    // Wait, "or be the move itself" means if i-1 or i+1 equals i, which only happens if N=1 or modulo wrap?
    // Actually, the standard rule for the game of 15 (or similar) is that you can only play next to existing numbers.
    // If the mask is empty, any move is allowed? Or must it be the first element?
    // The prompt says: "Start with that single index taken".
    // And: "Available moves: any untaken index adjacent to taken area".
    // So if mask is {bit i}, then valid moves are i-1 and i+1 (mod N).
    // If mask is empty, standard game rules often allow any start. But here we evaluate "first move".
    // The evaluate loop starts with a single bit set.
    // The "adjacency check" description: "indices i-1 and i+1 (mod N) must be within taken set or be the move itself".
    // This phrasing is a bit ambiguous. Let's assume standard linear adjacency.
    // If mask is empty (0), usually any move is valid. But since we evaluate moves 0..N-1 as starts, we don't check validity for the first move.
    // Inside recursive calls (state generation), we need to check validity.
    
    // Wires for neighbor bits
    wire [2:0] left_idx;
    wire [2:0] right_idx;
    
    assign left_idx = (i == 0) ? (N - 1) : (i - 1);
    assign right_idx = (i + 1) % N; // Need to handle mod N properly in Verilog
    // Since N is 3 bits, right_idx = (i + 1) % N. If i+1 == N, it's 0.
    // Let's do it manually: i+1 if i+1 < N else 0.
    wire [2:0] right_idx_calc;
    assign right_idx_calc = (i == 3'd7) ? 0 : i + 1; // Safe upper bound, N limits it
    // Actually N <= 8, so if N=8, max index 7. If N=5, indices 0-4. 
    // The wrap logic: (i+1)%N.
    // We can use the fact that N is small.
    reg [2:0] r_idx_wire;
    always @(*) begin
        if (i + 1 >= N) r_idx_wire = 0;
        else r_idx_wire = i + 1;
    end

    // Valid move check:
    // A move 'm' is valid for 'current_mask' if:
    // 1. Bit m is not set in current_mask.
    // 2. (Bit (m-1) is set OR Bit (m+1) is set) OR current_mask is 0 (starting condition logic handled by state machine)
    // The prompt says: "indices i-1 and i+1 (mod N) must be within taken set or be the move itself".
    // This usually implies adjacency. Let's implement standard adjacency.
    // If mask != 0, check neighbors. If mask == 0, any move is valid (start).
    
    // Helper to check if a bit is set in mask for a specific index
    wire left_set;
    wire right_set;
    wire self_set;
    
    assign self_set = mask[i];
    assign left_set = (i == 0) ? mask[N-1] : mask[i-1];
    // Correct right logic: (i+1) % N
    reg [2:0] next_idx;
    always @(*) begin
        if (i + 1 < N) next_idx = i + 1;
        else next_idx = 0;
    end
    assign right_set = mask[next_idx];

    wire is_valid_move;
    // If mask is 0, valid (start of subgame). Or if neighbors are set.
    assign is_valid_move = ~self_set && ( (mask == 8'h00) || left_set || right_set );

    // Is terminal check: all N bits set
    // Generate a mask of N bits set
    wire [7:0] full_mask;
    assign full_mask = (N == 1) ? 8'h01 :
                       (N == 2) ? 8'h03 :
                       (N == 3) ? 8'h07 :
                       (N == 4) ? 8'h0F :
                       (N == 5) ? 8'h1F :
                       (N == 6) ? 8'h3F :
                       (N == 7) ? 8'h7F : 8'hFF;
    
    assign is_terminal = ((mask & full_mask) == full_mask);

    // Combinational logic to compute outcome for a given mask and player
    // This is the core recursive logic flattened into combinational logic for synthesis
    // We use the state machine to sequence the recursion effectively or use pre-computed tables.
    // Given the "2048 cycles" constraint and "256 states", we can iterate.
    // Let's implement a step-by-step evaluation.

    // The algorithm: 
    // 1. Compute values for all states. We need to do this in order of increasing bits set.
    //    Or use iteration until stable? No, it's a DAG based on adding bits.
    //    Actually, we can process by number of bits set (popcount). 
    //    Let's do: count bits in mask -> store in popcount_reg.
    //    Iterate through all 256 masks. For each mask, if it's not terminal:
    //       Check valid moves. For each valid move, form new mask.
    //       New mask outcome = - (outcome of new mask) ? No.
    //       Value(Mask, Player) depends on Value(Move).
    //       If Player is Max (Ivana), she picks move leading to Max Value.
    //       If Player is Min (Zvonko), he picks move leading to Min Value.
    //       The Value of a state is the difference (IvanaOdd - ZvonkoOdd).
    //       When Ivana plays, she adds her odd count. When Zvonko plays, he adds to his count (subtracting from diff).
    //       Wait, the problem says: "outcome difference (Ivana's odd count - Zvonko's odd count)".
    //       If it's Ivana's turn and she picks an odd number: +1 to outcome.
    //       If it's Zvonko's turn and he picks an odd number: -1 to outcome.
    //       So, the recursive function should return the BEST possible outcome difference from the current state, assuming optimal play.
    
    //   Let `solve(mask, turn)` return the best possible outcome difference.
    //   Base case: if terminal, return 0 (no more moves).
    //   Recursive:
    //     If turn == Ivana (Max):
    //       Best = -inf.
    //       For each valid move i:
    //         new_mask = mask | (1<<i)
    //         val = get_odd(i) + solve(new_mask, Zvonko)
    //         Best = max(Best, val)
    //       Return Best
    //     If turn == Zvonko (Min):
    //       Best = +inf.
    //       For each valid move i:
    //         new_mask = mask | (1<<i)
    //         val = -get_odd(i) + solve(new_mask, Ivana) // Zvonko reduces diff
    //         Actually, usually we just subtract the opponent's gain.
    //         If the function returns (Ivana - Zvonko), then:
    //         When Ivana plays: NewDiff = OldDiff + (is_odd ? 1 : 0) - (result of next state? No, next state calculates diff from that point).
    //         The recursive call returns the diff for the *remaining* game.
    //         So Total Diff = (MoveResult) + (RemainingDiff).
    //         MoveResult: Ivana adds odd? 1 : 0. Zvonko adds odd? -1 : 0.
    //         So: Ivana turn: max over ( (odd?1:0) + solve(new_mask, Zvonko) )
    //         Zvonko turn: min over ( (odd?-1:0) + solve(new_mask, Ivana) )
    
    //   However, storing state values in the 256x8 memory.
    //   Usually in DP, we store the value for a state for the *current* player to move.
    //   Or we store the absolute outcome of the game from that state.
    //   The problem says: "Store state values in a 256×8-bit memory (256 states, 8-bit signed outcome)".
    //   And "For each state, compute the outcome difference".
    //   This suggests storing the result of the game from that state assuming optimal play (starting with the player whose turn it is).
    //   Wait, the recursion needs to alternate players.
    //   We can store values based on the parity of moves made (which determines whose turn it is).
    //   Or, we can store two values per state? No, 256x8-bit memory.
    //   Let's store the value assuming the player specified by 'current_turn' bit in the address? No, address is 8-bit mask.
    //   Actually, the state is defined by the mask. The turn is determined by the number of set bits.
    //   If popcount(mask) is even -> Ivana's turn? Or Zvonko's?
    //   Usually Ivana is first. So popcount=0 -> Ivana. popcount=1 -> Zvonko. popcount=2 -> Ivana.
    //   So turn = (popcount % 2 == 0) ? Ivana : Zvonko.
    //   We can compute this on the fly.
    
    //   So, we need to fill `state_mem` such that state_mem[mask] = optimal outcome difference for the game *starting from this mask*.
    //   We need to process states in decreasing order of set bits? Or increasing?
    //   Since adding bits moves us to a "larger" mask, we should process from full mask backwards, or use a queue.
    //   Given the small size (256), we can iterate multiple times or sort by popcount.
    //   Let's precompute popcount or iterate backwards from 255 to 0. 
    //   If we iterate backwards (255 down to 0), we process filled masks first. 
    //   But a state with fewer bits depends on states with more bits (since we add bits).
    //   So we MUST process states with MORE bits first.
    //   Iterating 255 down to 0 works if we interpret mask as integer.
    //   i.e., 11111111 is last, 00000000 is first. We want to solve 11111111 first.
    //   So loop i from 255 down to 0.

    //   Wait, the prompt asks for a state machine that runs in 2048 cycles. 
    //   256 states * some factor.
    
    //   Implementation Plan:
    //   State: IDLE -> INIT (clear memory/vars) -> COMPUTE_STATES.
    //   COMPUTE_STATES:
    //     We iterate 'state_addr' from 255 down to 0.
    //     For each state_addr:
    //       1. Check if mask is valid (bits > N must be 0). If bits > N are set, skip or treat as invalid.
    //       2. Determine turn: count bits in state_addr (popcount).
    //          If popcount >= N, terminal -> val = 0.
    //       3. Determine valid moves.
    //       4. If Ivana's turn: find move yielding max value. Value = (Odd?1:0) + Value(new_state).
    //       5. If Zvonko's turn: find move yielding min value. Value = (Odd?-1:0) + Value(new_state).
    //       6. Store in state_mem[state_addr].
    //     After 256 iterations, go to EVALUATE_MOVES.
    //   EVALUATE_MOVES:
    //     Iterate i from 0 to N-1.
    //     Set mask = (1 << i).
    //     Retrieve outcome = state_mem[mask].
    //     If outcome > 0, increment result.
    //     After loop, go to DONE.

    //   But wait, the prompt says: "Evaluate each possible first move... Start with that single index taken... Compute resulting outcome".
    //   And "The core algorithm uses memoization".
    //   This implies we need to fill the memo table (state_mem) *before* or *during* evaluation.
    //   Since we need to look up state_mem[mask] for any sub-state, we should fill the table first.
    //   The prompt also says: "For each state, compute the outcome difference... assuming optimal play".
    //   This confirms the DP approach.

    //   Let's refine the states to fit the cycle count.
    //   Total states: 256. For each state, we might need to check up to N (<=8) moves.
    //   So roughly 256 * 8 = 2048 cycles. This fits perfectly.
    //   So we can flatten the logic: 
    //   State: IDLE -> INIT -> COMPUTE_STATES (Main loop) -> EVALUATE_MOVES (Second loop) -> DONE.

    //   In COMPUTE_STATES, we need a nested loop or a sequential scan.
    //   Let's have a loop variable `addr_reg` from 255 down to 0.
    //   And a sub-loop `move_idx` from 0 to 7.
    //   Inside the sub-loop, we check if `move_idx` is a valid move for `addr_reg`.
    //   If yes, we calculate the value and update best/min.
    //   After checking all moves (0-7), we store the result.
    //   Note: We must ensure we only consider moves < N. But `num_bits` and `N` define the game.
    //   We must mask out bits >= N during checks.
    
    //   Let's define the internal logic for value calculation.
    //   Let `current_mask` be `addr_reg`.
    //   Let `turn` be determined by popcount of `current_mask`.
    //   Actually, popcount of `current_mask` tells us how many moves have been made.
    //   Ivana is move 0, 2, 4... Zvonko is 1, 3, 5...
    //   If `popcount` is even -> Ivana (Max). If odd -> Zvonko (Min).
    
    //   Wait, the problem says "N odd/even bits (packed)". `num_bits` defines the values of the numbers.
    //   Index 0 of `num_bits` corresponds to element 0.
    
    //   Let's implement the popcount logic.
    //   Since we are in Verilog, we can use a loop or explicit adders.
    //   Given the pipeline nature, let's do it sequentially or use helper logic.
    
    //   Let's refine the state machine phases:
    //   1. IDLE: Wait for start.
    //   2. INIT: Reset `addr_reg` (state counter) to 255. Reset result counter.
    //   3. COMPUTE_STATES:
    //        If `addr_reg` < 0 -> EVALUATE_MOVES.
    //        Else:
    //          Extract `mask` = `addr_reg`.
    //          Check mask validity (bits >= N must be 0). If invalid, store 0 and decrement.
    //          Calculate popcount of `mask`.
    //          If popcount == N -> terminal, store 0, decrement.
    //          Else:
    //            Determine turn (even popcount -> Ivana).
    //            Reset `move_idx` to 0.
    //            Go to sub-state to check moves.
    //   4. CHECK_MOVE:
    //        If `move_idx` >= N -> Go back to COMPUTE_STATES (end of move loop), store result.
    //        Check if `move_idx` is valid for `mask` (using logic above).
    //        If valid:
    //           Form `new_mask` = mask | (1 << move_idx).
    //           Read `old_val` from state_mem[new_mask]. (Note: since we iterate 255->0, new_mask > mask usually, so it's already computed).
    //           Calculate `val` = (Ivana move ? odd : -odd) + old_val.
    //           Update best/minimum.
    //           Increment `move_idx`.
    //           Loop CHECK_MOVE.
    //        Else -> Increment `move_idx`, loop CHECK_MOVE.
    //   5. EVALUATE_MOVES:
    //        Reset `move_idx` to 0.
    //        Reset `result` to 0.
    //        Loop through 0 to N-1:
    //           `new_mask` = 1 << move_idx.
    //           Read `val` from state_mem[new_mask].
    //           If `val` > 0 -> `result`++.
    //           Increment `move_idx`.
    //           If `move_idx` < N -> loop EVALUATE.
    //           Else -> DONE.
    //   6. DONE: Set done high. Wait for reset or start low?
    
    //   Optimization: Popcount of `addr_reg`.
    //   We can compute it once per `addr_reg`.
    //   Or, we can use a pre-calculated array? No, that's too big for registers.
    //   Let's compute it combinatorially inside the state machine.
    //   Popcount of 8 bits: 
    //   bit_count = mask[0] + mask[1] + ... + mask[7].
    //   This takes 1 cycle if we use an adder tree, or multiple cycles if sequential.
    //   Given 2048 cycles total, we have time.
    //   Let's use a sequential popcount calculation to save resources or keep logic shallow.
    //   Actually, we are already in a state machine. We can just use the comb logic we declared.
    //   `popcnt` wire.
    
    //   Implementation details:
    //   `state_mem` read/write:
    //   We write to it at the end of the COMPUTE_STATES phase (after checking all moves).
    //   We read from it during the CHECK_MOVE phase (to get value of child state).
    //   We read from it during EVALUATE_MOVES.
    
    //   Data path:
    //   Registers: `addr_reg` (8-bit), `move_idx` (3-bit), `best_val` (8-bit signed), `temp_val` (8-bit signed).
    
    //   Let's code the state machine.

    // Popcount helper logic
    wire [3:0] popcnt;
    assign popcnt = mask[0] + mask[1] + mask[2] + mask[3] + mask[4] + mask[5] + mask[6] + mask[7];

    // Memory Read Logic
    wire signed [7:0] read_val;
    assign read_val = state_mem[move_idx_valid ? new_mask : addr_reg]; // Simplified, handle in always block
    // Actually, we need to read specific addresses.
    // In CHECK_MOVE, we need to read state_mem[new_mask].
    // In EVALUATE, we read state_mem[1<<move_idx].
    // We will handle memory read/write in the combinational logic or sequential logic block.
    
    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Main State Machine Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            addr_reg <= 8'd255;
            move_idx <= 3'd0;
            result <= 4'd0;
            best_outcome <= 8'sd0;
            // state_mem cleared separately if needed, or assume it's init to 0.
            // Since it's an array, we might need to clear it in IDLE/INIT.
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Initialization
                        addr_reg <= 8'd255;
                        result <= 4'd0;
                        done <= 1'b0;
                        // We might need a flag to clear memory. Let's do it in INIT state.
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Clear state memory if needed. 
                    // Since we write to it in COMPUTE_STATES, and we iterate 255->0,
                    // we only write to valid states. Unwritten states (bits >= N) should be 0.
                    // If we assume state_mem is initialized to 0 at startup, we don't need to clear.
                    // But to be safe, we could use a clear loop. 
                    // Given the cycle limit, let's assume synthesis tool infers initial 0 or we don't need explicit clear.
                    // Just proceed to compute.
                    next_state <= COMPUTE_STATES;
                end

                COMPUTE_STATES: begin
                    // Check if we are done with all states (addr_reg wrapped or < 0)
                    // Actually, we want to process 0..255. We started at 255.
                    // If addr_reg becomes 255->0->255... we need a stopping condition.
                    // Let's stop when addr_reg crosses from 0 to 255.
                    // Or use a counter. Let's use a `valid_range` check.
                    // Actually, we need to process all 256.
                    // We can use `addr_reg` as a counter that decrements.
                    // If addr_reg == 0, next state is check 0, then next is 255 (if not handled).
                    // Let's use a separate counter or check if we processed 0.
                    // Let's introduce a `state_phase` or just check `addr_reg`.
                    
                    // If `addr_reg` == 0, we process index 0, then we are done with the loop.
                    // Let's say we are done when `addr_reg` == 0 AND we finished processing moves for it.
                    // But we don't have a "finished moves" flag here.
                    // Let's use a nested state for move checking.
                    
                    // Let's split COMPUTE_STATES into:
                    //   A. CHECK_TERMINAL_AND_SETUP (process current addr_reg)
                    //   B. CHECK_MOVES_LOOP (iterate move_idx)
                    
                    // Since I defined COMPUTE_STATES as the loop, let's define it as the entry point.
                    
                    // Check bounds. If addr_reg corresponds to a mask with bits > N, skip.
                    // Actually, it's easier to skip processing if (addr_reg & ~full_mask) != 0.
                    // But `addr_reg` is 8 bit. `full_mask` depends on N.
                    
                    // Let's perform the validity check and popcount.
                    // We will need `mask` variable.
                    mask <= addr_reg; // Capture current state
                    
                    // Check if we are finished.
                    // If addr_reg == 0, we finish THIS cycle, then go to evaluate.
                    // Wait, we must process addr_reg=0.
                    // After processing addr_reg=0, we go to EVALUATE.
                    
                    // Logic flow:
                    // 1. Check if `addr_reg` is valid (bits <= N).
                    // 2. If valid and not terminal:
                    //    Determine turn.
                    //    Reset move_idx = 0.
                    //    Move to CHECK_MOVE state.
                    // 3. If valid and terminal:
                    //    Store 0.
                    //    Decrement addr_reg. Loop COMPUTE_STATES.
                    // 4. If invalid:
                    //    Store 0 (optional, memory is 0).
                    //    Decrement addr_reg. Loop COMPUTE_STATES.
                    
                    // We need to do this step-by-step. 
                    // Let's use a single state for "Processing" and use move_idx to control flow.
                    
                    // Let's re-define the flow in one state for simplicity and use combinational logic to drive next state.
                end
            endcase
        end
    end
    
    // Re-writing the state machine logic to be strictly linear/sequential to fit the Verilog output requirement.
    // Since I cannot write infinite code, I will use a single always block for the FSM and combinational logic for calculations.
    
    // Registers for the loop
    reg [7:0] addr_reg; // 0..255
    reg signed [7:0] val_storage; // Value to write to memory
    reg write_en; // Memory write enable
    reg signed [7:0] current_best; // Best/Min value for current state
    reg [7:0] child_mask; // Mask of the child state
    reg signed [7:0] child_val; // Value read from memory
    reg signed [7:0] move_val; // Calculated value for current move
    reg signed [7:0] odd_val; // +1, -1, or 0 based on turn and oddity
    
    // Combinational block for next state and outputs
    always @(*) begin
        next_state = current_state;
        write_en = 1'b0;
        val_storage = 8'sd0;
        
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            
            INIT: begin
                next_state = COMPUTE_STATES;
            end
            
            COMPUTE_STATES: begin
                // This state handles the iteration control.
                // We need to perform multiple operations per 'addr_reg'.
                // 1. Check validity of addr_reg.
                // 2. If valid, check if terminal.
                // 3. If not terminal, we need to iterate moves.
                // Since we only have 2048 cycles, we must do this efficiently.
                // We can't use nested states for every move iteration easily in a simple FSM without exceeding code limits.
                // Let's use the fact that move_idx is 0..7 (8 steps).
                // So for every `addr_reg`, we spend 8 cycles.
                // Total cycles: 256 * 8 = 2048. Perfect.
                
                // We will use a combined state or a flag `in_move_loop`.
                // Let's use `move_idx` to determine if we are in the move loop.
                // If move_idx == 0, we are setting up.
                // If move_idx > 0, we are iterating.
                
                // Actually, let's separate COMPUTE_STATES into:
                // SETUP (checks validity, terminal, prepares move_idx=0) -> CHECK_MOVE -> (loop) -> STORE -> (loop addr_reg)
                
                // To keep the code compact, let's use a single state for the main loop and rely on `move_idx`.
                // However, verilog requires explicit states.
                // Let's define sub-states.
                
                // Since the prompt requires a specific state machine structure, I will use the main states and logic.
                // But to fit the synthesisable requirement and cycle count, I will assume a slightly more granular control.
                // Let's add an internal state `sub_state`.
            end
        endcase
    end
    
    // Refined FSM structure to meet requirements without excessive code:
    // State: IDLE, INIT, SETUP_COMPUTE, CHECK_MOVE, STORE_RESULT, EVALUATE_MOVES, DONE.
    // We will use `addr_reg` and `move_idx` as counters.
    
    // Internal state for the computation loop
    localparam SETUP = 1'b0;
    localparam ITERATE = 1'b1;
    reg compute_phase;
    
    // Combinational Logic for Determining Validity and Value
    wire signed [7:0] next_val;
    wire signed [7:0] child_read_val;
    
    // Memory Read Logic: Read from child_mask during iteration
    assign child_read_val = state_mem[child_mask];
    
    // Calculate move value
    // Turn: Ivana (0) if popcnt is even, Zvonko (1) if odd.
    // `mask` holds current state bits.
    // `move_idx` is the move being evaluated.
    wire turn_is_ivana;
    assign turn_is_ivana = (popcnt % 2 == 0);
    
    // Odd value of the move
    wire move_is_odd;
    assign move_is_odd = (move_idx < N) ? num_bits[move_idx] : 0;
    
    // Contribution to outcome
    wire signed [7:0] contribution;
    assign contribution = turn_is_ivana ? (move_is_odd ? 8'sd1 : 8'sd0) : (move_is_odd ? 8'sd1 : 8'sd0);
    // Wait, if Zvonko plays odd, outcome diff decreases. 
    // So Ivana play: +Odd, Zvonko play: -Odd.
    assign contribution = turn_is_ivana ? (move_is_odd ? 8'sd1 : 8'sd0) : (move_is_odd ? -8'sd1 : 8'sd0);
    
    // Total value for this move = contribution + child_read_val
    assign move_val = contribution + child_read_val;
    
    // Define validity of move
    wire move_valid;
    // Check if move_idx is within N
    wire idx_in_range;
    assign idx_in_range = (move_idx < N);
    // Check if bit is already taken
    wire bit_taken;
    assign bit_taken = mask[move_idx];
    // Check neighbors
    wire left_n, right_n;
    wire [2:0] l_idx, r_idx;
    // Handle wrapping
    assign l_idx = (move_idx == 0) ? (N - 1) : (move_idx - 1);
    assign r_idx = (move_idx + 1 >= N) ? 0 : (move_idx + 1);
    
    // We need to map these logical indices back to bits 0..7 for the mask.
    // Since we only care if they are set in `mask`.
    // But wait, if N=5, index 4 neighbors are 3 and 0. 
    // So we check mask[l_idx] and mask[r_idx].
    // However, the mask is 8-bit wide. If N=5, indices 5..7 are ignored in mask.
    // So we just check mask[logical_index].
    assign left_n = mask[l_idx];
    assign right_n = mask[r_idx];
    
    // Standard rule: Valid if bit not taken AND (neighbors exist OR mask is empty)
    assign move_valid = idx_in_range && ~bit_taken && ( (mask == 8'h00) || left_n || right_n );

    // Determine best/minimum value for current state
    // We need to accumulate this over the moves.
    // This requires a register `current_best`.
    // In SETUP phase, we initialize `current_best`.
    // In ITERATE phase, we update `current_best`.
    
    wire signed [7:0] next_best;
    // If Ivana: max(current, move_val)
    // If Zvonko: min(current, move_val)
    // Since Zvonko minimizes diff, we want the smallest diff (most negative). 
    // Standard negamax/negamax alpha-beta: Value = -max(opponent_value). 
    // But here we store outcome diff directly.
    // Ivana wants Max. Zvonko wants Min.
    
    assign next_best = turn_is_ivana ? 
                       ((current_best > move_val) ? current_best : move_val) : 
                       ((current_best < move_val) ? current_best : move_val);
                       
    // Initial values for `current_best`:
    // Ivana: -infinity. Zvonko: +infinity.
    // Let's use -128 and 127 for 8-bit signed.
    // Or, better, use the first valid move as the seed.
    // Let's handle the seed in the SETUP/ITERATE logic.

    // FSM Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            // Memory reset not required if we write all 256 entries
            // But to be safe, we can clear it if needed, but here we fill it.
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_state <= INIT;
                        // Reset loop counters
                        addr_reg <= 8'd255;
                        move_idx <= 3'd0;
                        compute_phase <= SETUP;
                        done <= 1'b0;
                    end
                end

                INIT: begin
                    // Transition to Compute
                    current_state <= COMPUTE_STATES;
                    // We will handle the logic in the next block or here.
                    // Actually, let's use a block for COMPUTE_STATES logic.
                    // But Verilog requires defined logic for all states.
                    // Let's combine logic.
                    
                    // To simplify, let's move directly to the loop.
                    current_state <= COMPUTE_STATES;
                    // Ensure we start with addr_reg = 255
                    addr_reg <= 8'd255;
                    move_idx <= 3'd0;
                    compute_phase <= SETUP; // We are setting up for address 255
                end

                COMPUTE_STATES: begin
                    // Logic for checking validity and terminal condition of `addr_reg`
                    // If invalid (bits > N) or terminal (popcnt == N):
                    //   Store 0 if invalid, 0 if terminal.
                    //   Then decrement addr_reg.
                    //   If addr_reg becomes 255 (wrapped), we are done. Go to EVALUATE.
                    //   Else, stay in COMPUTE_STATES with compute_phase <= SETUP.
                    
                    // If valid and not terminal:
                    //   If compute_phase == SETUP:
                    //     Initialize current_best.
                    //     mask <= addr_reg.
                    //     move_idx <= 0.
                    //     compute_phase <= ITERATE.
                    //   Else (ITERATE):
                    //     Check move_idx.
                    //     If move_idx >= 8: (Finished all moves)
                    //       Write `current_best` to state_mem[addr_reg].
                    //       Decrement addr_reg.
                    //       If addr_reg wraps (0->255), go to EVALUATE.
                    //       Else, compute_phase <= SETUP.
                    //     Else (move_idx < 8):
                    //       Check if move valid.
                    //       If valid: update current_best = next_best.
                    //       Increment move_idx.
                    
                    // We need to define the logic for "invalid or terminal" check.
                    // Let's use a wire.
                    wire is_invalid;
                    // Check bits 8..
                    wire [7:0] check_mask;
                    assign check_mask = (N == 1) ? 8'hFF : 
                                       (N == 2) ? 8'hFE :
                                       (N == 3) ? 8'hF8 :
                                       (N == 4) ? 8'hF0 :
                                       (N == 5) ? 8'hE0 :
                                       (N == 6) ? 8'hC0 :
                                       (N == 7) ? 8'h80 : 8'h00;
                    assign is_invalid = (addr_reg & check_mask) != 0;
                    
                    // Determine if we should write 0 immediately
                    wire immediate_zero;
                    assign immediate_zero = is_invalid || (popcnt == N && N != 0); // Terminal or invalid
                    
                    if (compute_phase == SETUP) begin
                        if (immediate_zero) begin
                            // Store 0
                            state_mem[addr_reg] <= 8'sd0;
                            // Next address
                            if (addr_reg == 0) begin
                                current_state <= EVALUATE_MOVES;
                                move_idx <= 3'd0; // Reset for evaluation loop
                            end else begin
                                addr_reg <= addr_reg - 1;
                                // stay in COMPUTE_STATES, phase SETUP (implicitly)
                            end
                        end else begin
                            // Valid state, need to iterate moves
                            mask <= addr_reg; // Store current mask for reference
                            move_idx <= 3'd0;
                            // Initialize best value based on turn
                            // Ivana (Max): -128. Zvonko (Min): 127.
                            // But we need to skip if no moves exist (shouldn't happen in valid non-terminal).
                            // However, we need to handle the case where no moves are valid (impossible for connected graph).
                            // Let's initialize to 0 and a flag 'first_move_found'?
                            // Actually, simpler: set default based on turn.
                            if (popcnt % 2 == 0) current_best <= -8'sd128; // Ivana
                            else current_best <= 8'sd127; // Zvonko
                            
                            compute_phase <= ITERATE;
                        end
                    end else begin // ITERATE phase
                        if (move_idx >= 3'd8) begin
                            // Finished all potential moves for this mask
                            state_mem[addr_reg] <= current_best;
                            // Next address
                            if (addr_reg == 0) begin
                                current_state <= EVALUATE_MOVES;
                                move_idx <= 3'd0;
                            end else begin
                                addr_reg <= addr_reg - 1;
                                compute_phase <= SETUP;
                            end
                        end else begin
                            // Check this move
                            if (move_valid) begin
                                // Calculate child mask
                                // child_mask = mask | (1 << move_idx)
                                // We need this comb logic or sequential.
                                // Let's do it sequentially. 
                                // Actually, we need to read state_mem[child_mask].
                                // We must ensure child_mask is ready.
                                
                                // Wait, `child_read_val` is combinational based on `child_mask`.
                                // We need to set `child_mask`.
                                // Since we are in a clocked block, we can't easily read and update in same cycle without pipeline.
                                // But we are iterating. We can compute child_mask on the fly.
                                
                                // Let's calculate child_mask inside the update logic.
                                // It's just `addr_reg | (1 << move_idx)`.
                                // Since `addr_reg` is the current state, and `move_idx` is the move.
                                
                                // Optimization: 
                                // In this cycle, we update `current_best`.
                                // But we need `child_read_val`. 
                                // `child_read_val` is `state_mem[addr_reg | (1<<move_idx)]`.
                                // Since we iterate `addr_reg` from 255 down to 0, `child_addr` > `addr_reg` (mostly) or valid.
                                // Actually, adding a bit increases the integer value.
                                // So yes, `child_addr` is already computed in a previous cycle.
                                // So we can safely read it.
                                
                                // Update logic:
                                // next_val = contribution + child_read_val.
                                // But we need `child_mask`.
                                // Let's define it locally.
                                wire [7:0] child_addr = addr_reg | (1 << move_idx);
                                // We must read `state_mem[child_addr]`.
                                // To do this in hardware, we need to clock it out or use it immediately.
                                // Since we are inside an always block, we can't read memory directly unless it's a variable.
                                // We can read it into a temporary register in the previous cycle.
                                // But we are updating `move_idx` sequentially.
                                
                                // Let's assume we have `child_read_val` driven by `child_addr`.
                                // We can define `child_addr` combinatorially.
                                // But we need to be careful about dependencies.
                                
                                // Let's implement the update.
                                // We need to use the combinational `move_val` defined earlier.
                                // But `move_val` depends on `child_read_val`, which depends on `child_mask`.
                                // We need to calculate `child_mask` and use it.
                                
                                // Let's do it explicitly here to avoid multiple memory ports or confusion.
                                // We will use a sequential read. 
                                // Actually, for simplicity in this constrained environment, we can perform the calculation based on the *previous* state's memory content if we pipeline, 
                                // OR we can assume the memory read is fast (zero cycle) for simulation/synthesis of small memories.
                                
                                // Let's use the combinational `child_read_val` defined outside.
                                // We need to update `child_mask` register or wire.
                                // Let's update `child_mask` on the fly.
                                
                                // Since I can't easily inject a wire update inside the block, I will compute the value.
                                // This assumes `state_mem` read is combinational or we handle it.
                                // For synthesis, we rely on the tool's memory inference.
                                
                                // Let's stick to the logic:
                                // 1. Compute child_mask = addr_reg | (1 << move_idx)
                                // 2. Read state_mem[child_mask] (assume combinational read or pre-fetched)
                                // 3. Update current_best.
                                
                                // To be safe with registers:
                                // We will update `current_best` using the logic derived.
                                // We need to read `state_mem`.
                                // Let's define a helper variable `child_mask_calc`.
                                wire [7:0] child_mask_calc = addr_reg | (1 << move_idx);
                                // We need to read state_mem[child_mask_calc].
                                // Let's assume we can access it directly here or via a temp register.
                                // If we use `state_mem[child_mask_calc]` directly, it is combinational read.
                                
                                // Check if we need to update.
                                // We need to update `current_best`.
                                
                                // Perform update:
                                if (turn_is_ivana) begin
                                    // Maximize
                                    if (move_val > current_best) current_best <= move_val;
                                end else begin
                                    // Minimize
                                    if (move_val < current_best) current_best <= move_val;
                                end
                            end
                            // Increment move_idx
                            move_idx <= move_idx + 1;
                        end
                    end
                end

                EVALUATE_MOVES: begin
                    // We need to evaluate first moves 0..N-1.
                    // Move_idx iterates 0..N-1.
                    // Read state_mem[1 << move_idx].
                    // If value > 0, result++.
                    
                    // Read logic needs to be combinational or we need a temp reg.
                    // Let's use `state_mem[1 << move_idx]` directly.
                    
                    // Since we are updating `result` which is a register, we need to be careful with accumulation.
                    // We can do this in N cycles.
                    
                    if (move_idx < N) begin
                        // Evaluate move_idx
                        if (state_mem[1 << move_idx] > 0) begin
                            result <= result + 1;
                        end
                        move_idx <= move_idx + 1;
                    end else begin
                        current_state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    // Stay done unless reset
                    // result is held
                end
            endcase
        end
    end

endmodule

// NOTE: The memory access state_mem[...] inside the always block might be synthesisable as block RAM or distributed RAM.
// However, reading and writing in the same cycle or depending on the address update can be tricky.
// In the code above, inside COMPUTE_STATES, we update `addr_reg` and `move_idx`. 
// When we access `state_mem[addr_reg]` or `state_mem[1<<move_idx]`, it uses the current values.
// This should work for combinational read memory.

// One specific issue: In `COMPUTE_STATES` ITERATE phase, we use `state_mem[addr_reg | (1<<move_idx)]`.
// Since `move_idx` increments, we access different addresses. 
// Since `state_mem` is an array, this is fine.

// Let's clean up the helper wires and logic to ensure they are defined at the top level or within the block if possible.
// For the purpose of this exercise, the code above assumes standard Verilog inference.

// Refined code to ensure all variables are declared and used correctly.
// I'll add the missing declarations and logic for the nested parts.

module ivana_game_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_bits,
    input [2:0] N,
    output reg [3:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam COMPUTE_STATES = 3'b010;
    localparam EVALUATE_MOVES = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state, next_state;

    // Registers for looping and computation
    reg [7:0] addr_reg;       // Current state mask being computed (255 -> 0)
    reg [2:0] move_idx;       // Current move index (0 -> 7)
    reg signed [7:0] current_best; // Best outcome for current state (Ivana: max, Zvonko: min)
    reg signed [7:0] temp_child_val; // Pipelined read of child value
    reg [7:0] child_addr;     // Address for child state
    reg child_valid;          // Flag if child state is valid
    
    // Memory for state outcomes (256 x 8-bit signed)
    // Inferred as distributed RAM or Block RAM
    reg signed [7:0] state_mem [0:255];
    integer i;

    // Wires for combinational logic
    wire [7:0] full_mask;
    wire [7:0] invalid_mask;
    wire is_invalid;
    wire [3:0] popcnt;
    wire turn_is_ivana;
    wire move_is_odd;
    wire signed [7:0] contribution;
    wire signed [7:0] move_val;
    wire [7:0] calc_child_addr;
    wire move_valid_check;
    wire idx_in_range;
    wire bit_taken;
    wire left_n, right_n;
    wire [2:0] l_idx, r_idx;
    wire [2:0] next_move_idx;
    wire is_terminal;

    // --- Combinational Logic ---

    // Full mask for N bits set
    assign full_mask = (N == 1) ? 8'h01 :
                       (N == 2) ? 8'h03 :
                       (N == 3) ? 8'h07 :
                       (N == 4) ? 8'h0F :
                       (N == 5) ? 8'h1F :
                       (N == 6) ? 8'h3F :
                       (N == 7) ? 8'h7F : 8'hFF;

    // Mask for bits >= N (to detect invalid states)
    assign invalid_mask = ~full_mask;
    assign is_invalid = (addr_reg & invalid_mask) != 0;

    // Popcount of addr_reg (current state)
    assign popcnt = addr_reg[0] + addr_reg[1] + addr_reg[2] + addr_reg[3] + 
                    addr_reg[4] + addr_reg[5] + addr_reg[6] + addr_reg[7];

    // Terminal check
    assign is_terminal = (popcnt == N) && (N != 0);

    // Turn determination: Ivana (Max) if even moves made, Zvonko (Min) if odd
    assign turn_is_ivana = (popcnt % 2 == 0);

    // Move properties
    assign idx_in_range = (move_idx < N);
    assign bit_taken = addr_reg[move_idx]; // Check bit in current state
    
    // Neighbor indices (circular)
    assign l_idx = (move_idx == 0) ? (N - 1) : (move_idx - 1);
    assign r_idx = (move_idx + 1 >= N) ? 0 : (move_idx + 1);
    
    // Neighbor checks (must be within valid range N)
    assign left_n = (l_idx < N) ? addr_reg[l_idx] : 1'b0;
    assign right_n = (r_idx < N) ? addr_reg[r_idx] : 1'b0;
    
    // Move validity: Index in range, bit not taken, and (mask empty OR neighbor taken)
    assign move_valid_check = idx_in_range && ~bit_taken && ((addr_reg == 8'h00) || left_n || right_n);

    // Contribution to outcome based on turn and oddity
    // Ivana adds odd, Zvonko subtracts odd
    assign move_is_odd = (move_idx < N) ? num_bits[move_idx] : 1'b0;
    assign contribution = turn_is_ivana ? (move_is_odd ? 8'sd1 : 8'sd0) : (move_is_odd ? -8'sd1 : 8'sd0);

    // Child address: current state + new move bit
    assign calc_child_addr = addr_reg | (1 << move_idx);

    // Value of the move: contribution + value of child state
    // Note: state_mem[calc_child_addr] must be read combinationaly or registered.
    // Here we use combinational read assumption.
    assign move_val = contribution + state_mem[calc_child_addr];

    // Next best value logic (updated in clocked process)
    wire signed [7:0] potential_best;
    assign potential_best = turn_is_ivana ? 
                            ((current_best > move_val) ? current_best : move_val) : 
                            ((current_best < move_val) ? current_best : move_val);

    // --- Sequential Logic ---

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            // Optional: Clear state_mem here if needed, but we overwrite all entries during compute
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_state <= INIT;
                        done <= 1'b0;
                    end
                end

                INIT: begin
                    // Initialize counters
                    addr_reg <= 8'd255;
                    move_idx <= 3'd0;
                    result <= 0;
                    // Transition to compute
                    current_state <= COMPUTE_STATES;
                end

                COMPUTE_STATES: begin
                    // --- Phase 1: Check State Validity & Terminal ---
                    if (move_idx == 3'd0 && !is_invalid && !is_terminal) begin
                        // Start evaluating this state
                        // Initialize best value based on turn
                        if (turn_is_ivana) current_best <= -8'sd128; // Min int
                        else current_best <= 8'sd127;                 // Max int
                        move_idx <= 3'd1; // Start checking moves from index 1 (or 0, depends on logic)
                        // Actually, let's check move 0 first.
                        move_idx <= 3'd0;
                    end else if (move_idx == 3'd0 && (is_invalid || is_terminal)) begin
                        // Invalid or Terminal: Store 0 (or just leave 0 if memory initialized to 0)
                        // Since we want to be explicit, we write 0 only if we are not at end of loop
                        if (addr_reg != 8'h00) state_mem[addr_reg] <= 8'sd0;
                        else state_mem[addr_reg] <= 8'sd0; // Explicitly write 0 to 0
                        
                        // Next address
                        if (addr_reg == 8'h00) begin
                            current_state <= EVALUATE_MOVES;
                            move_idx <= 3'd0;
                        end else begin
                            addr_reg <= addr_reg - 1;
                            move_idx <= 3'd0; // Reset for next iteration check
                        end
                    end 
                    else begin
                        // --- Phase 2: Iterate Moves ---
                        // If we are here, state is valid and not terminal. move_idx is iterating.
                        
                        if (move_idx < 3'd8) begin
                            // Check current move
                            if (move_valid_check) begin
                                current_best <= potential_best;
                            end
                            // Increment move index
                            move_idx <= move_idx + 1;
                        end else begin
                            // Finished iterating all moves (0..7)
                            // Store result
                            state_mem[addr_reg] <= current_best;
                            
                            // Next address
                            if (addr_reg == 8'h00) begin
                                current_state <= EVALUATE_MOVES;
                                move_idx <= 3'd0;
                            end else begin
                                addr_reg <= addr_reg - 1;
                                move_idx <= 3'd0; // Reset for next address setup
                            end
                        end
                    end
                end

                EVALUATE_MOVES: begin
                    // Evaluate first moves 0..N-1
                    if (move_idx < N) begin
                        // Check outcome of move 'move_idx'
                        // The state is mask = (1 << move_idx)
                        // We need to read state_mem[1 << move_idx]
                        if (state_mem[1 << move_idx] > 0) begin
                            result <= result + 1;
                        end
                        move_idx <= move_idx + 1;
                    end else begin
                        // Done evaluating
                        current_state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    // Stay here until reset
                    // Optional: if start goes low, go to IDLE, but spec implies reset or start logic.
                    if (!start) current_state <= IDLE;
                end
            endcase
        end
    end

endmodule