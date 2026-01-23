module wildcard_match (
    input clk,
    input rst_n,
    input start,
    input [2:0] s_len,
    input [2:0] t_len,
    input [63:0] s_data,
    input [63:0] t_data,
    output reg match,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam FIND_WILDCARD = 3'b001;
    localparam CHECK_PREFIX = 3'b010;
    localparam CHECK_SUFFIX = 3'b011;
    localparam VERIFY_LENGTH = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Datapath registers
    reg [2:0] star_pos;         // Position of wildcard (0 to 7)
    reg [2:0] star_count;       // Count of wildcards found
    reg has_wildcard;           // Flag if wildcard exists
    reg [2:0] prefix_len;       // Length of prefix (chars before *)
    reg [2:0] suffix_len;       // Length of suffix (chars after *)
    reg [2:0] idx;              // Generic index for comparisons
    reg match_reg;              // Internal match flag
    reg [7:0] char_s, char_t;   // Extracted characters
    reg valid_prefix;           // Prefix match result
    reg valid_suffix;           // Suffix match result
    reg [2:0] len_check;        // Sum of lengths for verification

    // Helper signals for character extraction
    // s_data[63:56] is index 0, s_data[56:48] is index 1, ...
    wire [7:0] s_chars [0:7];
    wire [7:0] t_chars [0:7];

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : char_extract
            assign s_chars[i] = s_data[63-(8*i) -: 8];
            assign t_chars[i] = t_data[63-(8*i) -: 8];
        end
    endgenerate

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = FIND_WILDCARD;
                else next_state = IDLE;
            end
            FIND_WILDCARD: begin
                // 1 cycle to find wildcard
                next_state = CHECK_PREFIX;
            end
            CHECK_PREFIX: begin
                // 8 cycles to scan
                if (idx >= 4'd8 || idx >= s_len) next_state = CHECK_SUFFIX;
                else next_state = CHECK_PREFIX;
            end
            CHECK_SUFFIX: begin
                // 8 cycles to scan (indices after star_pos)
                // We scan from star_pos + 1 up to s_len - 1
                // We use idx to track the current position in s
                if (idx >= s_len) next_state = VERIFY_LENGTH;
                else next_state = CHECK_SUFFIX;
            end
            VERIFY_LENGTH: begin
                // 1 cycle check
                next_state = DONE;
            end
            DONE: begin
                // 1 cycle output
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic (Control and Operations)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            match <= 1'b0;
            done <= 1'b0;
            star_pos <= 3'b0;
            star_count <= 3'b0;
            has_wildcard <= 1'b0;
            prefix_len <= 3'b0;
            suffix_len <= 3'b0;
            idx <= 3'b0;
            match_reg <= 1'b1; // Assume match until proven otherwise
            valid_prefix <= 1'b1;
            valid_suffix <= 1'b1;
            char_s <= 8'b0;
            char_t <= 8'b0;
            len_check <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    match <= 1'b0;
                    if (start) begin
                        // Reset check variables
                        match_reg <= 1'b1;
                        valid_prefix <= 1'b1;
                        valid_suffix <= 1'b1;
                        star_count <= 3'b0;
                        has_wildcard <= 1'b0;
                        star_pos <= 3'b0;
                        idx <= 3'b0;
                        prefix_len <= 3'b0;
                        suffix_len <= 3'b0;
                    end
                end

                FIND_WILDCARD: begin
                    // Scan s_data for '*' (8'h2A)
                    // Just a quick check if we need this logic or if we can just rely on CHECK_PREFIX/CKECK_SUFFIX
                    // The requirement says specific states, so we populate star_pos here.
                    // However, doing a full scan takes time. 
                    // Since we need to scan in CHECK_PREFIX/CKECK_SUFFIX anyway, we can combine logic.
                    // But to strictly follow the state machine description:
                    // Let's assume we can't scan all 8 bytes in 1 cycle without a loop.
                    // The requirement implies a multi-cycle operation for the states.
                    // So FIND_WILDCARD will simply initialize variables. 
                    // We will detect '*' dynamically in CHECK_PREFIX/CKECK_SUFFIX.
                    // Actually, to strictly follow "Scans s_data to find '*' position", we should do it here.
                    // But since we are sequential and latency is 20 cycles, we can spend cycles.
                    // However, 1 cycle is insufficient for 8 bytes. 
                    // Let's assume "FIND_WILDCARD" sets up the scan.
                    // We will rely on CHECK_PREFIX to find the star.
                    // If the requirement implies a separate state for searching, we should likely handle it there.
                    // Let's make CHECK_PREFIX handle finding the star.
                    // If we strictly need FIND_WILDCARD state, we'll just init idx=0 here and wait.
                    // But CHECK_PREFIX needs to run after. 
                    // Let's optimize: CHECK_PREFIX does the work of finding star.
                    // If we must have the state, we just transition.
                    // Let's assume we perform the search in CHECK_PREFIX.
                    // To respect the "FIND_WILDCARD" state, we can do a 1-cycle check of the whole string if we had compare logic.
                    // But we are building a sequential circuit. 
                    // Let's just start checking from index 0 in CHECK_PREFIX.
                    // Actually, let's handle it in CHECK_PREFIX state.
                    // We need to set up variables. 
                    star_pos <= 3'd0; 
                    has_wildcard <= 1'b0;
                    idx <= 3'd0;
                    // We will check for star in CHECK_PREFIX logic.
                end

                CHECK_PREFIX: begin
                    // We scan the pattern string s.
                    // If we find '*', record position, set has_wildcard.
                    // If we find a normal char, compare with t.
                    // If mismatch, set match_reg to 0.
                    // Increment idx.
                    
                    char_s <= s_chars[idx];
                    char_t <= t_chars[idx];

                    if (s_chars[idx] == 8'h2A) begin
                        has_wildcard <= 1'b1;
                        star_pos <= idx;
                        // Stop counting prefix here
                        // We are done with prefix check
                        // But we need to finish the loop to handle if there are multiple stars? 
                        // Requirement says "exactly one wildcard". 
                        // If we find a star, we must ensure no more stars exist.
                        // We continue scanning to count stars and verify length logic.
                        // But for matching logic, we switch to suffix check after this state ends.
                    end else begin
                        // It's a character
                        if (idx < s_len && idx < t_len) begin
                            if (s_chars[idx] != t_chars[idx]) begin
                                match_reg <= 1'b0;
                            end
                        end else if (idx < s_len && idx >= t_len) begin
                            // Pattern char but no target char
                            // If it's not a star, it's a mismatch
                            match_reg <= 1'b0;
                        end
                        // Update prefix length if not star
                        if (!has_wildcard) prefix_len <= idx + 1'b1;
                    end

                    // Track star count
                    if (s_chars[idx] == 8'h2A) star_count <= star_count + 1'b1;
                    
                    idx <= idx + 1'b1;
                end

                CHECK_SUFFIX: begin
                    // If we are here, we have handled prefix up to star_pos (or s_len if no star)
                    // We need to check the suffix.
                    // Suffix starts at s_len - suffix_len.
                    // Or more simply: iterate from index = star_pos + 1 (or 0 if no star) to s_len - 1
                    // Compare s[i] with t[t_len - (s_len - i)]
                    
                    // We need to calculate the index in s and t.
                    // Let idx represent the current index in s.
                    // If no wildcard, we already checked up to s_len in CHECK_PREFIX?
                    // Wait, CHECK_PREFIX loop stops at idx >= s_len.
                    // So if no wildcard, we never enter CHECK_SUFFIX (we would go to VERIFY_LENGTH).
                    // So we only enter CHECK_SUFFIX if has_wildcard.
                    
                    // Logic for suffix:
                    // We scan s from star_pos+1 to s_len.
                    // We need to compare s[star_pos+1] with t[t_len - (s_len - star_pos - 1)]
                    // i.e., t[t_len - s_len + star_pos + 1]
                    
                    // We use idx to iterate s indices.
                    // Let's map s index to t index on the fly.
                    
                    if (idx == 0) begin
                        // First time entering suffix logic setup
                        idx <= star_pos + 1'b1;
                    end else begin
                        idx <= idx + 1'b1;
                    end

                    if (idx >= star_pos + 1 && idx < s_len) begin
                        char_s <= s_chars[idx];
                        // Calculate t index: t_len - (s_len - idx)
                        // Note: t_len and s_len are 3-bit. s_len > star_pos.
                        // Let's compute t_idx = t_len - s_len + idx;
                        // To avoid subtraction in indexing, we can do 2's comp logic or assert order.
                        // t_idx must be >= 0 and < t_len.
                        // If t_idx is out of bounds, it's a mismatch.
                        
                        // Check bounds first.
                        // t_idx = t_len - s_len + idx
                        // We can verify if t_idx < t_len.
                        // If t_len - s_len + idx < t_len  => -s_len + idx < 0 => idx < s_len. (True)
                        // If t_idx >= 0 => t_len + idx >= s_len. (True if target is long enough)
                        
                        // Let's use a temporary variable for t_idx calculation
                        // logic [2:0] t_idx_temp;
                        // t_idx_temp = t_len - s_len + idx;
                        // 
                        // Since we are in sequential logic, we can't use temp variable easily in always block without reg.
                        // Let's compute char_t directly.
                        // char_t <= t_chars[t_len - s_len + idx]; 
                        // This requires synthesis to handle the arithmetic index.
                        // Or we can use a helper wire.
                        
                        // Since index must be valid (0-7), we check bounds.
                        if ((t_len + idx) >= s_len) begin
                            // Valid target index is t_len - s_len + idx
                            // We need to access t_chars at that index.
                            // Let's compute index temporarily.
                            // We can calculate t_idx = t_len - s_len + idx;
                            // But we need to map it to array index.
                            // Let's assume the index arithmetic is done in the sub-expression.
                            
                            // We need a register to hold the computed index for t to be safe, 
                            // or use a combinational block. 
                            // Let's use a combinational block to extract t_char for suffix.
                        end else begin
                            // Not enough chars in t, mismatch
                            match_reg <= 1'b0;
                        end
                        
                        // Compare
                        // We need the value of t_char. 
                        // Let's define a wire for suffix comparison.
                        // reg [2:0] t_idx_calc;
                        // t_idx_calc = t_len - s_len + idx;
                        // if (t_idx_calc < t_len && t_idx_calc >= 0) ...
                        // if (s_chars[idx] != t_chars[t_idx_calc]) ...
                        
                        // Let's do it:
                        if ((t_len + idx) >= s_len) begin
                             // t_idx = t_len - s_len + idx
                             // Since t_idx < t_len is guaranteed if t_len <= 8 and s_len <= 8 and idx < s_len.
                             // The only check is (t_len + idx) >= s_len.
                             // We access t_chars[t_len - s_len + idx].
                             // This is a multi-bit index. Synthesis tools handle this with muxes.
                             char_t <= t_chars[t_len - s_len + idx];
                             if (s_chars[idx] != t_chars[t_len - s_len + idx]) begin
                                 match_reg <= 1'b0;
                             end
                        end else begin
                             match_reg <= 1'b0;
                        end
                    end 
                    // Increment idx for next cycle
                    if (idx >= star_pos + 1 && idx < s_len) begin
                        // Logic handled above, idx incremented below
                    end else if (idx == 0) begin
                        // Just initialized, wait next cycle to process
                        // Force idx to star_pos+1 so we don't increment immediately in the else block below
                        // Actually, we set idx in the if block. If idx==0, we skip increment.
                    end else begin
                         // Increment idx to proceed scan
                         // If idx >= s_len, we are done. State transition handles exit.
                         // We only increment if we are within valid range and haven't finished.
                         // If idx < s_len, we continue. 
                         // Wait, we set idx in the first block. 
                         // The logic flow is:
                         // 1. If start of state (idx is 0 or marker), set idx to star_pos+1.
                         // 2. Process char at idx.
                         // 3. Increment idx.
                    end
                    
                    // Cleaned up logic for CHECK_SUFFIX:
                    // We use idx to track the position in S we are checking.
                    // Init: if idx == 0, idx <= star_pos+1.
                    // Else if idx < s_len, process idx, then idx <= idx+1.
                    // Else, finished.
                    
                    // Correction to the always block logic for CHECK_SUFFIX:
                    if (state == CHECK_SUFFIX) begin
                        if (idx == 3'b0 || (idx <= star_pos)) idx <= star_pos + 1'b1;
                        else if (idx < s_len) begin
                            // Compare s[idx] with t[t_len - s_len + idx]
                            char_s <= s_chars[idx];
                            if ((t_len + idx) >= s_len) begin
                                char_t <= t_chars[t_len - s_len + idx];
                                if (s_chars[idx] != t_chars[t_len - s_len + idx]) match_reg <= 1'b0;
                            end else begin
                                match_reg <= 1'b0;
                            end
                            idx <= idx + 1'b1;
                        end
                    end
                end

                VERIFY_LENGTH: begin
                    // Check if prefix_len + suffix_len <= t_len
                    // prefix_len was set in CHECK_PREFIX (if no star, it's s_len, but we handled that in CHECK_PREFIX logic?
                    // Wait. If no star, prefix_len <= idx + 1. In CHECK_PREFIX, idx goes up to s_len.
                    // If s_len is 5, idx goes 0,1,2,3,4. prefix_len <= 5. Next cycle idx=5, exit state. Correct.
                    // If star found, prefix_len <= idx (before increment) or idx+1? 
                    // If star found at idx=k, prefix_len <= k+1? 
                    // The prefix length is the number of chars before star. 
                    // If star is at idx 3, prefix is 0,1,2 -> length 3.
                    // In logic: if !has_wildcard, prefix_len <= idx+1.
                    // If star found, we stop incrementing prefix_len.
                    // So prefix_len is correct.
                    // Suffix length = s_len - star_pos - 1.
                    // If no star, suffix_len = 0.
                    
                    if (has_wildcard) begin
                        suffix_len <= s_len - star_pos - 1'b1;
                    end else begin
                        suffix_len <= 3'b0;
                    end
                    
                    // Verify length check
                    len_check <= prefix_len + (has_wildcard ? (s_len - star_pos - 1'b1) : 3'b0);
                    
                    if ((prefix_len + (has_wildcard ? (s_len - star_pos - 1'b1) : 3'b0)) > t_len) begin
                        match_reg <= 1'b0;
                    end
                    // Also verify wildcard count
                    if (star_count > 3'b1) begin // Requirement says "exactly one", we allow 0 or 1? "can contain exactly one" implies 0 or 1. 
                        // If multiple stars, it's invalid pattern for this module or mismatch.
                        if (star_count != 1 && star_count != 0) match_reg <= 1'b0;
                    end
                    // Check if target chars are all lowercase or valid? 
                    // Pattern chars should be lowercase or star. We didn't validate pattern, but we checked equality.
                    // If pattern char is invalid, it won't match target (assuming target is valid). 
                end

                DONE: begin
                    match <= match_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Re-evaluating CHECK_PREFIX and CHECK_SUFFIX combinational requirements:
    // The previous always block attempts to do everything in sync logic.
    // However, accessing t_chars[t_len - s_len + idx] requires the index to be computed.
    // This is fine in synthesis.
    // 
    // One issue: In CHECK_PREFIX, we used `char_s <= s_chars[idx]` and `char_t <= t_chars[idx]` for comparison.
    // But comparison happens in the same cycle as assignment to char_s/char_t.
    // Since char_s/char_t are registers, they update at the end of the cycle.
    // So `if (s_chars[idx] != t_chars[idx])` uses the OLD value of char_s/char_t if we relied on those.
    // But we are comparing `s_chars[idx]` directly. That is combinational logic from the CURRENT idx.
    // That is correct for synchronous logic.
    // 
    // Let's refine the CHECK_PREFIX and CHECK_SUFFIX logic to be robust.
    // 
    // CHECK_PREFIX:
    //   1. Check if s_chars[idx] is '*' -> set star_pos, has_wildcard.
    //   2. If not '*', compare s_chars[idx] vs t_chars[idx].
    //   3. Increment idx.
    //   4. If idx >= s_len, stop.
    //   5. If star found, we continue scanning to count stars (check for error) but do not compare t anymore.
    //      Actually, requirement says "Verify prefix matches start of t".
    //      So if we have star at idx 3, we compare idx 0,1,2. 
    //      If we find a second star later, it's invalid input or we just ignore it? 
    //      "exactly one wildcard". So if we find second star, we might set match_reg=0.
    //      
    // CHECK_SUFFIX:
    //   1. We need to loop from star_pos+1 to s_len-1.
    //   2. Current logic: 
    //      if (idx == 0) idx <= star_pos + 1;
    //      else if (idx < s_len) begin
    //          compare s_chars[idx] with t_chars[t_len - s_len + idx]
    //          idx <= idx + 1;
    //      end
    //   
    //   This works, but `t_len - s_len + idx` must be valid index (0-7).
    //   We must check bounds. 
    //   Bound check: `if (t_len - s_len + idx < t_len && t_len - s_len + idx >= 0)`
    //   Simplified: `if (t_len + idx >= s_len)` and `t_len + idx - s_len < t_len`.
    //   `t_len + idx - s_len < t_len` -> `idx < s_len`. (Always true if we loop up to s_len).
    //   So only check `t_len + idx >= s_len`.
    //   If condition fails, `match_reg <= 0`.
    
    // Let's rewrite the specific always block for clarity and correctness.
    // We will separate the operations slightly to avoid index out of bounds issues.
    
    // Wait, `s_chars` and `t_chars` are wires. Accessing them with variable index is fine.
    // 
    // The provided "Internal Logic" says:
    // "IDLE: Wait for start"
    // "FIND_WILDCARD: Scan s_data to find '*' position or confirm absence"
    //   -> Since we are sequential and need 20 cycles, we can actually scan in this state using a counter.
    //   -> Let's do it. It's cleaner.
    //   -> State FIND_WILDCARD: Use a counter `scan_idx` (reuse idx).
    //   -> If s_chars[scan_idx] == '*', set star_pos, has_wildcard.
    //   -> Increment scan_idx. Stop when scan_idx >= s_len.
    //   -> Transition to CHECK_PREFIX when done.
    //   -> This takes `s_len` cycles.
    //   -> Then CHECK_PREFIX takes `prefix_len` cycles.
    //   -> CHECK_SUFFIX takes `suffix_len` cycles.
    //   -> Total cycles = 2 (IDLE/DONE/VERIFY/START) + s_len + prefix + suffix.
    //   -> If no star: 2 + s_len + s_len + 0 = 2 + 2*s_len <= 18 (for s_len=8). Fits 20.
    //   -> If star: 2 + s_len + prefix + suffix = 2 + s_len + (s_len-1) = 2 + 2*s_len - 1 <= 17. Fits.
    //   -> This fits the 20 cycle budget and is much cleaner.
    
    // Revised State Machine Logic:
    
    // Registers:
    // reg [2:0] scan_idx; (Reuse idx)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match <= 1'b0;
            done <= 1'b0;
            idx <= 3'b0;
            star_pos <= 3'b0;
            has_wildcard <= 1'b0;
            star_count <= 3'b0;
            match_reg <= 1'b1;
            prefix_len <= 3'b0;
            suffix_len <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    match <= 1'b0;
                    if (start) begin
                        state <= FIND_WILDCARD;
                        idx <= 3'b0;
                        star_pos <= 3'b0;
                        has_wildcard <= 1'b0;
                        star_count <= 3'b0;
                        match_reg <= 1'b1; // Assume match
                    end
                end

                FIND_WILDCARD: begin
                    // Scan for '*' and count them
                    if (s_chars[idx] == 8'h2A) begin
                        has_wildcard <= 1'b1;
                        star_pos <= idx;
                        star_count <= star_count + 1'b1;
                    end
                    
                    if (idx == s_len - 1'b1) begin
                        // Finished scanning
                        state <= CHECK_PREFIX;
                        idx <= 3'b0; // Reset for prefix check
                        
                        // Check for invalid multiple wildcards immediately
                        if (star_count > 1'b1 || (s_chars[idx] == 8'h2A && has_wildcard)) begin 
                            // Wait, we increment star_count this cycle. 
                            // If s_len-1 is a star, we just set star_count + 1.
                            // We need to handle the case where we finish scanning.
                            // If we found > 1 wildcard, match is false.
                            if (star_count + (s_chars[idx] == 8'h2A ? 1'b1 : 1'b0) > 1'b1) begin
                                match_reg <= 1'b0;
                            end
                        end
                    end else begin
                        idx <= idx + 1'b1;
                    end
                end

                CHECK_PREFIX: begin
                    // If no wildcard, check whole string up to s_len
                    // If wildcard, check up to star_pos
                    // Compare s[i] vs t[i]
                    
                    if (has_wildcard) begin
                        // Check only if idx < star_pos
                        if (idx < star_pos) begin
                            // Check bounds against t_len first
                            if (idx >= t_len) begin
                                match_reg <= 1'b0;
                            end else begin
                                if (s_chars[idx] != t_chars[idx]) match_reg <= 1'b0;
                            end
                            idx <= idx + 1'b1;
                        end else begin
                            // Done with prefix
                            prefix_len <= idx; // idx is star_pos, so length is idx (since 0-indexed, up to idx-1 is checked, length is idx)
                            // Wait, if star_pos is 0, prefix_len should be 0. idx starts 0. 
                            // Loop runs 0 < 0? No. So idx stays 0. prefix_len <= 0. Correct.
                            // If star_pos is 3. We check idx 0, 1, 2. 
                            // Cycle 0: idx=0. Check. idx=1.
                            // Cycle 1: idx=1. Check. idx=2.
                            // Cycle 2: idx=2. Check. idx=3.
                            // Cycle 3: idx=3. Loop condition 3<3 false. Enter else.
                            // prefix_len <= 3. Length is 3 chars (0,1,2). Correct.
                            state <= CHECK_SUFFIX;
                            idx <= 3'b0; // Reset idx for suffix logic
                        end
                    end else begin
                        // No wildcard, check up to s_len
                        if (idx < s_len) begin
                            if (idx >= t_len) match_reg <= 1'b0;
                            else if (s_chars[idx] != t_chars[idx]) match_reg <= 1'b0;
                            
                            idx <= idx + 1'b1;
                        end else begin
                            // Done checking all chars
                            prefix_len <= s_len;
                            // Since no wildcard, verify length is trivial (prefix_len <= t_len)
                            // We will do length check in VERIFY_LENGTH state.
                            state <= VERIFY_LENGTH;
                        end
                    end
                end

                CHECK_SUFFIX: begin
                    // If no wildcard, we wouldn't be here. 
                    // Suffix starts at star_pos + 1. Ends at s_len - 1.
                    // We need to map s index (i) to t index (t_idx).
                    // t_idx = t_len - (s_len - i) = t_len - s_len + i.
                    
                    if (idx == 0) begin
                        // Initialize
                        // We want to process star_pos + 1 to s_len - 1.
                        // Let's use idx as the s index we are currently processing.
                        // We'll just increment idx from star_pos+1 to s_len.
                        // But we need to do the first iteration.
                        
                        // Let's do: if we haven't started suffix processing, set idx = star_pos + 1
                        // Actually, we can just increment idx inside this state.
                        // Initial check: if idx < star_pos + 1, idx = star_pos + 1.
                        // Wait, idx is initialized to 0 in CHECK_PREFIX exit.
                    end
                    
                    // Logic for loop:
                    // Ensure idx starts at star_pos+1. If idx <= star_pos, set to star_pos+1.
                    // If idx < s_len:
                    //   Check t_idx = t_len - s_len + idx.
                    //   If t_idx valid, compare. Else mismatch.
                    //   Increment idx.
                    // If idx >= s_len, go to VERIFY_LENGTH.
                    
                    // Handle initialization of idx in the state
                    if (idx <= star_pos) begin
                        idx <= star_pos + 1'b1;
                    end else if (idx < s_len) begin
                        // Perform check
                        // t_idx = t_len - s_len + idx
                        // Valid if t_idx < t_len && t_idx >= 0
                        // t_idx >= 0 <=> t_len + idx >= s_len
                        // t_idx < t_len <=> t_len + idx - s_len < t_len <=> idx < s_len (Always true here)
                        
                        if ((t_len + idx) >= s_len) begin
                            // Access t_chars[t_len - s_len + idx]
                            if (s_chars[idx] != t_chars[t_len - s_len + idx]) begin
                                match_reg <= 1'b0;
                            end
                        end else begin
                            match_reg <= 1'b0;
                        end
                        
                        idx <= idx + 1'b1;
                    end else begin
                        // Done
                        state <= VERIFY_LENGTH;
                        // Calculate suffix_len = s_len - (star_pos + 1)
                        suffix_len <= s_len - star_pos - 1'b1;
                    end
                end

                VERIFY_LENGTH: begin
                    // Check: prefix_len + suffix_len <= t_len
                    // If no wildcard: prefix_len = s_len, suffix_len = 0. Check s_len <= t_len.
                    // If wildcard: we already have prefix_len (from CHECK_PREFIX exit) and suffix_len (from CHECK_SUFFIX exit).
                    // Wait, if no wildcard, we don't pass through CHECK_SUFFIX. 
                    // So suffix_len is not updated if no wildcard in CHECK_SUFFIX.
                    // We need to handle that.
                    
                    // If !has_wildcard, suffix_len should be 0.
                    // We can calculate sum here.
                    // Also, we need to check if prefix_len > t_len for no wildcard case.
                    
                    if (!has_wildcard) begin
                        suffix_len <= 3'b0;
                    end
                    
                    // The check:
                    if (prefix_len + suffix_len > t_len) begin
                        match_reg <= 1'b0;
                    end
                    
                    state <= DONE;
                end

                DONE: begin
                    match <= match_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
