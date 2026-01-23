module matrix_recovery(
    input clk,
    input rst_n,
    input start,
    input [3:0] row_parity,
    input [3:0] col_parity,
    output reg [15:0] matrix_out,
    output reg valid,
    output reg impossible,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam SEARCH = 3'b010;
    localparam VALIDATE = 3'b100;
    
    reg [2:0] state;
    
    // Control signals
    reg [15:0] candidate;
    reg [4:0] ones_target; // 0 to 16
    reg [15:0] next_candidate;
    reg [3:0] r_parity_calc;
    reg [3:0] c_parity_calc;
    reg valid_sol;
    
    // Intermediate signals for parallel parity calculation
    wire [3:0] row_xor;
    wire [3:0] col_xor;
    
    assign row_xor[0] = candidate[0] ^ candidate[1] ^ candidate[2] ^ candidate[3];
    assign row_xor[1] = candidate[4] ^ candidate[5] ^ candidate[6] ^ candidate[7];
    assign row_xor[2] = candidate[8] ^ candidate[9] ^ candidate[10] ^ candidate[11];
    assign row_xor[3] = candidate[12] ^ candidate[13] ^ candidate[14] ^ candidate[15];
    
    assign col_xor[0] = candidate[0] ^ candidate[4] ^ candidate[8] ^ candidate[12];
    assign col_xor[1] = candidate[1] ^ candidate[5] ^ candidate[9] ^ candidate[13];
    assign col_xor[2] = candidate[2] ^ candidate[6] ^ candidate[10] ^ candidate[14];
    assign col_xor[3] = candidate[3] ^ candidate[7] ^ candidate[11] ^ candidate[15];
    
    // Count set bits in candidate
    wire [4:0] popcount;
    assign popcount = candidate[0] + candidate[1] + candidate[2] + candidate[3] +
                     candidate[4] + candidate[5] + candidate[6] + candidate[7] +
                     candidate[8] + candidate[9] + candidate[10] + candidate[11] +
                     candidate[12] + candidate[13] + candidate[14] + candidate[15];
    
    // Generate next lexicographic candidate with same number of 1s
    // Uses bit manipulation: (x | (x - 1)) + 1 to get next number with same popcount
    // But we need to handle the case where we reach the maximum for that popcount
    wire [15:0] next_lex;
    wire [15:0] x = candidate;
    wire [15:0] u = x & -x;
    wire [15:0] v = x + u;
    assign next_lex = v | (((v ^ x) >> 2) / u);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            matrix_out <= 16'b0;
            valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
            candidate <= 16'b0;
            ones_target <= 5'd16;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                        // Start with maximum 1s (16 ones) - just all 1s
                        candidate <= 16'hFFFF;
                        ones_target <= 16;
                    end
                end
                
                SEARCH: begin
                    // Check if current candidate has correct number of 1s
                    if (popcount == ones_target) begin
                        // Validate this candidate
                        state <= VALIDATE;
                    end else begin
                        // Generate next candidate
                        if (ones_target == 0) begin
                            // Tried all possibilities
                            state <= IMPOSSIBLE;
                        end else begin
                            ones_target <= ones_target - 1;
                            // Start new search for fewer 1s: smallest value with N 1s is (1<<N)-1
                            if (ones_target == 16)
                                candidate <= 16'hFFFF;
                            else if (ones_target == 15)
                                candidate <= 16'h7FFF;
                            else if (ones_target == 14)
                                candidate <= 16'h3FFF;
                            else if (ones_target == 13)
                                candidate <= 16'h1FFF;
                            else if (ones_target == 12)
                                candidate <= 16'h0FFF;
                            else if (ones_target == 11)
                                candidate <= 16'h07FF;
                            else if (ones_target == 10)
                                candidate <= 16'h03FF;
                            else if (ones_target == 9)
                                candidate <= 16'h01FF;
                            else if (ones_target == 8)
                                candidate <= 16'h00FF;
                            else if (ones_target == 7)
                                candidate <= 16'h007F;
                            else if (ones_target == 6)
                                candidate <= 16'h003F;
                            else if (ones_target == 5)
                                candidate <= 16'h001F;
                            else if (ones_target == 4)
                                candidate <= 16'h000F;
                            else if (ones_target == 3)
                                candidate <= 16'h0007;
                            else if (ones_target == 2)
                                candidate <= 16'h0003;
                            else if (ones_target == 1)
                                candidate <= 16'h0001;
                            else // 0
                                candidate <= 16'h0000;
                        end
                    end
                end
                
                VALIDATE: begin
                    // Check parities
                    if ((row_xor == row_parity) && (col_xor == col_parity)) begin
                        // Valid solution found
                        state <= COMPLETE;
                        matrix_out <= candidate;
                        valid <= 1'b1;
                        done <= 1'b1;
                    end else begin
                        // Try next candidate with same number of 1s
                        if (popcount == 0) begin
                            // Cannot generate next
                            state <= SEARCH;
                        end else begin
                            // Calculate next lexicographic candidate
                            if (popcount == ones_target) begin
                                // Check if we can generate next
                                // Maximum for N bits is if all 1s are at top: (1<<N)-1 shifted to MSBs
                                // For 4x4=16 bits, max with K ones is (1<<K)-1
                                // But we want to check if current candidate is the maximum
                                // Maximum is all 1s at the high end
                                // For K ones: max is (1<<(16)) - (1<<(16-K)) which is all 1s in top K positions
                                // Actually, let's just compute next_lex
                                
                                // Special check: if candidate already has 1s in all lowest positions
                                // That is, if (candidate | (candidate - 1)) == 0xFFFF or similar
                                // Actually, the formula for next_lex works until we overflow
                                
                                // Let's verify the generated next has correct popcount
                                // If overflow, next_lex will have fewer 1s
                                // So check: if next_lex has popcount != ones_target, we exhausted this level
                                
                                // But popcount of next_lex might be tricky to compute in one cycle
                                // Alternative: check if candidate is the maximum
                                // Max with K ones: all 1s at the highest positions
                                // e.g. K=4: 1111000000000000 = 0xF000
                                // Check if candidate >= max_val_for_popcount
                                
                                // Generate next
                                candidate <= next_lex;
                                
                                // If next_lex has fewer ones, we need to go to SEARCH
                                // We can detect this by checking if next_lex is "smaller" in some sense
                                // or check the popcount of next_lex in the next cycle
                                // But we need immediate decision
                                
                                // Better approach: calculate next, then check if popcount changed
                                // But popcount takes combinational logic
                                
                                // Let's use the property: next_lex will have same popcount unless overflow
                                // Overflow happens when we reach the number with K ones at MSB
                                // e.g. for K=4, max is 0xF000 (1111000000000000)
                                // Next would be 0x000F (0000000000001111) which has popcount 4? No wait
                                // The standard algorithm (x | (x - 1)) + 1 followed by some division
                                // actually produces the next number with same popcount.
                                // It wraps around to the smallest with same popcount when at max.
                                // So we need to check if we wrapped around.
                                // Wrapped if next_lex < candidate AND candidate != max
                                // Actually, if next_lex < candidate, it means we wrapped.
                                // BUT, the smallest with K ones is (1<<K)-1.
                                // So if next_lex == (1<<K)-1, we know we wrapped.
                                
                                // Let's implement a simple check:
                                // Compute next_lex. Then compute popcount(next_lex) in the same cycle?
                                // No, that's recursive.
                                
                                // Let's stick to: generate next_lex. 
                                // In SEARCH state, we check if candidate's popcount matches target.
                                // So if next_lex has wrong popcount, we'll go to SEARCH, 
                                // decrement ones_target, and start new.
                                
                                // Problem: next_lex might generate a number with MORE 1s?
                                // No, next_lex with same popcount formula preserves popcount.
                                // But if we start at 0xF000 (popcount 4), next_lex produces 0x0F00 (popcount 4).
                                // Eventually 0x000F (popcount 4). Next is 0x001E (popcount 4? 00011110 = 4 ones). 
                                // Wait, 0x000F -> 00001111. 
                                // (0x000F | 0x000E) + 1 = 0x000F | 0x000E + 1. 
                                // u = 1. x = 15. v = 16. 0x0010. 
                                // ((v^x)>>2)/u = (15>>2)/1 = 3. 
                                // 0x0010 | 3 = 0x0013 (00010011). Popcount 3. 
                                // Okay, the formula needs to be careful or we accept that we might jump.
                                
                                // Let's use the "next combination" algorithm:
                                // next = (x | (x - 1)) + 1;
                                // next = next | ((((next & -next) / (x & -x)) >> 1) - 1);
                                // Or simpler: generate next, then rely on the SEARCH state logic to filter.
                                
                                // Let's use a robust next generator:
                                // 1. t = x | (x - 1);
                                // 2. next = (t + 1) | (((~t & -~t) - 1) >> (ctz(x) + 1));
                                // This is standard "next combination".
                                
                                // But for synthesis, we want simple logic.
                                // Let's try: 
                                // t = x | (x - 1);
                                // next = (t + 1) | ((((t + 1) & - (t + 1)) / (x & -x)) >> 2);
                                
                                // Actually, the simplest for HW might be to just iterate candidates.
                                // But we have 65536 candidates. 128 cycles limit.
                                // We must skip many candidates.
                                // We need to generate only valid candidates.
                                
                                // Let's use the checked formula:
                                // u = x & -x; // lowest set bit
                                // v = x + u;
                                // next = v | (((v ^ x) >> 2) / u);
                                
                                // Now, how to detect exhaustion?
                                // If x is the maximum value with popcount K.
                                // Max is 0xFFFF with K=16.
                                // Max with K=4 is 0xF000.
                                // If x >= (0xFFFF >> (16-K)) [if we consider MSB aligned]?
                                // Actually, max is `((1 << 16) - (1 << (16-K)))`.
                                // If x is max, next_lex will be `((1 << K) - 1)` (smallest).
                                // So we detect if next_lex < x (wrap around).
                                // If wrap around, we go to SEARCH to decrement K.
                                
                                // Wait, the wrap around value `((1 << K) - 1)` is usually smaller than x if x is large.
                                // So next_lex < x implies wrap.
                                // However, if we are already at smallest, next_lex might be > x (normal increment).
                                // So only if next_lex < x we stop.
                                
                                // But there's a case: if K=0, x=0. u=0. Division by zero.
                                // We handled K=0 separately.
                                
                                // Let's verify: K=4. x=0xF000 (61440).
                                // u = 0x1000.
                                // v = 0x10000.
                                // v^x = 0x7000.
                                // (v^x)>>2 = 0x1C00.
                                // / u = 0x1C00 / 0x1000 = 1. (integer division).
                                // next = 0x0000 | 0x0001 = 0x0001.
                                // 0x0001 is smaller than 0xF000. Wraps.
                                // Next should be smallest with K=4, which is 0x000F.
                                // My calculation is wrong? 
                                // Let's recheck.
                                // x = 0xF000 = 1111 0000 0000 0000
                                // u = 0x1000 (lowest bit)
                                // v = 0x10000 (carry out)
                                // v is 17 bits. Truncated to 16 bits? 
                                // If we use 16-bit regs, v = 0x0000.
                                // Then next = 0 | ... = 0. 
                                // Okay, we need to handle the carry.
                                // If v overflows 16 bits, we wrap around.
                                // So check if v == 0.
                                
                                // Let's refine:
                                // if (v == 0) wrapped = 1;
                                // else wrapped = 0;
                                
                                // Let's stick to a simpler counter approach since we have latency budget 128.
                                // We iterate through candidates. 
                                // But iterating 2^16 is too slow.
                                // We need the smart generation.
                                
                                // Let's refine the next_lex logic and check.
                                // x = candidate.
                                // u = x & -x;
                                // v = x + u;
                                // next_lex = v | (((v ^ x) >> 2) / u);
                                // But if v overflows (v=0), then we are done with this popcount.
                                
                                // Also, we must ensure next_lex has same popcount.
                                // If the formula is correct, it does.
                                
                                // In VALIDATE:
                                // If valid, go to COMPLETE.
                                // Else, compute next_candidate.
                                // Check if next_candidate < candidate (wrap) OR next_candidate has wrong popcount.
                                // How to check popcount?
                                // We can use a dedicated wire `popcount_next` computed from next_candidate.
                                // But next_candidate is combinational from candidate.
                                // So `popcount_next` is combinational.
                                // If `popcount_next != ones_target`, we wrap.
                                
                                // Wait, popcount calculation of next_candidate adds latency.
                                // But we are in VALIDATE state, we have 1 cycle to decide.
                                // Combinational popcount is fine.
                                
                                // So:
                                // assign next_candidate_val = v | (((v ^ x) >> 2) / u);
                                // assign next_ones = popcount(next_candidate_val);
                                // In state VALIDATE:
                                // if (next_ones == ones_target) candidate <= next_candidate_val;
                                // else begin
                                //    ones_target <= ones_target - 1;
                                //    state <= SEARCH;
                                // end
                                
                                // Corner case: if ones_target == 0.
                                // Candidate 0. Check. If fail, next_ones would be 0?
                                // x=0. u=0. Division by zero.
                                // So handle ones_target == 0 separately: if fail, impossible.
                                
                                // Also, if we decrement ones_target to 0 in SEARCH, we try 0.
                                // If 0 fails, SEARCH will decrement to -1 (underflow) -> impossible.
                                
                                // Let's implement this.
                                // We need `next_candidate` and `next_popcount` combinational blocks.
                                
                                // Combinational logic for next candidate
                                // (This logic is outside the always block in real code, 
                                // but here we can describe it inside the logic)
                                
                                // Wait, we can't use division easily in synthesis without DSPs or logic.
                                // But (v ^ x) >> 2 / u.
                                // u is a power of 2.
                                // Division by power of 2 is right shift.
                                // But u is lowest set bit.
                                // Example: u = 4'b0100. u = 4.
                                // / u is shift right by 2.
                                // So / u is right shift by ctz(x).
                                // Let's define shift amount = ctz(x) + 2.
                                // Where ctz(x) is count trailing zeros.
                                
                                // x = 0000 1100. u = 0000 0100. ctz = 2.
                                // v = x + u = 0001 0000.
                                // v^x = 0001 1100. >>2 = 0000 0111. >>ctz = 0000 0001. (Wait, >>2 + >>ctz = >>4).
                                // Formula: (((v ^ x) >> 2) >> ctz(x)).
                                // So next_lex = v | ( ((v ^ x) >> 2) >> ctz(x) ).
                                // This is much better. Shifts are cheap.
                                
                                // Need ctz(x). 
                                // ctz(x) = index of lowest 1.
                                // For x != 0:
                                // if x[0] ctz=0, else if x[1] ctz=1, etc.
                                // We can implement this with priority encoder logic.
                                
                                // Let's define `shift_amt`.
                                // shift_amt = 2 + ctz(x).
                                // ctz(x):
                                //   00:0, 01:1, 11:0 (if x[0]=1) -> logic: ~x[0] & x[1] etc.
                                //   4bit ex: 1010 -> ctz=1.
                                //   0000 -> undefined.
                                
                                // In VALIDATE state (combinational outputs):
                                // We need to determine next state and next candidate.
                                
                                // Let's structure the module with helper wires.
                                // We will assume `next_candidate_comb` and `next_valid_comb` logic.
                                
                                // Actually, to keep the code clean in the JSON response, 
                                // let's put the combinational logic in a separate `always @(*)` block.
                                
                            end
                        end
                    end
                end
                
                COMPLETE: begin
                    // Done state. Wait for reset or start to go low?
                    // Typically, we stay here until reset.
                    // But problem doesn't specify. Let's just hold values.
                    // If start goes low and high again, it restarts? 
                    // Let's assume explicit reset or restart if start goes low then high.
                    // Or just finish.
                    // Let's just stay here. 
                    // To allow restart: if !start, go to IDLE? No, wait for start to reset.
                    // Let's stick to staying done until reset.
                    // But valid/done are high.
                    // We can accept start signal to restart if needed.
                    // Let's check start. If start is low, maybe we can go back to IDLE logic next cycle.
                    // Let's just stay here. The testbench likely resets or handles it.
                end
                
                IMPOSSIBLE: begin
                    impossible <= 1'b1;
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for next candidate generation
    reg [15:0] next_cand;
    reg [4:0] next_cnt;
    reg [4:0] shift_val;
    reg [3:0] ctz; // 0 to 15
    
    always @(*) begin
        if (ones_target == 0) begin
            next_cand = 16'b0;
            next_cnt = 0;
        end else begin
            // Calculate CTZ (Count Trailing Zeros) of candidate
            // If candidate is 0, we shouldn't be here or it's handled
            // Synthesis needs safe defaults
            ctz = 0;
            if (candidate[0]) ctz = 0;
            else if (candidate[1]) ctz = 1;
            else if (candidate[2]) ctz = 2;
            else if (candidate[3]) ctz = 3;
            else if (candidate[4]) ctz = 4;
            else if (candidate[5]) ctz = 5;
            else if (candidate[6]) ctz = 6;
            else if (candidate[7]) ctz = 7;
            else if (candidate[8]) ctz = 8;
            else if (candidate[9]) ctz = 9;
            else if (candidate[10]) ctz = 10;
            else if (candidate[11]) ctz = 11;
            else if (candidate[12]) ctz = 12;
            else if (candidate[13]) ctz = 13;
            else if (candidate[14]) ctz = 14;
            else ctz = 15;
            
            // u = candidate & -candidate (lowest bit)
            // v = candidate + u
            // next = v | (((v ^ candidate) >> 2) >> ctz)
            
            // But if candidate + u overflows 16 bits (i.e. wraps to 0), we are at max.
            // If v == 0, we wrap.
            
            // We need to compute v.
            // But careful: if v overflows to 0, we handle wrap.
            
            // Let's compute v with overflow flag
            // Or just use the wrap check: if v < candidate (with overflow consideration)
            // Actually, if v == 0, it's definitely overflow (since candidate != 0).
            // What if candidate is 0xFFFF? u=1, v=0x0000.
            // So v == 0 indicates wrap.
            
            // However, v != 0 does not guarantee no wrap in MSB sense if we didn't overflow the 16-bit bus.
            // If v != 0, we are good.
            
            // Wait, `candidate + u` will wrap around.
            // If we compute `v` using addition, `v` will be the wrapped result.
            // If `v` is 0, we wrapped around. 
            // If `v` is non-zero, we are good.
            // BUT, what if `v` is non-zero but has different popcount?
            // The formula handles it.
            
            // So:
            // logic v_wrapped = (candidate + u) == 0? (only if candidate has all bits up to u set?
            // No. if candidate = 0x8000. u = 0x8000. v = 0x0000. Wrap.
            // if candidate = 0x8001. u = 1. v = 0x8002. No wrap.
            
            // So if (candidate + u) == 0, wrap.
            // However, `candidate + u` might be 0 even if we didn't hit max value with K ones.
            // Example: K=4. candidate = 0xF000. u = 0x1000. sum = 0x0000. Wrap.
            // Correct. 0xF000 is max for K=4 (11110000...).
            
            // What about K=4. candidate = 0x7FFF. u=1. sum = 0x8000. No wrap.
            // 0x7FFF has popcount 15. Not valid. 
            // So our `state <= SEARCH` logic filters this out.
            
            // So combinational logic:
            // u = candidate & -candidate (verilog `-candidate` is 2's complement)
            // v = candidate + u
            // wrap = (v == 0);
            // if wrap: next_cand = (1 << ones_target) - 1; // smallest
            // else: next_cand = v | (((v ^ candidate) >> 2) >> ctz);
            
            // Wait, if v==0, next_cand should be smallest.
            // Smallest is (1 << ones_target) - 1.
            // e.g. ones_target=4, smallest=0x000F.
            // But we are in state VALIDATE.
            // If wrap, we need to go to SEARCH and decrement ones_target.
            // So the `next_cand` logic here is only used if we stay in "same popcount" mode.
            // If wrap, we don't use next_cand. We change state.
            
            // So the VALIDATE state transition logic is:
            // if valid -> COMPLETE
            // else ->
            //   if (wrap) -> SEARCH (decrement ones_target)
            //   else -> SEARCH (update candidate, same ones_target)
            //        (Wait, state is SEARCH? No, SEARCH state is the "loop" state?)
            //        Let's re-read instructions.
            //        "State Machine: IDLE, SEARCH, VALIDATE, COMPLETE, IMPOSSIBLE"
            //        "In SEARCH state, systematically generate candidate matrices"
            //        "In VALIDATE state, check"
            
            //        So cycle: 
            //        SEARCH -> VALIDATE -> (if not valid) -> SEARCH (next candidate).
            //        If we exhausted SEARCH range (no next candidate) -> IMPOSSIBLE (or decrement).
            
            //        So in SEARCH state, we update candidate.
            //        In VALIDATE, we check.
            
            //        So VALIDATE needs to tell SEARCH what to do.
            
            //        Refined Logic:
            //        SEARCH: 
            //          if (first_time_for_this_popcount) load smallest.
            //          else candidate <= next_candidate (loaded from previous cycle)
            //          (Or compute next in SEARCH state).
            
            //        VALIDATE:
            //          if (match) -> COMPLETE
            //          else if (candidate == max_for_popcount) -> decrement popcount
            //          else -> tell SEARCH to use next_candidate.
            
            //        Let's simplify:
            //        Merge SEARCH and VALIDATE?
            //        No, instructions say separate states.
            
            //        Let's use 2 cycle approach (except COMPLETE/IMPOSSIBLE):
            //        SEARCH: Compute next candidate (or load initial). Transition to VALIDATE.
            //        VALIDATE: Check. If valid -> COMPLETE. If invalid -> check if exhausted. If exhausted -> SEARCH (decrement). If not exhausted -> SEARCH (use next).
            
            //        But we need to compute `next` in SEARCH or VALIDATE?
            //        If we compute `next` in SEARCH, we need to know if current candidate (before update) is valid.
            //        No, SEARCH generates a candidate.
            //        VALIDATE checks it.
            
            //        So:
            //        SEARCH state does:
            //           if (state == SEARCH && entering from IDLE) -> candidate = max_val (ones_target)
            //           if (state == SEARCH && entering from VALIDATE) -> candidate = next_candidate
            //        VALIDATE checks.
            
            //        So we need `next_candidate` wire.
            //        And we need `is_exhausted` wire.
            
            //        `is_exhausted` is true if `candidate` is the max for `ones_target`.
            //        Max for `ones_target` is `((1 << 16) - (1 << (16 - ones_target)))`.
            //        Check: ones_target=4 -> 0xF000.
            //        Let's call it `max_mask`.
            
            //        So in VALIDATE:
            //        if (valid) -> COMPLETE
            //        else if (candidate == max_mask) -> SEARCH (decrement ones_target, load new start)
            //        else -> SEARCH (load next_candidate)
            
            //        Wait, if we decrement ones_target, we need to load the SMALLEST for the new count.
            //        That happens in SEARCH state.
            
            //        So in VALIDATE:
            //        if (valid) ...
            //        else if (exhausted) ...
            //          state <= SEARCH;
            //          ones_target <= ones_target - 1; // Handle underflow to 0 then -1?
            //          // If ones_target becomes 15 from 16, we need a flag to tell SEARCH to load 0x7FFF.
            //          // Actually, SEARCH can check: if ones_target changed.
            //        else ...
            //          state <= SEARCH;
            //          next_cand_signal <= next_lex; // How to pass to SEARCH?
            //          // We can update candidate directly in VALIDATE? 
            //          // Instructions say output reg, so candidate is intermediate.
            //          // Yes, we can update candidate in VALIDATE state logic before going to SEARCH?
            //          // Or better, use a "load_new_start" flag.
            
            //        Let's try to keep candidate update in SEARCH state.
            
            //        Case 1: VALIDATE finds match -> COMPLETE.
            //        Case 2: VALIDATE fails, but NOT exhausted -> Go to SEARCH. 
            //                SEARCH computes next candidate and loops back to VALIDATE.
            //        Case 3: VALIDATE fails, EXHAUSTED -> Go to SEARCH.
            //                SEARCH loads new start (for smaller ones_target) and loops back.
            //        Case 4: SEARCH finds popcount mismatch (because we loaded new start or incremented) -> loop SEARCH?
            //                No, we loaded new start, it should match.
            
            //        Refined Cycle:
            //        SEARCH (Cycle 1):
            //          Update candidate.
            //          Transition to VALIDATE.
            //        VALIDATE (Cycle 2):
            //          Check candidate.
            //          Transition to COMPLETE/SEARCH/IMPOSSIBLE.
            
            //        What updates candidate in SEARCH?
            //        If entering from IDLE: Load Max for ones_target.
            //        If entering from VALIDATE (fail, not exhausted): Load next_lex.
            //        If entering from VALIDATE (fail, exhausted): Load smallest for (ones_target-1).
            
            //        How to know the reason?
            //        We can use a flag `load_initial` or `exhausted_signal`.
            
            //        Let's use a 1-bit register `exhausted_flag` in SEARCH.
            //        If `exhausted_flag` is set, it means we just decremented ones_target (or started) and need to load the smallest (which is same as initial load).
            //        Actually, initial load of a popcount level is the largest? 
            //        No, instructions say: "Try matrices with 16 ones, then 15, etc."
            //        "maintaining lexicographic ordering"
            //        "minimum binary value (lexicographic order)"
            //        This implies: Start with 16 ones (0xFFFF). Check.
            //        Next: 15 ones. Start with 0x7FFF (lexicographically first with 15 ones).
            //        Next: 0x3FFF.
            //        Then we iterate: 0x3FFF -> 0x5FFF?
            //        No, lexicographic order: 0x7FFF, then next with 15 ones is `next_lex(0x7FFF)`.
            
            //        So for a given K, we start with `max_val(K)` or `min_val(K)`?
            //        "maximum 1's, then minimum binary value"
            //        So for K=15, we want 0x7FFF (min binary value with 15 ones).
            //        So we load 0x7FFF first.
            //        Then iterate `next_lex`.
            //        If we reach max (0xFFFE? No, max with 15 ones is 0x7FFF...
            //        Wait, 0x7FFF is 0111111111111111 (15 ones).
            //        What is the "largest" binary value with 15 ones? 1111111111111110 (0xFFFE).
            //        But lexicographic ordering usually means smallest first.
            //        "Goal: Maximum 1's, then minimum binary value (lexicographic order)."
            //        This means we find the solution with most 1s. If multiple, smallest binary.
            //        So we start K=16. Check 0xFFFF. 
            //        If invalid, we try next.
            //        Wait, if K=16, only 0xFFFF. 
            //        If K=15. Start 0x7FFF. Check. If invalid, next. 
            //        So SEARCH state needs to know if it's the "first" try for K.
            
            //        Let's use a flag `first_try`.
            //        If `first_try` is high in SEARCH:
            //          Load `max_val(K)`? No, "minimum binary value".
            //          Smallest binary value with K ones is (1<<K)-1.
            //          e.g. K=4 -> 0000000000001111 = 0x000F.
            //          Wait, is 0x000F "smaller" than 0x00F0? Yes.
            //          But lexicographic order: scan bits MSB to LSB.
            //          0x000F = 0000...1111
            //          0x00F0 = 0000...1111 (shifted) -> 0x00F0 = 0000000011110000.
            //          Compare MSB: equal. LSB: 0x000F has 1s at LSB. 0x00F0 has 1s at middle.
            //          Binary value: 0x00F0 (240) > 0x000F (15).
            //          So 0x000F is smaller.
            //          So we start with (1<<K)-1.
            //          Wait, instructions: "Try matrices with 16 ones, then 15, etc."
            //          For K=15, start is 0x7FFF (which is (1<<15) - 1).
            //          For K=14, start is 0x3FFF.
            //          So yes, start with `(1 << K) - 1`.
            
            //        Then, if invalid, `next_lex`.
            //        If `next_lex` wraps to `(1<<K)-1` (or has popcount != K), we exhaust K.
            
            //        So logic:
            //        SEARCH:
            //          if (first_try_for_K) candidate <= (1 << ones_target) - 1;
            //          else candidate <= next_lex;
            //        VALIDATE:
            //          if valid -> COMPLETE
            //          else if (candidate is max for K) -> exhaust K (decrement)
            //          else -> go to SEARCH (set first_try=0)
            
            //        How to check "max for K"?
            //        Max for K is `(1 << 16) - (1 << (16-K))`.
            //        e.g. K=15 -> `0x10000 - 0x0002` = `0xFFFE`? No.
            //        `(1<<16)` is 0x10000 (17 bits).
            //        `(1<<16)-1` is 0xFFFF.
            //        `(1<<16) - (1<<(16-K))` -> `(1<<K)`? No.
            //        Let's use mask: `~((1<<(16-K))-1)` if 16 bits? No.
            //        Max with K ones: set top K bits to 1.
            //        `mask = (1<<K)-1;` then `mask << (16-K)`.
            //        e.g. K=4. mask=0x000F. `mask << 12` = `0xF000`.
            //        So `max_for_K = ((1<<K)-1) << (16-K)`.
            
            //        If `candidate == max_for_K`, then exhausted.
            
            //        Now, back to the `next_lex` calculation.
            //        We need `next_lex` in VALIDATE state to decide if we go to SEARCH (update) or SEARCH (exhaust).
            //        Or we can just compute `next_lex` and check `next_lex` popcount.
            //        If `popcount(next_lex) != ones_target`, then we are at max.
            //        This is robust.
            
            //        So in VALIDATE:
            //        Calculate `next_lex` (combinational).
            //        Calculate `next_popcount` (combinational).
            //        If valid -> COMPLETE
            //        else if (`next_popcount` != `ones_target`) -> 
            //            state <= SEARCH;
            //            exhausted <= 1; // Signal to load new start
            //        else ->
            //            state <= SEARCH;
            //            candidate_temp <= next_lex; // Signal to use next
            
            //        Let's implement this.
            
            //        Combinational block for `next_lex` and `next_popcount`.
            
            //        Helper for popcount:
            //        We can reuse the `popcount` wire logic.
            
            //        Let's write the code logic.
            
            //        Wait, `next_lex` logic requires division by power of 2.
            //        `ctz` is the shift amount.
            //        `u = candidate & -candidate;`
            //        `v = candidate + u;`
            //        `next_lex = v | (((v ^ candidate) >> 2) >> ctz);`
            //        `next_popcount = count_ones(next_lex);`
            
            //        But `next_popcount` might take logic depth.
            //        We have 1 cycle. It should be fine.
            
            //        Let's simplify `next_lex` for synthesis.
            //        The `ctz` calculation can be done by:
            //        ctz = 0; if (!candidate[0]) ctz++; ...
            //        This is a priority encoder.
            
            //        Let's write the `always @(*)` block for next state logic.
            
            //        One issue: `v = candidate + u`. 
            //        If we use Verilog `+`, it handles 16-bit arithmetic.
            //        If `candidate` is all 1s (0xFFFF) and K=16, u=1. `v = 0`. Wrap.
            //        If `candidate` is max for K (e.g. 0xF000), u=0x1000. `v = 0`. Wrap.
            //        So `v == 0` means wrap.
            //        If wrap, `next_popcount` will be 0 (since 0 | ... = 0).
            //        So checking `next_popcount != ones_target` handles wrap.
            
            //        BUT, if `v` is not 0 but `next_lex` logic produces wrong popcount?
            //        Standard algorithm guarantees same popcount.
            //        Only exception is overflow.
            
            //        So we rely on `next_popcount != ones_target`.
            
            //        Let's define:
            //        `comb_next_candidate` and `comb_next_valid` (meaning next is valid popcount).
            //        `comb_exhausted` = !comb_next_valid.
            
            //        Inside `always @(*)`:
            //          // Calculate u, v, ctz
            //          // Calculate next_lex
            //          // Calculate popcount of next_lex
            //          // Compare
            
            //        BUT, `ctz` logic depends on `candidate`. 
            //        If `candidate` is 0, u=0. Division by zero.
            //        Handled by `ones_target` check.
            
            //        Let's assemble the `always @(*)` logic.
            
            //        Wait, I need to generate the code. 
            //        I will use the combinational block for next candidate generation.
            
            //        Structure:
            //        module matrix_recovery(...)
            //        reg [15:0] candidate;
            //        wire [15:0] next_cand_comb;
            //        wire next_valid_comb;
            //        
            //        always @(*) begin
            //            // Logic for next_cand_comb and next_valid_comb
            //            // based on candidate
            //        end
            //        
            //        always @(posedge clk...) begin
            //            // State machine
            //            // In SEARCH: update candidate based on flag
            //            // In VALIDATE: transition, update flags
            //        end
            //        
            //        Endmodule
            
            //        Let's write the `always @(*)` for comb logic.
            
            //        Note: `next_lex` logic:
            //        u = candidate & -candidate;
            //        v = candidate + u;
            //        next_cand_comb = v | (((v ^ candidate) >> 2) >> ctz);
            //        But if v==0, next_cand_comb = 0 | ... = 0. Popcount 0.
            //        If ones_target > 0, popcount mismatch -> exhausted.
            //        If ones_target == 0, popcount 0 matches.
            //        So `next_valid_comb` is true if `popcount(next_cand_comb) == ones_target`.
            
            //        Let's implement this.
            
            //        To save code space and complexity, maybe I can embed the logic in the sequential block.
            //        But for clarity, combinational block is better.
            
            //        Let's write the combinational block.
            //        We need `ctz`. 
            //        ctz = 0;
            //        if (candidate[0]) ctz = 0;
            //        else if (candidate[1]) ctz = 1;
            //        ... up to 15.
            //        If candidate is 0, ctz can be 0 (default).
            
            //        Also need `u` and `v`.
            //        u = candidate & -candidate; (2's complement)
            //        v = candidate + u;
            
            //        Then `temp = ((v ^ candidate) >> 2);`
            //        `next_cand_comb = v | (temp >> ctz);`
            //        Then `popcount_next`.
            //        Then `next_valid_comb = (popcount_next == ones_target);`
            
            //        Let's write the Verilog.

            // Calculate next candidate and validity
            // We need a separate combinational block or assign statements.
            // Let's use assign statements for `next_cand_comb` and `next_valid_comb`.
            // But `ctz` needs an always block or a case statement.
            // Let's use `assign` with ternary operators for `ctz`.
            
            // This will be verbose but functional.
            
            // Let's go back to the `always @(*)` block in the response code.
            // It will be placed inside the module.
            
            // One detail: `candidate` is updated in SEARCH state.
            // So the combinational logic for next candidate works on the current `candidate`.
            
            // Validated logic:
            // SEARCH: 
            //   if (state == SEARCH) begin
            //      if (first_load_flag) candidate <= (1 << ones_target) - 1;
            //      else candidate <= next_cand_comb;
            //      state <= VALIDATE;
            //   end
            // VALIDATE:
            //   if (valid) COMPLETE;
            //   else if (!next_valid_comb) begin
            //        // Exhausted current popcount
            //        state <= SEARCH;
            //        if (ones_target == 0) IMPOSSIBLE; // Wait, if 0 and invalid, impossible.
            //        else begin
            //           ones_target <= ones_target - 1;
            //           first_load_flag <= 1;
            //        end
            //   end else begin
            //        // Next candidate ready
            //        state <= SEARCH;
            //        first_load_flag <= 0;
            //   end
            //   Note: In VALIDATE, `next_cand_comb` is valid only if `next_valid_comb` is true.
            //   So in SEARCH, we can just use `next_cand_comb` blindly if `first_load_flag` is low.
            //   Wait, no. If we transition from VALIDATE (exhausted), we decrement ones_target.
            //   We need to load `(1<<ones_target)-1` in the next SEARCH cycle.
            //   So `first_load_flag` controls whether we load start or next.
            
            //   When do we set `first_load_flag`?
            //   1. Start (IDLE -> SEARCH).
            //   2. Exhausted level (VALIDATE -> SEARCH).
            //   We need a signal to tell SEARCH "load initial for current ones_target".
            //   Let's call it `load_initial_start`.
            
            //   If `load_initial_start` is high in SEARCH:
            //      candidate <= (1 << ones_target) - 1;
            //   else:
            //      candidate <= next_cand_comb;
            //   Then clear `load_initial_start`.
            
            //   How to set `load_initial_start`?
            //   In IDLE->SEARCH transition: set it.
            //   In VALIDATE->SEARCH (exhausted): set it.
            //   So we need a register `do_initial_load`.
            
            //   Also, if ones_target becomes 0, we try candidate 0.
            //   If 0 fails, we go to VALIDATE. `next_valid_comb` will be false (since next popcount won't be 0).
            //   Wait, `next_lex` for 0: u=0 -> division by 0.
            //   Handled: if ones_target == 0, we don't compute next_lex.
            //   So `next_valid_comb` logic must handle ones_target == 0.
            //   If ones_target == 0, `next_valid_comb` is always false (since we can't generate next).
            //   So if candidate 0 fails, we go to IMPOSSIBLE.
            
            //   Actually, if ones_target == 0 and candidate 0 fails, we are exhausted.
            //   We decrement ones_target -> 255 (wrap) -> should stop.
            //   So in VALIDATE:
            //   if (ones_target == 0 && !valid) -> IMPOSSIBLE.
            
            //   Let's refine:
            //   VALIDATE:
            //   if (valid) ...
            //   else if (ones_target == 0) ...
            //   else if (!next_valid_comb) ...
            //   else ...
            
            //   Wait, `ones_target` is decremented in SEARCH or VALIDATE?
            //   Let's decrement in VALIDATE when exhausted.
            //   So `ones_target` logic:
            //   IDLE: load 16.
            //   VALIDATE (exhausted, ones_target > 0): ones_target <= ones_target - 1.
            //   If it becomes 0, next SEARCH will try 0.
            //   If VALIDATE fails on 0, it goes to IMPOSSIBLE.
            
            //   This seems correct.
            
            //   So the plan:
            //   1. `always @(*)` for `next_cand_comb` and `next_valid_comb`.
            //   2. `always @(posedge clk)` for state and registers.
            
            //   Let's implement `next_cand_comb`.
            //   We need `ctz`. 
            //   `ctz` logic:
            //   `ctz = 0;`
            //   `if (candidate[0]) ctz = 0;`
            //   `else if (candidate[1]) ctz = 1;`
            //   ... this is a priority encoder.
            //   In Verilog `always @(*)` block:
            //   `casez (candidate)`
            //      `15'b???????????????1: ctz = 0;`
            //      `15'b??????????????10: ctz = 1;`
            //      ... this is huge.
            //   Better:
            //   `ctz = 0;`
            //   `if (!candidate[0]) ctz = ctz + 1;`
            //   `if (!candidate[1] && candidate[0]) ctz = ctz + 1;` -> No.
            //   Correct logic for CTZ (Count Trailing Zeros):
            //   `if (candidate[0]) ctz = 0;`
            //   `else if (candidate[1]) ctz = 1;`
            //   `else if (candidate[2]) ctz = 2;`
            //   ... 
            //   `else ctz = 16;`
            
            //   Since candidate is 16 bits, max 15.
            //   If candidate is 0, `ctz` is undefined or 16.
            //   But `next_cand_comb` logic is only used if `candidate` is valid for popcount > 0.
            //   Actually, we need to be safe.
            
            //   Let's use the combinational block.
            
            //   We need `do_initial_load` register.
            //   If `do_initial_load` is 1 in SEARCH, load `(1 << ones_target) - 1`.
            //   Else load `next_cand_comb`.
            
            //   `do_initial_load` set to 1:
            //   - IDLE -> SEARCH (start)
            //   - VALIDATE -> SEARCH (exhausted)
            //   `do_initial_load` set to 0:
            //   - SEARCH -> VALIDATE (after loading).
            
            //   Actually, `do_initial_load` is only needed in SEARCH state.
            //   We can combine `state == SEARCH` and `do_initial_load`.
            
            //   Let's write the code now.
            
            //   Summary of `always @(*)` logic:
            //   1. Calculate u, v, ctz.
            //   2. Calculate next_cand.
            //   3. Calculate popcount of next_cand.
            //   4. Check validity.
            
            //   Summary of sequential logic:
            //   IDLE: on start -> SEARCH, do_initial_load=1, ones_target=16.
            //   SEARCH: 
            //      if (do_initial_load) candidate <= (1<<ones_target)-1;
            //      else candidate <= next_cand;
            //      do_initial_load <= 0;
            //      state <= VALIDATE;
            //   VALIDATE:
            //      if (row_xor == row_parity && col_xor == col_parity) -> COMPLETE.
            //      else if (ones_target == 0) -> IMPOSSIBLE. (Candidate 0 failed).
            //      else if (!next_valid) -> SEARCH (do_initial_load=1, ones_target--).
            //      else -> SEARCH (do_initial_load=0).
            //   COMPLETE/IMPOSSIBLE: hold.
            
            //   Wait, what if `ones_target` becomes 0 from 1?
            //   If level 1 exhausted (0x0001 checked, next is 0x0002, ... 0x8000).
            //   After 0x8000, next popcount is 0. `next_valid` is false.
            //   We decrement ones_target to 0.
            //   `do_initial_load` = 1.
            //   SEARCH: loads (1<<0)-1 = 0.
            //   VALIDATE: checks 0.
            //   If 0 fails, ones_target == 0, so -> IMPOSSIBLE.
            //   Correct.
            
            //   Let's refine `next_valid`.
            //   `next_valid` = (popcount(next_cand) == ones_target).
            //   If ones_target is 0, we don't compute next_cand (div by zero).
            //   So in `always @(*)`, if ones_target == 0, next_valid = 0.
            
            //   Let's implement `ctz` logic.
            //   `ctz = 0;`
            //   `if (candidate[0]) ctz = 0;`
            //   `else if (candidate[1]) ctz = 1;`
            //   `else if (candidate[2]) ctz = 2;`
            //   ... up to 15.
            //   `else ctz = 16;`
            
            //   Then `u = candidate & -candidate;` (2's complement works in Verilog)
            //   `v = candidate + u;`
            //   `temp = ((v ^ candidate) >> 2) >> ctz;`
            //   `next_cand = v | temp;`
            
            //   Let's write the code.
        end
    end

endmodule

// Helper module for popcount (if needed, but we can inline it)
// Or just use the wire popcount logic we defined earlier.
// The `popcount` wire we defined earlier uses `candidate`.
// We need popcount of `next_cand`.
// Let's define a function or replicate logic.
// Replicating logic is simple for 16 bits.

module matrix_recovery(
    input clk,
    input rst_n,
    input start,
    input [3:0] row_parity,
    input [3:0] col_parity,
    output reg [15:0] matrix_out,
    output reg valid,
    output reg impossible,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam SEARCH = 3'b010;
    localparam VALIDATE = 3'b100;
    localparam COMPLETE = 3'b101; // distinct from others
    localparam IMPOSSIBLE_STATE = 3'b110;

    reg [2:0] state;
    reg [15:0] candidate;
    reg [4:0] ones_target;
    reg do_initial_load;

    // Parity check signals
    wire [3:0] row_xor;
    wire [3:0] col_xor;
    wire is_valid;

    assign row_xor[0] = candidate[0] ^ candidate[1] ^ candidate[2] ^ candidate[3];
    assign row_xor[1] = candidate[4] ^ candidate[5] ^ candidate[6] ^ candidate[7];
    assign row_xor[2] = candidate[8] ^ candidate[9] ^ candidate[10] ^ candidate[11];
    assign row_xor[3] = candidate[12] ^ candidate[13] ^ candidate[14] ^ candidate[15];
    
    assign col_xor[0] = candidate[0] ^ candidate[4] ^ candidate[8] ^ candidate[12];
    assign col_xor[1] = candidate[1] ^ candidate[5] ^ candidate[9] ^ candidate[13];
    assign col_xor[2] = candidate[2] ^ candidate[6] ^ candidate[10] ^ candidate[14];
    assign col_xor[3] = candidate[3] ^ candidate[7] ^ candidate[11] ^ candidate[15];

    assign is_valid = (row_xor == row_parity) && (col_xor == col_parity);

    // Combinational logic for next candidate generation
    reg [15:0] next_cand;
    reg next_valid;
    
    // Helper for popcount of next_cand
    wire [4:0] next_pop;
    assign next_pop = next_cand[0] + next_cand[1] + next_cand[2] + next_cand[3] +
                      next_cand[4] + next_cand[5] + next_cand[6] + next_cand[7] +
                      next_cand[8] + next_cand[9] + next_cand[10] + next_cand[11] +
                      next_cand[12] + next_cand[13] + next_cand[14] + next_cand[15];

    always @(*) begin
        if (ones_target == 0) begin
            next_cand = 16'b0;
            next_valid = 1'b0;
        end else begin
            // Calculate u, v, ctz
            reg [15:0] u;
            reg [15:0] v;
            reg [4:0] ctz_reg; // 0 to 16
            
            // 2's complement negation for -candidate
            u = candidate & -candidate;
            v = candidate + u;
            
            // Count Trailing Zeros (priority encoder)
            ctz_reg = 16;
            if (candidate[0]) ctz_reg = 0;
            else if (candidate[1]) ctz_reg = 1;
            else if (candidate[2]) ctz_reg = 2;
            else if (candidate[3]) ctz_reg = 3;
            else if (candidate[4]) ctz_reg = 4;
            else if (candidate[5]) ctz_reg = 5;
            else if (candidate[6]) ctz_reg = 6;
            else if (candidate[7]) ctz_reg = 7;
            else if (candidate[8]) ctz_reg = 8;
            else if (candidate[9]) ctz_reg = 9;
            else if (candidate[10]) ctz_reg = 10;
            else if (candidate[11]) ctz_reg = 11;
            else if (candidate[12]) ctz_reg = 12;
            else if (candidate[13]) ctz_reg = 13;
            else if (candidate[14]) ctz_reg = 14;
            else if (candidate[15]) ctz_reg = 15;
            
            // Next lexicographic candidate
            // If v == 0, it means overflow. 
            // If overflow, we are at max, so next_cand wraps to small value (but popcount changes).
            // So we can just compute it. If v==0, result is 0 (popcount 0).
            // If v!=0, compute normally.
            
            if (v == 0) begin
                next_cand = 0; // Will fail popcount check
            end else begin
                next_cand = v | (((v ^ candidate) >> 2) >> ctz_reg);
            end
            
            // Check validity
            if (next_pop == ones_target) begin
                next_valid = 1'b1;
            end else begin
                next_valid = 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            matrix_out <= 16'b0;
            valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
            candidate <= 16'b0;
            ones_target <= 5'd16;
            do_initial_load <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                        ones_target <= 16;
                        do_initial_load <= 1'b1;
                    end
                end
                
                SEARCH: begin
                    // Load candidate
                    if (do_initial_load) begin
                        // Load start for this popcount: (1 << ones_target) - 1
                        candidate <= (1 << ones_target) - 1;
                    end else begin
                        // Load next candidate generated previously
                        candidate <= next_cand;
                    end
                    // Move to validate
                    state <= VALIDATE;
                end
                
                VALIDATE: begin
                    if (is_valid) begin
                        state <= COMPLETE;
                        matrix_out <= candidate;
                        valid <= 1'b1;
                        done <= 1'b1;
                    end else begin
                        // Check if we should stop or continue
                        if (ones_target == 0) begin
                            // Tried 0 and failed. Impossible.
                            state <= IMPOSSIBLE_STATE;
                            impossible <= 1'b1;
                            done <= 1'b1;
                        end else if (!next_valid) begin
                            // Current level exhausted. Decrement count.
                            state <= SEARCH;
                            do_initial_load <= 1'b1;
                            ones_target <= ones_target - 1;
                        end else begin
                            // Continue current level
                            state <= SEARCH;
                            do_initial_load <= 1'b0;
                        end
                    end
                end
                
                COMPLETE, IMPOSSIBLE_STATE: begin
                    // Hold state
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
