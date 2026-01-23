module thore_checker (
    input clk,
    input rst_n,
    input start,
    input [15:0] scoreboard_size,
    input [127:0] current_name,
    input [127:0] names_above [0:7],
    input [127:0] names_below [0:7],
    output reg [15:0] result_prefix,
    output reg [127:0] result_string,
    output reg done,
    output reg is_awesome,
    output reg sucks
);

    // States
    typedef enum logic [2:0] {
        IDLE,
        CHECK_FIRST,
        CHECK_SUCKS,
        FIND_PREFIX,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Variables
    reg [3:0] prefix_len;
    reg [3:0] name_idx;
    reg [127:0] current_name_shifted;
    reg [127:0] name_above_shifted;
    
    // Helper logic for byte comparison
    // We will compare byte by byte in a loop using a combinatorial helper
    wire match;
    
    // Extract bytes based on prefix_len
    // Note: current_name is 16 chars (16 bytes). We need to compare first 'prefix_len' bytes.
    // If prefix_len is L, we compare current_name[127:0] vs names_above[i][127:0] masked to L bytes.
    // Since we are iterating L from 1 to 13, we can shift or mask.
    
    // Combinatorial check for "match" of first 'prefix_len' bytes
    // We assume names are stored in big-endian order (ASCII string left-aligned in 128-bit vector).
    // Byte 0 is at MSB [127:120], Byte 1 at [119:112], etc.
    // To compare first L bytes, we need to check if the bits [127:128-8*L] are equal.
    
    wire [127:0] mask;
    assign mask = (128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF) << (128 - 8 * prefix_len);
    
    wire [127:0] masked_current;
    assign masked_current = current_name & mask;
    
    wire [127:0] masked_above;
    assign masked_above = names_above[name_idx] & mask;
    
    assign match = (masked_current == masked_above);

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic & Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and internal variables
            done <= 1'b0;
            is_awesome <= 1'b0;
            sucks <= 1'b0;
            result_prefix <= 16'b0;
            result_string <= 128'b0;
            prefix_len <= 4'd1;
            name_idx <= 3'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    is_awesome <= 1'b0;
                    sucks <= 1'b0;
                    result_prefix <= 16'b0;
                    result_string <= 128'b0;
                    if (start) begin
                        // Initialize variables
                        name_idx <= 3'd0;
                        prefix_len <= 4'd1;
                    end
                end

                CHECK_FIRST: begin
                    // Check if Thore is first
                    // Condition: scoreboard_size == 0 implies no names above.
                    // Or names_above[0] is all zero.
                    if (scoreboard_size == 16'd0 || names_above[0] == 128'b0) begin
                        is_awesome <= 1'b1;
                        done <= 1'b1;
                        // Stay in DONE implicitly by next_state logic, but we set done here.
                        // Actually, we need to handle transition in next_state block.
                        // To keep it standard, we update registers based on next_state.
                        // However, standard practice is to split combinational next_state and sequential output.
                        // Let's use a single always block for Mealy/Moore logic for simplicity as requested.
                    end 
                end

                CHECK_SUCKS: begin
                    // Iterate through names_above to check prefix "ThoreHusfeld" (12 chars)
                    // We use name_idx to track which name we are checking.
                    // We need a loop logic here. Since we are in a clocked block, we check one entry per cycle or use a helper.
                    // Given the latency requirement (20-30 cycles), we can do one check per cycle.
                    
                    // To implement the loop in sequential logic:
                    // If match found on current name_idx, set sucks and go to DONE.
                    // If finished all names (name_idx >= 8 or name_idx >= scoreboard_size-1) and no match, go to FIND_PREFIX.
                    
                    // Note: The prompt asks for a state machine. Inside a state, we might need sub-iterations.
                    // We will iterate 'name_idx'.
                    
                    if (match && name_idx < scoreboard_size) begin
                        // Found a match with prefix 12
                        sucks <= 1'b1;
                        done <= 1'b1;
                        // Transition to DONE handled in next_state logic
                    end
                    
                    // Increment index logic is handled in next_state block usually, but let's keep it clean.
                    // We will advance name_idx in the transition logic or here.
                end

                FIND_PREFIX: begin
                    // Logic: Iterate L=1 to 13.
                    // For each L, iterate through names_above.
                    // If no matches for L, found unique prefix.
                    
                    // Implementation strategy: 
                    // Inner loop: check name_idx against current_name with len prefix_len.
                    // If match, increment name_idx.
                    // If no match, we found a mismatch for this name. But we need NO name to match.
                    // So if match found, we increment prefix_len (or reset name_idx and increment prefix_len).
                    // Wait, the requirement is: "No name in names_above has the same first L characters".
                    // So if ANY name matches, current L is NOT unique.
                    
                    // Algorithm in hardware:
                    // Check name_idx against current_name with len prefix_len.
                    // If match:
                    //    Increment prefix_len (if >13 error, but assume <13).
                    //    Reset name_idx to 0.
                    //    (Wait, if match found, we immediately know L is bad, so increment L and restart check).
                    // If mismatch:
                    //    Increment name_idx.
                    //    If name_idx reaches end of list (no matches found for this L):
                    //       This L is unique. Record result.
                    end

                DONE: begin
                    // Latch outputs. Wait for reset or start.
                    // If we are in DONE, we stay here until reset.
                    // The 'done' signal is already high.
                end
            endcase
        end
    end

    // Separated Next State Logic for clarity and correctness in the single-always block approach
    // Actually, mixing next_state and output in one block requires careful ordering.
    // Let's use a separate combinational block for next_state.

    // Helper variables for state transitions
    reg [3:0] next_prefix_len;
    reg [3:0] next_name_idx;
    
    always @(*) begin
        next_state = current_state;
        next_prefix_len = prefix_len;
        next_name_idx = name_idx;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_FIRST;
                    next_name_idx = 3'd0;
                    next_prefix_len = 4'd1;
                end
            end

            CHECK_FIRST: begin
                if (scoreboard_size == 16'd0 || names_above[0] == 128'b0) begin
                    // If Thore is first (no names above or first entry is null)
                    next_state = DONE;
                end else begin
                    // If not first, go check sucks
                    next_state = CHECK_SUCKS;
                    next_name_idx = 3'd0;
                end
            end

            CHECK_SUCKS: begin
                // Check if current index matches prefix 12
                // Note: We need to compare L=12. The 'match' wire uses 'prefix_len'.
                // We need to temporarily force L=12 for this state.
                // OR we can structure the logic to handle L=12 specifically.
                // Let's use a specific comparison here to avoid messing up prefix_len.
                
                // Comparing L=12 for CHECK_SUCKS state:
                // We do this by overriding the match logic or just evaluating it here.
                // To keep 'match' wire generic, we can set prefix_len to 12 before entering this state?
                // Or just use the explicit logic here.
                
                // Explicit logic for L=12:
                wire match_12;
                // Calculate mask for L=12
                wire [127:0] mask_12 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF << (128 - 96); // 12*8=96 bits
                wire [127:0] masked_current_12 = current_name & mask_12;
                wire [127:0] masked_above_12 = names_above[name_idx] & mask_12;
                assign match_12 = (masked_current_12 == masked_above_12);

                // Logic:
                // If match_12: Transition to DONE (sucks set in sequential block)
                // If !match_12: Increment name_idx
                // If name_idx reaches limit (scoreboard_size) without match: Transition to FIND_PREFIX
                
                // Check limit: scoreboard_size is the total entries. We iterate indices 0 to scoreboard_size-1.
                // If we are at index i, we check. If i is the last one (i == scoreboard_size - 1), and no match, we are done with this phase.
                
                if (match_12) begin
                    // Found a match in above names
                    // nextState stays in CHECK_SUCKS? No, we set sucks high in sequential block.
                    // We should transition to DONE.
                    next_state = DONE;
                end else begin
                    // No match at this index
                    if (name_idx >= scoreboard_size - 1 || name_idx >= 7) begin
                        // Reached end of list
                        next_state = FIND_PREFIX;
                        next_name_idx = 3'd0;
                        next_prefix_len = 4'd1;
                    end else begin
                        // Check next name
                        next_name_idx = name_idx + 1;
                    end
                end
            end

            FIND_PREFIX: begin
                // Loop over L=1 to 13.
                // Loop over names.
                // If current L is unique (checked all names, no matches), go to DONE.
                // If match found at index i, L is NOT unique. Increment L, reset index i=0.
                // If !match at index i, check next index.
                
                // Use generic 'match' wire (which depends on 'prefix_len')
                
                if (match) begin
                    // Match found. Current prefix_len is NOT unique.
                    // Increment prefix_len.
                    if (prefix_len == 4'd13) begin
                        // Should not happen if names are distinct, but fallback
                        next_state = DONE;
                        next_prefix_len = 4'd13;
                    end else begin
                        next_prefix_len = prefix_len + 1;
                        next_name_idx = 3'd0; // Reset index to check new prefix_len
                    end
                end else begin
                    // No match at this index. Check next name.
                    // If we have checked all names for this prefix_len, then it's unique.
                    // Condition for "checked all": name_idx is last index
                    if (name_idx >= scoreboard_size - 1 || name_idx >= 7) begin
                        // We finished checking this prefix_len and found no matches.
                        // This is our answer.
                        next_state = DONE;
                    end else begin
                        // Next name
                        next_name_idx = name_idx + 1;
                    end
                end
            end

            DONE: begin
                // Stay here until reset
                next_state = DONE;
            end
        endcase
    end

    // Update sequential variables
    // We need to separate the combinational next_state from sequential updates.
    // The previous always block handled the "effect" of the state (output).
    // This block handles the "cause" (transition).
    // However, to avoid race conditions and keep it simple in one block:
    // We will stick to the single block approach but separate the logic cleanly.
    
    // Re-implementing the single always block with proper ordering to ensure outputs are registered.
    // This is the most robust way for synthesizable RTL.
    
    // We need a way to detect edge cases or loops.
    // Let's add auxiliary registers to help manage the iteration.
    
    // Actually, let's refine the single block logic.
    // The previous sequential block had commented out logic.
    // Let's rewrite the sequential block to handle the logic correctly using 'if/else' chains based on state.

    // We will define the L=12 comparison wire inside the module scope so it can be used in the combinational block.
    wire match_12;
    wire [127:0] mask_12 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF << (128 - 96);
    assign match_12 = ((current_name & mask_12) == (names_above[name_idx] & mask_12));

    // We need to handle the loop for CHECK_SUCKS and FIND_PREFIX carefully.
    // To adhere to the "Single Always Block" requirement often used in these prompts for simplicity (or split into next_state/output):
    // I will implement a split logic:
    // 1. Combinational block for 'next_state' and 'outputs' (Moore/Mealy).
    // 2. Sequential block to update state and registers.
    
    // Let's put everything in one sequential block as requested by the prompt style ("Always block"), but we need to handle the iterations.
    // Iterations inside a clocked block usually look like:
    // if (state == X) begin if (iteration_done) next_state else increment_counter end
    
    // Let's define the logic inside a single clocked block for clarity on state transitions and variable updates.
    // We need to store the result when we hit DONE.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            is_awesome <= 1'b0;
            sucks <= 1'b0;
            result_prefix <= 16'b0;
            result_string <= 128'b0;
            prefix_len <= 4'd1;
            name_idx <= 3'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    is_awesome <= 1'b0;
                    sucks <= 1'b0;
                    result_prefix <= 16'b0;
                    result_string <= 128'b0;
                    if (start) begin
                        current_state <= CHECK_FIRST;
                        name_idx <= 3'd0;
                        prefix_len <= 4'd1;
                    end
                end

                CHECK_FIRST: begin
                    // Check if Thore is first.
                    // If scoreboard_size == 0 or names_above[0] is all zero.
                    if (scoreboard_size == 16'd0 || names_above[0] == 128'b0) begin
                        is_awesome <= 1'b1;
                        done <= 1'b1;
                        current_state <= DONE;
                    end else begin
                        current_state <= CHECK_SUCKS;
                        name_idx <= 3'd0;
                    end
                end

                CHECK_SUCKS: begin
                    // Compare current_name with names_above[name_idx] using L=12.
                    // Check if we are within valid range.
                    // Note: scoreboard_size could be up to 8. We iterate indices 0 to 7.
                    // We must stop at scoreboard_size - 1.
                    
                    // If we are at an index >= scoreboard_size (shouldn't happen if logic is correct) or have checked all.
                    // Actually, scoreboard_size is the number of entries. If size=1, names_above[0] is valid.
                    
                    // Check match (L=12)
                    if (match_12 && name_idx < scoreboard_size) begin
                        sucks <= 1'b1;
                        done <= 1'b1;
                        current_state <= DONE;
                    end else begin
                        // No match, check next
                        if (name_idx >= scoreboard_size - 1) begin
                            // Reached end, no "ThoreHusfeld" found above
                            current_state <= FIND_PREFIX;
                            name_idx <= 3'd0;
                            prefix_len <= 4'd1;
                        end else begin
                            name_idx <= name_idx + 1;
                        end
                    end
                end

                FIND_PREFIX: begin
                    // Compare using 'match' wire (depends on prefix_len)
                    // If match (any name above matches current prefix), then current prefix_len is NOT unique.
                    // We need to increment prefix_len and restart scan.
                    // If no match at current index, check next index.
                    // If we reach end of list with no matches for this prefix_len, then it's unique.
                    
                    // Condition 1: Match found
                    if (match && name_idx < scoreboard_size) begin
                        // Current prefix length failed. Try longer.
                        prefix_len <= prefix_len + 1;
                        name_idx <= 3'd0;
                        // If prefix_len goes to 14, we are out of bounds (name is 13 chars).
                        // Logic should handle 1..13. If prefix_len == 13 and matches, we go to 14.
n                        // We should check if prefix_len > 13.
                        if (prefix_len == 4'd13) begin
                            // If 13 matches, we have exact match. 
                            // Logic says "find smallest prefix... such that no name in names_above has the same..."
                            // If 13 matches, then no unique prefix? Logic failure or Thore is same as above.
                            // We will just go to DONE with 13.
                            // Or loop indefinitely? Let's stop at 13.
                            result_prefix <= 13;
                            result_string <= current_name; // Full string
                            done <= 1'b1;
                            current_state <= DONE;
                        end
                    end else begin
                        // No match at this index
                        // Are we at the last name?
                        // Valid names are 0 to scoreboard_size - 1.
                        if (name_idx >= scoreboard_size - 1) begin
                            // We checked all names for this prefix_len and found no matches.
                            // Success.
                            result_prefix <= prefix_len;
                            // Result string: take first prefix_len bytes from current_name.
                            // current_name is 128 bits. We zero out bytes > prefix_len.
                            // Actually, we can just assign it. The user expects the prefix string.
                            // To be precise: result_string = current_name masked? 
                            // "The actual prefix string (first N bytes)". Usually implies the string with padding or just valid bytes.
                            // We will output the masked version to be safe/clean.
                            result_string <= current_name & (128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF << (128 - 8*prefix_len));
                            done <= 1'b1;
                            current_state <= DONE;
                        end else begin
                            // Check next name
                            name_idx <= name_idx + 1;
                        end
                    end
                end

                DONE: begin
                    // Stay here until reset
                end
            endcase
        end
    end

endmodule
