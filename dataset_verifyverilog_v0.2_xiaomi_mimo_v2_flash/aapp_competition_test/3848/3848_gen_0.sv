module next_tolerable_string (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] p,
    input [127:0] s_in,
    output reg valid,
    output reg [127:0] s_out,
    output reg no_solution
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SEARCH = 3'b001;
    localparam VALIDATE = 3'b010;
    localparam FILL = 3'b011;
    localparam DONE = 3'b100;
    localparam NO_SOLUTION = 3'b101;

    reg [2:0] state;
    reg [3:0] idx; // Current index being processed (0 to 15)
    reg [4:0] char_val; // Current character value (0 to p-1)
    reg [127:0] work_str; // Working string register
    reg [127:0] temp_str; // Temporary storage for validation
    reg [127:0] temp_str_next; // Next state for temp_str
    reg [2:0] state_next;
    reg [3:0] idx_next;
    reg [4:0] char_val_next;
    reg valid_next;
    reg no_solution_next;
    reg [127:0] s_out_next;

    // Helper signals for character access
    // Extract character at specific index from 128-bit vector
    wire [7:0] char_at_idx;
    assign char_at_idx = work_str[idx * 8 +: 8];
    
    wire [7:0] char_at_idx_minus_1;
    assign char_at_idx_minus_1 = work_str[(idx - 1) * 8 +: 8];
    
    wire [7:0] char_at_idx_minus_2;
    assign char_at_idx_minus_2 = work_str[(idx - 2) * 8 +: 8];

    // Helper to get char from temp_str
    wire [7:0] temp_char_at_idx;
    assign temp_char_at_idx = temp_str[idx * 8 +: 8];
    wire [7:0] temp_char_at_idx_minus_1;
    assign temp_char_at_idx_minus_1 = temp_str[(idx - 1) * 8 +: 8];
    wire [7:0] temp_char_at_idx_minus_2;
    assign temp_char_at_idx_minus_2 = temp_str[(idx - 2) * 8 +: 8];

    // Logic to check if a specific character value (c) at position 'pos' is valid
    // based on characters at pos-1 and pos-2 in 'check_str'
    reg is_valid_check;
    always @(*) begin
        is_valid_check = 1'b1;
        // Check against pos-1 (Length 2 palindrome check)
        if (pos >= 1) begin
            if ((check_str[(pos-1)*8 +: 8] - 8'h61) == char_val) is_valid_check = 1'b0;
        end
        // Check against pos-2 (Length 3 palindrome check)
        if (pos >= 2) begin
            if ((check_str[(pos-2)*8 +: 8] - 8'h61) == char_val) is_valid_check = 1'b0;
        end
    end
    
    // Signals for combinational logic block
    reg [3:0] pos; // Position to check
    reg [127:0] check_str; // String to check against
    reg [4:0] char_val_check; // Char value to validate

    // Next State Logic
    always @(*) begin
        state_next = state;
        idx_next = idx;
        char_val_next = char_val;
        temp_str_next = temp_str;
        valid_next = 1'b0;
        no_solution_next = 1'b0;
        s_out_next = s_out;

        case (state)
            IDLE: begin
                if (start) begin
                    // Load input string into working string
                    temp_str_next = s_in;
                    state_next = SEARCH;
                    idx_next = n - 1; // Start from rightmost
                    char_val_next = 5'd0;
                    valid_next = 1'b0;
                    no_solution_next = 1'b0;
                end
            end

            SEARCH: begin
                // Check if we have run out of indices
                if (idx[3] && idx != 4'hF && idx > n - 1 && idx < 4'h8) begin // Check if idx < 0 (using 2's comp logic or just reset) or logic for idx == 0xffff (overflow)
                   // Actually simpler: idx is unsigned. If we decrement below 0, we wrap to 15. 
                   // We need to handle the case when idx is decremented from 0.
                   // Let's track strictly: if we are at index 0 and try to go left, fail.
                   // Or simpler: check if idx >= n means we are done with initialization or error.
                   // Let's use a standard counter: if idx == 0, we can't go left.
                   // Wait, the standard algorithm decrements idx. If idx wraps around from 0 to 15, we stop.
                   // However, my counter is 4 bits. 0 -> 15.
                   // Let's add a flag or check range.
                end
                
                // Logic for IDLE->SEARCH transition or if we are already in SEARCH
                // We need to handle the current character at idx.
                
                // If idx >= n, we are just starting or moved left past start?
                // We need to make sure idx is within 0..n-1 when acting on string.
                // Let's do: 
                // 1. If we are in SEARCH, we are looking at 'idx'.
                // 2. We need to find the next valid char for 'idx'.
                
                // First, check if current char_at_idx is valid to continue (if we haven't tried incrementing yet).
                // Actually, the description says: "Try to increment the character at current index".
                // This implies we must try values > current value.
                
                // So, initially (when entering SEARCH from IDLE), we set char_val = char_at_idx + 1.
                // But wait, we need to check if the *current* configuration is valid to extend, or we just increment.
                // The problem asks for "Next" string. So we must increment the rightmost character possible.
                
                // Let's refine SEARCH:
                // If we just entered SEARCH (from IDLE), we take the input string.
                // We set idx = n-1.
                // We set char_val = char_at_idx[idx] + 1.
                
                // If we are in SEARCH from a previous iteration (e.g., VALIDATE failed), we increment char_val.
                
                // Check bounds
                if (char_val >= p) begin
                    // Cannot increment this position anymore. Move left.
                    if (idx == 0) begin
                        state_next = NO_SOLUTION;
                    end else begin
                        idx_next = idx - 1;
                        // We need to start checking values > the original character at this new index
                        // But we need to preserve the left part of the string (0 to idx-1).
                        // The working string 'work_str' currently holds the best valid prefix found so far.
                        // Wait, we need to store the input string or the current best valid prefix.
                        // Let's use 'work_str' to store the current prefix we are building/validating.
                        // When we move left, we need to reset the character at idx to the original value from input (or incremented if we already incremented it? No, we move left so we increment the one to the left).
                        // Actually, when moving left, we should use the character that was at index 'idx' before we started modifying it? 
                        // No, standard backtracking: we go back to the previous index, and we increment it to a value > what it was originally (or > what we last tried).
                        // To keep it simple: 'work_str' is the current string state.
                        // When we move left from idx, we keep work_str[0:idx-1] as is.
                        // At idx (the new index), we want to try values > work_str[idx].
                        // But work_str[idx] might have been modified.
                        // We should reload the original input char at idx.
                        // Let's assume we keep 's_in' (or a copy) to know the original values.
                        
                        // Let's use 'temp_str' to hold the original input string permanently until we find a solution.
                        // 'work_str' will hold the current modification.
                        // When moving left from idx:
                        // We copy s_in[0:idx-1] to work_str? No, we must keep any changes made to the left if they were valid.
                        // Actually, if we are at idx=N and couldn't find a valid char, we move to idx=N-1.
                        // We must increment idx=N-1.
                        // The value at idx=N-1 in 'work_str' is what we need to increment from.
                        // But wait, if we successfully found a valid char at idx=N-1 previously, then moved to idx=N, that means the char at idx=N-1 is fixed.
                        // So 'work_str' is correct.
                        
                        // When moving left:
                        // idx = idx - 1.
                        // char_val = work_str[idx] + 1.
                        // But we need to restore the 'right' part of work_str to original input? 
                        // Yes, because we are backtracking. We are changing idx-1, so we discard solutions at idx and beyond.
                        // So we should reset work_str[idx...] to s_in[idx...].
                        
                        // Correction for next state assignments:
                        temp_str_next = work_str;
                        // Actually, we need to keep 's_in' separate to restore right side.
                        // Let's keep 'temp_str' as the original input 's_in'.
                        // Wait, in IDLE we set temp_str_next = s_in. So temp_str IS the original input.
                        
                        // Now in SEARCH moving left:
                        // We need to restore work_str[idx:] to temp_str[idx:]
                        // Since we are moving to idx-1, we need to restore work_str[idx-1:] to temp_str[idx-1:]
                        // But we want to keep work_str[0:idx-2] (the prefix) as is.
                        // So we need to merge.
                        // Let's do this:
                        // work_str[0 +: (idx-1)*8] remains.
                        // work_str[(idx-1)*8 +: (n - (idx-1))*8] becomes temp_str[(idx-1)*8 +: (n - (idx-1))*8]
                        // We can do this by generating next_work_str in the block.
                        
                        char_val_next = work_str[(idx - 1) * 8 +: 8] - 8'h61 + 1; // Increment original value
                        
                        // Update work_str to restore right part
                        // We need a next_work_str signal to do this. 
                        // Let's add a next_work_str reg.
                    end
                end else begin
                    // Try current char_val
                    state_next = VALIDATE;
                    // Prepare for validation: 
                    // We are checking if inserting char_val at idx is valid given the left part of work_str.
                    // We will set up the combinational block to check this.
                end
            end

            VALIDATE: begin
                // Check if 'char_val' is valid at 'idx'
                // Constraints: 
                // 1. char_at_idx != char_at_idx_minus_1
                // 2. char_at_idx != char_at_idx_minus_2
                // Note: work_str holds the prefix 0..idx-1.
                // We need to check against work_str[idx-1] and work_str[idx-2].
                
                // We use the combinational block defined below.
                // If valid:
                //   Update work_str[idx] = char_val + 61.
                //   If idx == n-1, go to DONE.
                //   Else, go to FILL.
                // If invalid:
                //   Increment char_val.
                //   Go back to SEARCH (which will handle bounds check).
                
                // Let's decide next state here based on the combinational output.
                // However, we need to assign work_str[idx] first.
                
                // Let's do the check in combinational logic block.
                // If is_valid_check is true:
                //   work_str_next[idx] = char_val + 61.
                //   If idx == n-1: state_next = DONE.
                //   Else: state_next = FILL.
                // Else:
                //   char_val_next = char_val + 1.
                //   state_next = SEARCH.
                
                // Wait, in SEARCH we handle bounds. But here we just increment.
                // If we increment char_val here, we need to loop back to SEARCH to check bounds.
                // Or we can check bounds here.
                
                if (is_valid_check) begin
                    // Commit char
                    work_str[idx * 8 +: 8] = char_val + 8'h61;
                    if (idx == n - 1) begin
                        state_next = DONE;
                    end else begin
                        state_next = FILL;
                        idx_next = idx + 1;
                        char_val_next = 5'd0;
                    end
                end else begin
                    // Try next char
                    char_val_next = char_val + 1;
                    state_next = SEARCH;
                end
            end

            FILL: begin
                // Greedily fill from idx to n-1
                // We need to find the smallest valid char for current idx.
                // Constraints: check against idx-1 and idx-2.
                // Note: work_str already contains valid prefix.
                
                // We need to iterate char_val from 0 to p-1.
                // Since we are in FILL, we try char_val=0, then 1, etc.
                // We can use a simple loop state or combinational check.
                // Given latency constraints, sequential check is fine.
                
                // We can reuse VALIDATE logic, but we need to handle the loop.
                // Let's try char_val = 0.
                // Check validity.
                // If valid: set char, increment idx. If idx==n, Done. Else repeat.
                // If invalid: increment char_val, check again.
                
                // This looks like a loop. We can structure it as:
                // 1. Try current char_val (starts at 0).
                // 2. Check valid (combinational).
                // 3. If valid: commit, idx++, if idx==n DONE else char_val=0.
                // 4. If invalid: char_val++, check bounds. If < p, repeat 2. Else -> Backtrack? 
                //   Actually, if FILL fails at idx k, it means no valid char for k.
                //   We must backtrack to k-1. But k-1 is part of the prefix we just fixed?
                //   No, k-1 was found in VALIDATE or previous FILL step.
                //   If k-1 is not the last character we incremented in the backtracking phase (the one we are trying to increase), then we can't change it.
                //   Wait, the algorithm says:
                //   "Try to increment the character at current index. If valid, fill remaining."
                //   This implies we are at index `idx` (which we incremented).
                //   We found a valid char for `idx`.
                //   Now we try to fill `idx+1`, `idx+2`...
                //   If we can't fill `idx+1`, then our choice of char at `idx` was invalid? No, char at `idx` was valid given left side. But it makes right side impossible.
                //   If greedy fill fails, we must backtrack. But since we are looking for the NEXT string, and we incremented `idx`, we should try the NEXT value at `idx`.
                //   But wait, we are in FILL. We are filling `idx` (which is > the originally incremented index).
                //   If we can't fill `idx`, we should try a larger value at `idx`.
                //   If `idx` is the index we just set in VALIDATE (the "pivot"), we can increment it.
                //   But if `idx` is greater than the pivot, we can't increment the pivot. We should try larger values at `idx`.
                //   If we exhaust `idx`, then we are stuck. We must backtrack to the pivot.
                //   This gets complex.
                
                // Simplified approach for FILL state:
                // We are at index 'idx'. We need to find a valid char.
                // We try char_val = 0, 1, ...
                // If we find one: set it, move to idx+1.
                // If we don't find one (char_val reaches p):
                //   This means the prefix (0..idx-1) cannot be extended.
                //   But wait, the prefix (0..idx-1) was valid. Why can't we extend?
                //   Because the char at idx-1 (the pivot) might be too restrictive.
                //   So we must go back to idx-1 and increment it.
                //   This means moving from FILL back to SEARCH logic at idx-1.
                //   But we need to distinguish between the "pivot" (the one we just modified) and fillers.
                
                // Alternative:
                // Use a single loop state that manages the fill.
                // But the instructions say: "If valid, fill remaining positions to the right greedily".
                // This suggests we set the pivot, then jump to FILL.
                // In FILL, we iterate.
                // If FILL fails, we assert backtracking.
                // Backtracking from FILL means we return to SEARCH at the pivot index.
                
                // Let's add a flag or state to handle the FILL loop.
                // Or, since the latency is generous (16*26*2), we can do one attempt per cycle.
                
                // State FILL logic:
                // We are at 'idx'. We want to set a char here.
                // We try 'char_val' (initialized to 0 when entering FILL).
                // Check if 'char_val' is valid against work_str[idx-1] and work_str[idx-2].
                // If valid:
                //   work_str[idx] = char_val + 61.
                //   idx++.
                //   If idx == n, DONE.
                //   Else, stay in FILL, reset char_val to 0.
                // If invalid:
                //   char_val++.
                //   If char_val < p, stay in FILL.
                //   If char_val == p, 
                //     This position cannot be filled. We must backtrack.
                //     Decrement idx.
                //     If idx == pivot_index (the one we found in VALIDATE), go to SEARCH state (to increment it).
                //     If idx < pivot_index, this shouldn't happen if pivot was valid.
                //     But we need to know where the pivot is.
                //     Let's store pivot_idx.
                
                // Wait, if we are in FILL and fail at idx=k, we go to idx=k-1.
                // But idx=k-1 has a fixed char from the previous step.
                // We need to increment it. But we are not allowed to change the prefix (0..pivot-1).
                // Only the pivot and right side can change.
                // So, we should go back to the pivot.
                // How do we know pivot? 
                // Pivot is the index that transitioned from SEARCH/VALIDATE to FILL.
                // Or, simpler: The algorithm is:
                // 1. Backtrack (go left) until we find a character we can increment.
                // 2. Increment it.
                // 3. If valid, fill right.
                // 4. If full, Done.
                
                // My current structure: IDLE -> SEARCH -> VALIDATE -> FILL.
                // SEARCH finds the index to modify and increments it.
                // VALIDATE checks validity.
                // FILL fills right.
                // If FILL fails, we need to go back to SEARCH at the same index.
                // But SEARCH expects to increment. If we are at the pivot, we need to try next char.
                // If we are to the right of pivot, we need to try next char.
                // So, if FILL fails at idx k:
                //   We go to SEARCH.
                //   But SEARCH will look at idx k.
                //   We need to tell SEARCH: "Try next char at idx k".
                //   Currently, SEARCH handles increments.
                //   So, FILL fail -> SEARCH (idx=k, char_val=current+1).
                
                // But what if idx k is the pivot?
                // If we are at pivot, we just incremented it in VALIDATE. We tried a value.
                // In FILL, we start at idx = pivot + 1.
                // If FILL fails, we need to try a larger value at pivot.
                // So we go to SEARCH, idx = pivot.
                // SEARCH will increment char_val.
                
                // So the logic holds: FILL fails -> SEARCH at current idx.
                // But wait, FILL iterates idx. 
                // Example: n=3. Pivot is idx=1.
                // VALIDATE at idx=1 checks validity. Pass.
                // Go to FILL. idx becomes 2.
                // FILL at idx=2 tries 0..p-1. Fails.
                // State -> SEARCH. idx=2.
                // SEARCH sees idx=2. char_val = p. Move left. idx=1.
                // SEARCH sees idx=1. char_val = previous_val + 1.
                // This works.
                
                // So, FILL state logic:
                // We are at 'idx'.
                // We try 'char_val' (starts at 0).
                // Check validity.
                // If valid: set char, idx++, char_val=0.
                // If idx==n, DONE.
                // If invalid: char_val++.
                // If char_val == p: we failed to fill this position.
                //   State = SEARCH.
                //   (Don't change idx, SEARCH will handle moving left if needed).
                //   (Don't increment char_val here, SEARCH will check if char_val is out of bounds).
                //   Wait, if we failed to fill idx k, it means 0..p-1 are invalid.
                //   So char_val at idx k is effectively p (exhausted).
                //   So we move to SEARCH.
                //   SEARCH will see char_val >= p, so it moves left.
                //   This is correct.
                
                // Implementation:
                // Need to compute is_valid_check for current char_val.
                // Needs to be combinational or registered?
                // Let's use combinational logic block at the bottom.
                
                // But we need to handle the "reset char_val to 0 when incrementing idx".
                // And we need to update work_str.
            end

            DONE: begin
                valid_next = 1'b1;
                s_out_next = work_str;
                if (start) state_next = IDLE; // Reset if start is pressed again
            end

            NO_SOLUTION: begin
                no_solution_next = 1'b1;
                if (start) state_next = IDLE;
            end
        endcase
        
        // Special handling for IDLE->SEARCH transition logic (initialization)
        // We need to copy s_in to work_str and set initial idx/char_val.
        // We can do this in the IDLE state block.
    end

    // Combinational Logic for Validation
    // This checks if 'char_val' is valid at 'pos' in 'check_str'
    // We need to map this to the state machine needs.
    // In VALIDATE state: pos = idx, check_str = work_str, char_val = char_val.
    // In FILL state: pos = idx, check_str = work_str, char_val = char_val.
    
    // Let's separate the validation logic into a function-like block or just inline it where needed.
    // It's easier to just inline the check in the FSM combinational block using 'work_str'.
    
    // However, we need to update 'work_str' in VALIDATE and FILL.
    // Let's add a 'work_str_next' signal.
    reg [127:0] work_str_next;
    
    // Revisiting the FSM block to include work_str_next logic clearly.
    
    always @(*) begin
        // Default assignments
        state_next = state;
        idx_next = idx;
        char_val_next = char_val;
        work_str_next = work_str;
        temp_str_next = temp_str;
        valid_next = 1'b0;
        no_solution_next = 1'b0;
        s_out_next = s_out;

        case (state)
            IDLE: begin
                if (start) begin
                    work_str_next = s_in;
                    temp_str_next = s_in; // Save original input to restore right side when backtracking
                    idx_next = n - 1;
                    // Start incrementing from the original value at n-1
                    char_val_next = (s_in[(n-1)*8 +: 8] - 8'h61) + 1;
                    state_next = SEARCH;
                end
            end

            SEARCH: begin
                // Check if current char_val is within bounds
                if (char_val < p) begin
                    // Check validity
                    // Valid if:
                    // 1. idx >= 1 -> char_val != work_str[(idx-1)*8 +: 8] - 8'h61
                    // 2. idx >= 2 -> char_val != work_str[(idx-2)*8 +: 8] - 8'h61
                    // Note: work_str holds the current prefix.
                    
                    reg valid_try;
                    valid_try = 1'b1;
                    if (idx >= 1 && char_val == (work_str[(idx-1)*8 +: 8] - 8'h61)) valid_try = 1'b0;
                    if (idx >= 2 && char_val == (work_str[(idx-2)*8 +: 8] - 8'h61)) valid_try = 1'b0;
                    
                    if (valid_try) begin
                        // Found a valid candidate
                        work_str_next[idx * 8 +: 8] = char_val + 8'h61;
                        
                        // Now we need to fill the rest
                        // If idx == n-1, we are done filling
                        if (idx == n - 1) begin
                            state_next = DONE;
                        end else begin
                            // Move to filling next positions
                            state_next = FILL;
                            idx_next = idx + 1;
                            char_val_next = 5'd0; // Start filling from 'a'
                        end
                    end else begin
                        // Not valid, try next character
                        char_val_next = char_val + 1;
                        // Stay in SEARCH
                    end
                end else begin
                    // char_val >= p, exhausted options at this index
                    // Backtrack: move left
                    if (idx == 0) begin
                        state_next = NO_SOLUTION;
                    end else begin
                        idx_next = idx - 1;
                        // Restore work_str from original input for indices >= idx-1 (which is the new current idx)
                        // Actually, we just need to restore the right side of the new idx.
                        // work_str[0 : (idx-1)-1] is valid.
                        // work_str[(idx-1)*8 : end] needs to be reset to original s_in values.
                        // We have s_in in temp_str.
                        work_str_next = work_str; // Keep prefix
                        // We need to assign the rest. Verilog doesn't support variable slice assignment easily in always @(*) if not blocking.
                        // We can do it bit by bit or generate a mask.
                        // Since we are moving left, we are modifying index `idx-1`.
                        // We want to restore `idx-1` and everything to the right.
                        // Wait, if we move left, we are about to try a new value for `idx-1`.
                        // The old value of `idx-1` (in work_str) is `old_val`. We failed with `old_val`.
                        // The original value in `temp_str` is `orig_val`.
                        // If `old_val` > `orig_val`, we keep `old_val` as the base? No, we want to increment `idx-1`. 
                        // If `old_val` was found by incrementing `orig_val`, then we keep `old_val` as the prefix.
                        // But wait, we failed at `idx`. We go to `idx-1`.
                        // We want to increment `idx-1`. The current value at `idx-1` is what we found (or tried) earlier.
                        // We should keep it.
                        // However, if we move left from `idx`, we need to clear `idx` (and beyond) so we don't accidentally use old values.
                        // But `SEARCH` at `idx-1` will overwrite `idx` eventually.
                        // So we don't strictly need to clear it, but it's cleaner.
                        // Crucially: the value at `idx-1` should be the one we previously found (or started with).
                        // When we enter IDLE, we set work_str = s_in.
                        // In SEARCH, we modify work_str[idx].
                        // When backtracking from idx=i to i-1, we need to keep work_str[i-1].
                        // So we don't need to restore work_str.
                        // EXCEPT: When we go from FILL back to SEARCH (fail to fill).
                        // In FILL, we might have set work_str[fill_idx].
                        // If FILL fails at idx=k, we go to SEARCH at idx=k.
                        // But wait, if we fail to fill k, we can't change k. We must change k-1.
                        // But k-1 is the pivot.
                        // So we go to SEARCH at idx=k-1.
                        // In that case, we MUST restore work_str[k] to original (or clear it).
                        // So, we need to restore the suffix.
                        
                        // Let's add a restore logic:
                        // work_str_next[ (idx-1)*8 +: (n - (idx-1))*8 ] = temp_str[ (idx-1)*8 +: (n - (idx-1))*8 ]
                        // Since we can't do that easily in one line in combinational block without generate loops or manual bit selection, 
                        // we will do it in the sequential block or handle it specifically in the SEARCH state.
                        
                        // Actually, let's rely on the fact that in SEARCH, we are going to overwrite `idx` immediately.
                        // But we might move left multiple times.
                        // If we move left multiple times (e.g. idx=5 -> idx=4 -> idx=3), we need to make sure `work_str[4]` is valid.
                        // `work_str[4]` is valid because it was fixed when we went right.
                        // So we only need to restore when backtracking from FILL failure.
                        // Let's add a flag or handle it in FILL state.
                        
                        // Let's modify the transition from FILL failure.
                        // If FILL fails (char_val == p), we need to:
                        // 1. Restore suffix.
                        // 2. Go to SEARCH at idx-1.
                        // So we can't just jump to SEARCH. We need a restore step.
                        // Or, we can make SEARCH smart enough to restore if idx is less than n-1 and we are coming from failure.
                        // Actually, let's just do the restore in the sequential logic or add a state.
                        // Or, simplest: When moving left in SEARCH (due to char_val exhaustion), we restore suffix.
                        // When moving left from FILL failure, we set state to SEARCH, idx to current-1.
                        // And we need to set a flag to restore suffix.
                        // Or, just handle restoration in SEARCH state.
                        
                        // Let's do this:
                        // In SEARCH, if we enter due to backtrack (from FILL or previous SEARCH exhaustion),
                        // we need to restore work_str[idx] and right from temp_str.
                        // But we might be coming from IDLE (fresh start).
                        
                        // Let's add a signal `restore_suffix`.
                        // Or, we can just check: if state_next == SEARCH and we are coming from FILL (or exhausted), restore.
                        
                        // Let's do it in the sequential block explicitly if we need it, but we can infer it.
                        // Actually, we can do it in SEARCH block:
                        // "If we just moved left (idx changed), restore work_str[idx...]"
                        // But that requires detecting the edge.
                        
                        // Let's try a different approach.
                        // FILL fail: 
                        //   state_next = SEARCH;
                        //   idx_next = idx; // We are at 'idx', which failed. 
                        //   Wait, if FILL fails at idx=k, we can't fill k. So we must change k-1.
                        //   So idx_next = idx - 1.
                        //   And we MUST restore work_str[k...] to temp_str[k...].
                        //   And we MUST increment char_val at k-1.
                        //   So we need to know the value at k-1.
                        //   work_str[k-1] is the pivot. We need to increment it.
                        //   So we set char_val_next = work_str[k-1] - 61 + 1.
                        
                        // So, logic for FILL fail:
                        //   idx_next = idx - 1;
                        //   char_val_next = work_str[(idx-1)*8 +: 8] - 8'h61 + 1;
                        //   work_str_next = work_str; // But we need to mask out suffix.
                        
                        // Since we can't easily mask in always @(*), let's do the masking in the sequential block or use a helper block.
                        // Or, we can use `generate` to create bit masks, but that's complex.
                        // Let's use a helper loop in combinational block.
                        
                        // Actually, we can assign `work_str_next` to `work_str` first, then overwrite the suffix if needed.
                        // But we need to overwrite the suffix with `temp_str`.
                        // So we need to copy `temp_str` to `work_str` for the range [idx-1 : n-1].
                        
                        // We can do:
                        // work_str_next = work_str;
                        // work_str_next[ (idx-1)*8 +: (n - (idx-1))*8 ] = temp_str[ (idx-1)*8 +: (n - (idx-1))*8 ];
                        // But variable slice width is not supported in standard Verilog always @(*) if the width is variable.
                        // We can unroll the loop or just accept we will do it in the sequential block?
                        // No, this is a combinatorial logic request.
                        
                        // Let's change the design: 
                        // Instead of restoring in SEARCH, we can restore in a dedicated step or just be smart.
                        // If we are in SEARCH and idx < n-1, we assume we are backtracking or filling.
                        // If we are backtracking, we need to restore.
                        // 
                        // Let's add a state: RESTORE.
                        // But that adds latency.
                        // 
                        // Let's rely on the fact that we only need to clear the character we are about to overwrite.
                        // No, we need to clear all to the right because if we find a valid char at idx-1, we go to FILL, and FILL fills idx and beyond.
                        // If we don't restore, work_str[idx] might hold a stale valid character that satisfies local constraints but is lexicographically wrong.
                        // Actually, if we find a valid char at idx-1, we will overwrite idx in FILL (since FILL starts at idx = idx-1 + 1).
                        // So we only need to restore work_str[idx] if we don't find a valid char at idx-1 and move further left.
                        // So, the critical issue is: what if we move left multiple times?
                        // Example: Pivot at 3. Fail to fill 4. Pivot 3 exhausted. Move to 2.
                        // We restore work_str[3:] to original.
                        // We try to increment 2. 
                        // If valid, we go to FILL at 3. We overwrite 3. 
                        // So we only need to restore the *immediate* right sibling if we are moving left.
                        // Actually, we need to restore everything to the right of the new idx.
                        
                        // Given the constraints and complexity, let's try to implement the slice assignment logic using a loop in a combinational block.
                        // This is synthesizable (unrolled). 
                        // But we don't know n at compile time.
                        // So we can't unroll fully.
                        // However, n <= 16. We can do a 16-stage multiplexer or similar.
                        // 
                        // Alternative: Keep the original string in a shift register or just keep track of the "pivot" index.
                        // Actually, the problem is simple: 
                        // We have `work_str` (current prefix) and `temp_str` (original).
                        // When backtracking (moving left), we reset `work_str` from `idx` to `n-1` to `temp_str`.
                        // We can do this bit-by-bit in a combinatorial block using a `for` loop.
                        // Verilog `for` loops in `always @(*)` are unrolled during synthesis. Since max n=16, it's fine.
                        
                        // So, we need a combinational block or an always block that handles this update.
                        // Let's define `always @(*)` to compute `work_str_next`.
                        // We will use the `state` and `idx` to decide.
                    end
                    
                    // Back to the logic for SEARCH exhaustion (char_val >= p):
                    if (idx == 0) state_next = NO_SOLUTION;
                    else begin
                        idx_next = idx - 1;
                        // We need to restore suffix in work_str_next
                        // We will handle this after the case statement or in a separate combinational block.
                        // Actually, let's just set `char_val_next` correctly.
                        // The value to increment is work_str[(idx-1)*8 +: 8].
                        // But work_str[(idx-1)*8 +: 8] might be stale if we came from FILL failure.
                        // Wait, in SEARCH, if we enter due to exhaustion, we are at idx i.
                        // If we move left, we go to i-1.
                        // The value at i-1 in work_str should be valid (it was found previously).
                        // EXCEPT if we came from FILL failure.
                        // So, we need to distinguish IDLE start vs FILL failure.
                        
                        // Let's use `temp_str` to hold the original string.
                        // And let's add a logic to reset work_str[idx] to temp_str[idx] when moving left.
                        // We can do this by adding a `restore` flag or a specific state.
                        
                        // Let's modify FILL failure:
                        // FILL failure: 
                        //   state_next = RESTORE;
                        //   restore_idx = idx; // We want to restore from idx onwards
                        //   move_target = idx - 1; // We want to go here after restore
                        //   Or simpler: State RESTORE does: work_str = temp_str (for suffix).
                        
                        // State RESTORE:
                        //   work_str_next = work_str; // keep prefix
                        //   for(int k=idx; k<n; k++) work_str_next[k*8+:8] = temp_str[k*8+:8];
                        //   idx_next = idx - 1; // Decrement to target
                        //   state_next = SEARCH;
                        //   // In SEARCH, we need to set char_val to work_str[idx] + 1.
                        //   // But work_str[idx] is now original.
                        //   // So we need to tell SEARCH to use original value.
                        //   // Or, we can set char_val_next here.
                        //   char_val_next = temp_str[(idx-1)*8+:8] - 8'h61 + 1;
                        
                        // This seems cleaner.
                    end
                end
            end
            
            // We need a RESTORE state to handle suffix reset from FILL failure
            // Or, we can handle it in FILL state by setting a flag, but that complicates FILL.
            // Let's add a RESTORE state.
            
            // Wait, if we don't add RESTORE, can we do it in SEARCH?
            // SEARCH is entered for incrementing.
            // If we come from FILL, we are at idx i. We want to try i-1.
            // We can handle it by adding a "backtrack" input to SEARCH or a flag.
            // Let's use a flag `backtrack_from_fill`.
            // But that adds state.
            // 
            // Let's stick to the "RESTORE" state for clarity.
            // Transitions:
            // FILL fail -> RESTORE
            // SEARCH exhaust -> RESTORE
            // RESTORE -> SEARCH
            
            // So, let's rewrite the logic above.
            // (The generated code below will reflect this cleaner logic).

            // Revised State Machine Logic:
            // IDLE: init work_str, idx=n-1, char=s[n-1]+1. -> SEARCH.
            // SEARCH: 
            //   If char < p:
            //     Check valid.
            //     If valid: work_str[idx]=char. If idx==n-1 -> DONE. Else -> FILL (idx++, char=0).
            //     If invalid: char++.
            //   Else: // char >= p
            //     If idx == 0 -> NO_SOLUTION.
            //     Else -> RESTORE (target_idx = idx-1).
            // FILL:
            //   If char < p:
            //     Check valid.
            //     If valid: work_str[idx]=char. idx++. If idx==n -> DONE. Else char=0.
            //     If invalid: char++.
            //   Else: // FILL failed at idx
            //     -> RESTORE (target_idx = idx-1).
            // RESTORE:
            //   // Work: restore work_str[target_idx+1 ... n-1] from temp_str.
            //   // Then -> SEARCH.
            //   // In SEARCH, we need to start incrementing target_idx.
            //   // Original value at target_idx is now in work_str (restored).
            //   // We need to increment it.
            //   // So, in RESTORE, we set next_idx = target_idx.
            //   // And we need to set char_val = work_str[target_idx] + 1.
            //   // But wait, in RESTORE we set work_str[target_idx+1...] to temp_str.
            //   // We also need to ensure work_str[target_idx] is correct.
            //   // work_str[target_idx] was valid before we went to FILL.
            //   // But we might have incremented it multiple times.
            //   // Actually, the value in work_str[target_idx] is the one we tried and passed validation.
            //   // We want to try the NEXT value.
            //   // So we should NOT restore work_str[target_idx].
            //   // We should only restore work_str[target_idx+1 ...].
            //   // So, RESTORE restores suffix starting from target_idx + 1.
            
            // Let's refine RESTORE:
            // Target = idx - 1 (from FILL) or idx (from SEARCH exhaustion? No, SEARCH exhaust happens at idx, we go to idx-1).
            // So, RESTORE takes input `next_idx` (the index we want to increment).
            // It restores `work_str` from `next_idx + 1` to `n-1` using `temp_str`.
            // It sets `idx_next = next_idx`.
            // It sets `char_val_next = work_str[next_idx] - 61 + 1`.
            // Wait, `work_str[next_idx]` is the current value. We want to increment it.
            // But we need to be careful about `work_str`.
            // If we are coming from FILL, `work_str[next_idx]` is the pivot. It's valid.
            // If we are coming from SEARCH exhaustion, `work_str[next_idx]` is the previous pivot. It's valid.
            // So we use `work_str`.
            // BUT, we must restore the suffix first so we don't accidentally use stale values in SEARCH validity check.
            // 
            // So, RESTORE logic:
            // work_str_next = work_str;
            // for (k = next_idx + 1; k < n; k++) work_str_next[k*8+:8] = temp_str[k*8+:8];
            // idx_next = next_idx;
            // char_val_next = (work_str[next_idx*8+:8] - 8'h61) + 1;
            // state_next = SEARCH;
            // Wait, if we update work_str_next in combinational block, we can't loop easily.
            // We will handle `work_str_next` update explicitly in the state transitions.
            
            // Let's simplify and assume we can do the restore in the sequential block logic or 
            // use the fact that in SEARCH, we don't rely on right side values to validate left side.
            // We only rely on left side.
            // When we go to SEARCH at idx=k, we check validity against idx-1 and idx-2.
            // Those are to the left.
            // So we don't actually need to restore the suffix immediately for validity check!
            // We only need to restore it when we transition to FILL (to have correct initial state for FILL).
            // And we need to restore it if we move left multiple times, because the value at idx-1 might depend on what we tried?
            // No, idx-1 is fixed until we increment it.
            // 
            // So, we can skip the explicit RESTORE state if we restore suffix at the transition to FILL.
            // And if we move left in SEARCH (exhaustion), we just decrement idx. 
            // But we need to clear `work_str[idx]`? No, we will overwrite it if we find a valid char.
            // 
            // However, what if we backtrack multiple times?
            // Example: work_str = ...X|Y|Z. We fail at Z (FILL). We go to Y (SEARCH). We increment Y. Valid. Go to FILL at Z.
            // We need Z to be reset to original (or 0) for FILL to start fresh.
            // So, we need to reset Z.
            // 
            // Let's add logic in FILL state entry (or reset char_val to 0) AND restore work_str[idx] to temp_str[idx].
            // So, when we enter FILL (from VALIDATE success), we set work_str[idx] = temp_str[idx]? No, we just set it to the new valid char.
            // When we enter FILL (from ... wait, FILL is only entered from VALIDATE success).
            // VALIDATE success means we found a valid char at `idx`. We set `work_str[idx]`.
            // Then we go to FILL. `idx` becomes `idx+1`. `char_val` becomes 0.
            // We need `work_str[idx+1]` to be original? No, `FILL` will overwrite it.
            // But `FILL` checks validity against `idx` (which we just set) and `idx-1`.
            // So `work_str` is correct.
            // 
            // The problem is when FILL fails.
            // FILL fails at `idx`. We need to backtrack to `idx-1`.
            // We go to SEARCH at `idx-1`. 
            // We need to increment `idx-1`. `work_str[idx-1]` is the pivot. It's correct.
            // But we also need to make sure `work_str[idx]` doesn't affect anything.
            // It won't affect validation of `idx-1`.
            // So we are safe.
            // 
            // EXCEPT: If we fail at `idx`, we try `idx-1`. 
            // If `idx-1` is valid (incremented), we go to FILL at `idx`. 
            // FILL at `idx` needs to try values from 0.
            // `work_str[idx]` currently holds the old (failed) value or whatever.
            // FILL will check validity. It only reads `work_str[idx-1]` and `work_str[idx-2]`.
            // It does not read `work_str[idx]`.
            // So we are fine.
            // 
            // So, do we ever need to restore?
            // We need to restore `work_str` only if we use it for validation.
            // We validate against left neighbors.
            // So we only need correct values in `work_str` at indices < current idx.
            // 
            // Wait, FILL checks `char_val` against `work_str[idx-1]` and `work_str[idx-2]`.
            // These are correct.
            // So we don't need to restore!
            // 
            // Let's verify with the algorithm:
            // 1. Start at rightmost.
            // 2. Increment char. Check constraints with left.
            // 3. If valid, fill right.
            // 
            // My implementation:
            // SEARCH: tries to increment `idx`. Checks against left. Updates `work_str[idx]`.
            // FILL: fills `idx+1`, `idx+2`... Checks against left. Updates `work_str[idx]`.
            // 
            // When FILL fails at `idx=k`, we go to SEARCH at `idx=k-1`.
            // SEARCH at `k-1` increments `char_val` from `work_str[k-1]`. Checks against `k-2`, `k-3`. 
            // This is valid.
            // If valid, SEARCH sets `work_str[k-1]` to new value.
            // Then goes to FILL at `idx=k`. 
            // FILL at `k` starts `char_val=0`. Checks against `k-1`, `k-2`. 
            // `work_str[k-1]` is updated. `work_str[k-2]` is old valid. 
            // Checks pass.
            // So we don't need to restore `work_str[k]` because we overwrite it in FILL.
            // 
            // What about moving left multiple times in SEARCH exhaustion?
            // `work_str` holds prefix.
            // If we move left, we decrement `idx`. 
            // `work_str` for indices >= new `idx` might be stale.
            // But we check against left neighbors. So stale values at right don't matter.
            // So we are safe.
            // 
            // So, we don't need a RESTORE state!
            // We just need to handle transitions and updates.

            // --- REDOING FSM LOGIC WITH THIS SIMPLIFICATION ---

            IDLE: begin
                if (start) begin
                    work_str_next = s_in;
                    idx_next = n - 1;
                    char_val_next = (s_in[(n-1)*8 +: 8] - 8'h61) + 1;
                    state_next = SEARCH;
                end
            end

            SEARCH: begin
                if (char_val < p) begin
                    // Check validity against left neighbors
                    reg valid_try;
                    valid_try = 1'b1;
                    if (idx >= 1) begin
                        if (char_val == (work_str[(idx-1)*8 +: 8] - 8'h61)) valid_try = 1'b0;
                    end
                    if (idx >= 2) begin
                        if (char_val == (work_str[(idx-2)*8 +: 8] - 8'h61)) valid_try = 1'b0;
                    end

                    if (valid_try) begin
                        work_str_next[idx * 8 +: 8] = char_val + 8'h61;
                        if (idx == n - 1) begin
                            state_next = DONE;
                        end else begin
                            state_next = FILL;
                            idx_next = idx + 1;
                            char_val_next = 5'd0;
                        end
                    end else begin
                        char_val_next = char_val + 1;
                    end
                end else begin
                    // Exhausted at this index, backtrack
                    if (idx == 0) begin
                        state_next = NO_SOLUTION;
                    end else begin
                        idx_next = idx - 1;
                        char_val_next = (work_str[(idx-1)*8 +: 8] - 8'h61) + 1;
                        // Note: work_str[(idx-1)*8 +: 8] is the value we previously found.
                        // We want to increment it.
                    end
                end
            end

            FILL: begin
                // Try to fill current idx with char_val
                if (char_val < p) begin
                    reg valid_try;
                    valid_try = 1'b1;
                    if (idx >= 1) begin
                        if (char_val == (work_str[(idx-1)*8 +: 8] - 8'h61)) valid_try = 1'b0;
                    end
                    if (idx >= 2) begin
                        if (char_val == (work_str[(idx-2)*8 +: 8] - 8'h61)) valid_try = 1'b0;
                    end

                    if (valid_try) begin
                        work_str_next[idx * 8 +: 8] = char_val + 8'h61;
                        idx_next = idx + 1;
                        if (idx_next == n) begin // Check if we just filled the last char
                            state_next = DONE;
                        end else begin
                            char_val_next = 5'd0; // Continue filling next position
                        end
                    end else begin
                        char_val_next = char_val + 1;
                    end
                end else begin
                    // Cannot fill this position, backtrack to previous
                    if (idx == 0) begin // Should not happen if logic is correct, but safety
                        state_next = NO_SOLUTION;
                    end else begin
                        idx_next = idx - 1;
                        // We need to increment the previous character.
                        // But we are currently in FILL state. We need to go to SEARCH logic to increment.
                        // Or we can compute the next value here and go to SEARCH.
                        // Let's go to SEARCH.
                        // We need to set char_val to work_str[idx-1] + 1.
                        // However, we are in FILL. The previous character (idx-1) is valid.
                        // We want to increment it.
                        // But we can't just jump to SEARCH with char_val = work_str[idx-1] + 1 because SEARCH expects to handle the current char.
                        // Wait, if we go to SEARCH with idx=idx-1, SEARCH will read char_val from register.
                        // The register char_val currently holds 'p' (exhausted).
                        // So we need to update char_val_next.
                        char_val_next = (work_str[(idx-1)*8 +: 8] - 8'h61) + 1;
                        state_next = SEARCH;
                    end
                end
            end

            DONE: begin
                valid_next = 1'b1;
                s_out_next = work_str;
                if (start) state_next = IDLE;
            end

            NO_SOLUTION: begin
                no_solution_next = 1'b1;
                if (start) state_next = IDLE;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            no_solution <= 1'b0;
            // Reset other regs if needed, though IDLE handles load
        end else begin
            state <= state_next;
            idx <= idx_next;
            char_val <= char_val_next;
            work_str <= work_str_next;
            // temp_str only updated in IDLE, so we need to keep it
            // Actually, temp_str_next is assigned in IDLE only in my logic above.
            // But to be safe, we update it.
            if (state == IDLE && start) begin
                temp_str <= temp_str_next;
            end
            valid <= valid_next;
            no_solution <= no_solution_next;
            s_out <= s_out_next;
        end
    end

endmodule
