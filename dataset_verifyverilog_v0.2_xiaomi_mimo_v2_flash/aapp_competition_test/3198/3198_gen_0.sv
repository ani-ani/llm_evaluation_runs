module typo_detector (
    input wire clk,
    input wire rst_n,
    input wire in_valid,
    input wire [CHARS*8-1:0] in_word,
    input wire in_is_last,
    output reg out_valid,
    output reg [CHARS*8-1:0] out_word,
    output reg done
);

    parameter CHARS = 8;
    parameter MAX_WORDS = 16;
    parameter WORD_BITS = CHARS * 8;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam CHECK = 3'b010;
    localparam DELETE_GEN = 3'b011;
    localparam VERIFY = 3'b100;
    localparam OUTPUT = 3'b101;
    localparam FINISH = 3'b110;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] head_ptr; // Pointer to next free slot in dictionary (0-15)
    reg [4:0] check_idx; // Index of word currently being checked (0 to head_ptr-1)
    reg [3:0] del_idx;   // Deletion index (0 to 7)
    reg [WORD_BITS-1:0] dict_mem [0:MAX_WORDS-1];
    reg [WORD_BITS-1:0] current_word; // Word currently being verified
    reg [WORD_BITS-1:0] candidate;    // Generated deletion variant
    reg is_last_word;
    reg match_found;

    // Combinational Logic for Candidate Generation
    integer k;
    reg [WORD_BITS-1:0] temp_candidate;
    
    always @(*) begin
        // Default candidate is current_word
        temp_candidate = current_word;
        
        // Shift logic: Move characters from del_idx+1 to end into positions del_idx to end-1
        for (k = 0; k < CHARS - 1; k = k + 1) begin
            if (k >= del_idx) begin
                // Source index is k+1, Destination is k
                // 8 bits per char, so extract 8-bit slice and place it
                temp_candidate[(k*8)+:8] = current_word[((k+1)*8)+:8];
            end
        end
        // Null pad the last character
        temp_candidate[(CHARS-1)*8+:8] = 8'h00;
    end

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            done <= 1'b0;
            head_ptr <= 5'd0;
            check_idx <= 5'd0;
            del_idx <= 4'd0;
            out_word <= {WORD_BITS{1'b0}};
            current_word <= {WORD_BITS{1'b0}};
            candidate <= {WORD_BITS{1'b0}};
            is_last_word <= 1'b0;
            match_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    head_ptr <= 5'd0;
                    check_idx <= 5'd0;
                    del_idx <= 4'd0;
                    is_last_word <= 1'b0;
                    if (in_valid) begin
                        // Load first word directly to state transition handles it, 
                        // but here we might need to capture inputs if they persist or use combinational logic.
                        // Typically we register inputs in LOAD state or capture them here.
                        // Let's handle capture in LOAD state or verify logic.
                        // The request says "Loads words one by one". 
                        // We will move to LOAD on in_valid.
                    end
                end

                LOAD: begin
                    if (in_valid) begin
                        dict_mem[head_ptr] <= in_word;
                        head_ptr <= head_ptr + 1'b1;
                        is_last_word <= in_is_last;
                    end
                end

                CHECK: begin
                    // Check if we are done checking all stored words for the current input word
                    // Note: current_word should hold the word we are checking against the dictionary.
                    // Wait, the logic is: Check NEW word against OLD words? OR Check OLD words if NEW word makes them typos?
                    // Prompt: "For each word, it generates all possible deletion variants... and checks if any variant matches a word already stored"
                    // This means: Take CURRENT word, generate variants, check against STORED words.
                    // So we need to wait until dictionary has previous words.
                    // head_ptr points to next free slot. If head_ptr > 0, we have stored words.
                    // If head_ptr == 0, this is the first word, cannot be a typo.
                    // If head_ptr > 0, we check current_word against dict_mem[0]...dict_mem[head_ptr-1].
                    
                    // Wait, the description says: "After loading a word, check if it is a typo against previously loaded words."
                    // Correct.
                    
                    // If head_ptr == 1 (just loaded the first word), no check needed. Go to OUTPUT (or wait for next).
                    // If head_ptr > 1, we need to iterate.
                    
                    // Optimization: We don't need to check the NEW word against the dictionary.
                    // We need to check if the NEW word IS a typo of an OLD word? 
                    // "Rule: Deleting a single character results in another word".
                    // This implies: If Word A becomes Word B by deletion, Word A is typo.
                    // Prompt: "check if it is a typo against previously loaded words".
                    // Interpretation: Is `current_word` (the one just loaded) a typo of `stored_word`?
                    // NO. Rule: `current_word` -> `variant`. Is `variant` == `stored_word`?
                    // So we generate variants of `current_word` and match against `dict_mem`.
                    // Wait, the rule is: `current_word` is a typo if deleting a char gives `dict_mem`.
                    // So we iterate `current_word` vs `dict_mem`.
                    // BUT, `current_word` is the NEW word. We haven't loaded it into `dict_mem` yet? 
                    // Actually, we loaded it in LOAD state. So it is in `dict_mem[head_ptr-1]`.
                    // We should check `dict_mem[head_ptr-1]` against `dict_mem[0]...dict_mem[head_ptr-2]`.
                    // So `current_word` should be `dict_mem[head_ptr-1]`.
                    
                    // State CHECK setup:
                    // current_word <= dict_mem[head_ptr-1];
                    // check_idx <= 0;
                    
                    // If head_ptr <= 1, skip to OUTPUT (or directly to IDLE if not last).
                    // However, `OUTPUT` state is used to assert `out_valid`.
                    
                    if (head_ptr <= 1) begin
                        // No previous words to check against.
                        // Just go to OUTPUT. (out_valid will remain 0 from previous or reset)
                    end else begin
                        // We need to start the verification loop.
                        // We will do loop in DELETE_GEN/VERIFY.
                    end
                end

                DELETE_GEN: begin
                    // Generate candidate based on current_word and del_idx
                    candidate <= temp_candidate;
                end

                VERIFY: begin
                    // Compare candidate with dict_mem[check_idx]
                    // If match found:
                    match_found <= (candidate == dict_mem[check_idx]);
                    
                    // Increment check_idx
                    if (check_idx < head_ptr - 2) begin // -1 for self, -1 for range check (0-based)
                        check_idx <= check_idx + 1'b1;
                        next_state <= DELETE_GEN; // Loop back to generate/delete for same word, next stored word
                    end else begin
                        // Finished checking all stored words for this delete variant?
                        // Wait. We need to iterate BOTH stored words AND deletion indices.
                        // The current logic handles Stored Word iteration for a fixed Deletion Index.
                        // We need a nested loop or combined state.
                        
                        // Let's do: 
                        // Outer Loop: Deletion Index (0 to 7)
                        // Inner Loop: Dictionary Words (0 to head_ptr-2)
                        
                        // If inner loop done: Increment Deletion Index, reset check_idx.
                        // If outer loop done: Move to OUTPUT.
                        
                        if (match_found) begin
                            // Found a match, we can stop and go to OUTPUT
                            // Or continue if we want to find all? Just find one.
                            next_state <= OUTPUT;
                        end else begin
                            // Inner loop finished for this deletion index
                            if (del_idx < CHARS - 1) begin // Can delete up to CHARS-1? 
                                // Actually, deleting last char (index 7) results in word length 7. 
                                // If we pad with nulls, it's valid.
                                // So del_idx goes 0 to 7.
                                // After checking all stored words for del_idx X:
                                // Increment del_idx.
                                del_idx <= del_idx + 1'b1;
                                check_idx <= 5'd0;
                                next_state <= DELETE_GEN; // Go generate next candidate
                                
                                if (del_idx == CHARS - 1) begin
                                    // All deletion indices checked, no match found
                                    next_state <= OUTPUT;
                                end
                            end else begin
                                next_state <= OUTPUT;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    // If match_found was high OR if it became high during VERIFY logic (which sets match_found register)
                    // Note: match_found is a sticky register for the current word check.
                    // We need to check if it's high. 
                    // Also we need to handle the case where head_ptr <= 1 (no check).
                    
                    // We need to capture the result of the check.
                    // If head_ptr <= 1, match_found is 0.
                    // If we found a match, out_valid goes high.
                    
                    if (match_found) begin
                        out_valid <= 1'b1;
                        out_word <= current_word;
                    end else begin
                        out_valid <= 1'b0;
                    end
                    
                    // Transition
                    if (is_last_word) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= IDLE; // Wait for next input
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    out_valid <= 1'b0;
                end
            endcase
            
            // Special handling for state entry actions to keep sequential logic clean
            if (state != next_state) begin
                case (next_state)
                    CHECK: begin
                        // Reset counters for the verification loops
                        check_idx <= 5'd0;
                        del_idx <= 4'd0;
                        current_word <= dict_mem[head_ptr-1]; // The word we just loaded
                        match_found <= 1'b0;
                        // Start generation immediately
                        // But we are in state transition, next cycle will be DELETE_GEN.
                    end
                    DELETE_GEN: begin
                        // Logic handled in combinational block above, just waiting for latch
                    end
                    VERIFY: begin
                        // Logic handled in combinational block above
                    end
                    LOAD: begin
                        // Waiting for input
                    end
                    IDLE: begin
                        // Reset outputs for next word
                        out_valid <= 1'b0;
                    end
                endcase
            end else if (state == CHECK && next_state == CHECK) begin
                 // Just entered CHECK? No, if we are staying, it was handled by IDLE->CHECK transition logic?
                 // Actually, if we are in state CHECK, and we want to go to DELETE_GEN immediately (no delay):
                 // We can force next_state = DELETE_GEN if we are in CHECK.
                 // But typically FSMs wait one cycle.
                 // Let's add a logic to move from CHECK to DELETE_GEN immediately if check conditions met.
                 
                 // Actually, let's fix the transition logic to be cleaner.
                 // Current block: Update registers on posedge.
                 // Next state logic determines where we go.
                 
                 // If state == CHECK:
                 if (head_ptr > 1) begin
                     next_state <= DELETE_GEN;
                 end else begin
                     // No words to check against
                     next_state <= OUTPUT;
                 end
            end else if (state == DELETE_GEN && next_state == DELETE_GEN) begin
                next_state <= VERIFY;
            end else if (state == VERIFY && next_state == VERIFY) begin
                // Inside the loop, we need to decide next step based on counters
                // But wait, if match_found becomes high, we want to go to OUTPUT.
                // The logic inside the state block handles transitions based on counters.
                // However, if we find a match in VERIFY state (e.g. comparing this cycle),
                // the match_found register updates at the end of the cycle.
                // We need to check it for the next state decision.
                
                // But we already set next_state based on check_idx logic.
                // If match_found becomes high, we are already committed to the loop (unless we added check).
                // Let's modify the logic inside VERIFY to handle match_found immediately.
                
                // Corrected logic for VERIFY state block:
                // It sets match_found. 
                // It sets next_state based on counters.
                // BUT if match_found happens, we should stop loop.
                // So inside VERIFY block:
                // if (candidate == dict_mem[check_idx]) match_found <= 1;
                // if (match_found || (check_idx == ... && del_idx == ...)) ...
                
                // Actually, the register `match_found` updates at the end of the cycle.
                // So in the *current* cycle, we can't use it to change `next_state` for the *next* cycle if we rely on it being high.
                // However, we can use a combinational signal `match_detected` for the immediate transition.
            end
        end
    end

    // Re-implementing the sequential logic to handle the loop structure correctly
    // and match detection correctly.
    
    // Combinational helper for matching
    wire match_detected = (candidate == dict_mem[check_idx]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs
            out_valid <= 1'b0;
            done <= 1'b0;
            // Reset internal state
            state <= IDLE;
            head_ptr <= 5'd0;
            check_idx <= 5'd0;
            del_idx <= 4'd0;
            match_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    if (in_valid) begin
                        state <= LOAD;
                        // Capture word? We will do it in LOAD state or here.
                        // Let's do it here to save a cycle if needed, but standard is to do in LOAD.
                        // Since in_valid is high, we can store it.
                        dict_mem[head_ptr] <= in_word;
                        // We don't know if it's last yet unless we see in_is_last. 
                        // But in_is_last is valid with in_valid.
                        is_last_word <= in_is_last;
                        // Increment head_ptr now? Or in LOAD? 
                        // If we go to LOAD, we have already stored it. 
                        // Let's just go straight to CHECK if we treat LOAD as just a storage cycle.
                        // But prompt has separate LOAD state.
                        // Let's stay in LOAD.
                    end
                end

                LOAD: begin
                    // We stored in IDLE transition (or do it here).
                    // Let's rely on the fact that inputs are valid for 1 cycle or more.
                    // If we need to latch, we do it here.
                    // Actually, let's store in IDLE transition to make LOAD state just a placeholder if needed,
                    // or to increment head_ptr if we didn't do it.
                    // Let's increment head_ptr here to keep memory write and ptr update together.
                    // Wait, if we wrote in IDLE->LOAD transition, we need to increment head_ptr.
                    // Let's do: State transitions IDLE->LOAD. Inside IDLE logic (or transition) we write to mem[head_ptr].
                    // Inside LOAD, we increment head_ptr.
                    
                    // Let's adjust: 
                    // IDLE: on in_valid, go to LOAD. Do not write memory yet.
                    // LOAD: write memory, increment ptr. Go to CHECK.
                    
                    if (in_valid) begin
                        dict_mem[head_ptr] <= in_word;
                        head_ptr <= head_ptr + 1;
                        is_last_word <= in_is_last;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Setup for verification loop
                    // If head_ptr == 1 (just added first word), skip to OUTPUT (or finish if last)
                    // But we added word in LOAD, so head_ptr is already pointing to the next free slot.
                    // If we added 1 word, head_ptr == 1. 
                    // We need to check if current word (dict_mem[0]) matches.
                    // So we need to check against words 0 to head_ptr-2.
                    // If head_ptr == 1, range 0 to -1 (empty). No check.
                    
                    if (head_ptr <= 1) begin
                        // No previous words to check against.
                        state <= OUTPUT;
                        match_found <= 1'b0;
                    end else begin
                        // Setup loop variables
                        current_word <= dict_mem[head_ptr-1]; // The word we just loaded
                        check_idx <= 5'd0;
                        del_idx <= 4'd0;
                        match_found <= 1'b0;
                        state <= DELETE_GEN;
                    end
                end

                DELETE_GEN: begin
                    // Generate candidate for current del_idx and current_word
                    // Logic handled by always @(*) block (temp_candidate)
                    candidate <= temp_candidate;
                    state <= VERIFY;
                end

                VERIFY: begin
                    // Check candidate against dict_mem[check_idx]
                    // Logic handled by wire match_detected
                    
                    if (match_detected) begin
                        match_found <= 1'b1;
                        // Found match, no need to check further. 
                        // But we need to go to OUTPUT. 
                        // We can transition immediately or next cycle. 
                        // To save cycles, let's transition immediately.
                        // However, standard FSM updates state at end of cycle.
                        // If we set state = OUTPUT here, it updates on posedge.
                        state <= OUTPUT;
                    end else begin
                        // No match for this candidate
                        // Check if we checked all stored words for this deletion index
                        if (check_idx < head_ptr - 2) begin
                            // Continue inner loop (next stored word)
                            check_idx <= check_idx + 1'b1;
                            state <= DELETE_GEN; // Next stored word, same deletion index
                            // Note: we loop back to DELETE_GEN to re-generate candidate (same word, same del_idx, just comparing to next dict entry)
                            // Actually, candidate generation only depends on current_word and del_idx.
                            // We can stay in VERIFY and just update check_idx if we optimize.
                            // But candidate needs to be valid for VERIFY.
                            // If we change check_idx, candidate doesn't change.
                            // So we can stay in VERIFY and just increment check_idx.
                            // But to keep state machine simple and robust:
                            // Go to DELETE_GEN (which does nothing if inputs same) -> VERIFY.
                            // Or just increment check_idx here and stay in VERIFY.
                            // Let's just increment check_idx.
                            check_idx <= check_idx + 1'b1;
                            state <= VERIFY; // Stay in VERIFY, next cycle it compares new check_idx
                            // Note: we need to update the wire connection. 
                            // The wire match_detected uses current check_idx. 
                            // If we increment check_idx here, the next cycle it uses new index.
                            // This works fine.
                        end else begin
                            // Inner loop done. Try next deletion index.
                            if (del_idx < CHARS - 1) begin
                                del_idx <= del_idx + 1'b1;
                                check_idx <= 5'd0;
                                state <= DELETE_GEN; // Generate new candidate for next del_idx
                            end else begin
                                // All deletion indices done, no match found
                                state <= OUTPUT;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    if (match_found) begin
                        out_valid <= 1'b1;
                        out_word <= current_word;
                    end else begin
                        out_valid <= 1'b0;
                    end
                    
                    if (is_last_word) begin
                        state <= FINISH;
                    end else begin
                        state <= IDLE;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    out_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule