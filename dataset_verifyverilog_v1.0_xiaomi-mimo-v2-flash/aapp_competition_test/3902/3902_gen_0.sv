module find_suffixes (
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] s_ascii,
    input [3:0] s_len,
    output reg [4:0] result_count,
    output reg [15:0][31:0] result_suffixes,
    output reg [15:0][1:0] result_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // State registers
    reg [1:0] state, next_state;
    reg [4:0] idx; // Current position index (5 to 15)
    reg [4:0] cycle_count; // Cycle counter for timeout
    localparam [4:0] MAX_CYCLES = 5'd20; // Enough for DP (16 states * ~1 cycle)

    // DP arrays: reach2[i] = 1 if suffix of length 2 starting at i is valid
    // reach3[i] = 1 if suffix of length 3 starting at i is valid
    reg [15:0] reach2_reg;
    reg [15:0] reach3_reg;
    
    // Temporary storage for comparison results
    reg temp_reach2;
    reg temp_reach3;
    reg [31:0] suffix_val;
    reg [1:0] suffix_len;
    reg match_found;
    
    // Deduplication storage
    reg [31:0] stored_suffixes [0:15]; // Internal array
    reg [15:0] stored_lens [0:15];      // Internal array
    reg [4:0] stored_count;
    
    // Combinational comparison variables
    wire [7:0] char1, char2, char3, char4, char5, char6;
    wire cmp2_success;
    wire cmp3_success;
    
    // Assign chars for easy access
    assign char1 = s_ascii[idx];
    assign char2 = s_ascii[idx + 1];
    assign char3 = s_ascii[idx + 2];
    assign char4 = s_ascii[idx + 3];
    assign char5 = s_ascii[idx + 4];
    assign char6 = s_ascii[idx + 5];
    
    // 2-char comparison: s[i:i+2] != s[i+2:i+4]
    // Compare 3 chars (though problem says suffixes, likely 2 chars vs 2 chars for length 2)
    // Actually problem: "compare s[i:i+2] with s[i+2:i+4]"
    // This implies comparing 2 chars from current with 2 chars from next
    // But logic: if i+2 is reachable, check if current suffix matches next suffix
    // Constraint: "no two consecutive suffixes are identical"
    // So if we take 2 chars at i, and next starts at i+2 (length 2), they must differ
    wire [15:0] vec1_2, vec2_2;
    assign vec1_2 = {char2, char1}; // Reversed for little-endian storage if needed
    assign vec2_2 = {char4, char3};
    assign cmp2_success = (vec1_2 != vec2_2); // Strings differ
    
    // 3-char comparison: s[i:i+3] != s[i+3:i+6]
    wire [23:0] vec1_3, vec2_3;
    assign vec1_3 = {char3, char2, char1};
    assign vec2_3 = {char6, char5, char4};
    assign cmp3_success = (vec1_3 != vec2_3); // Strings differ

    // --- State Transition Logic ---
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE : IDLE;
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES || idx < 5'd5) // 5 is min length for root
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // --- Output and Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result_count <= 5'd0;
            idx <= 5'd0;
            cycle_count <= 5'd0;
            reach2_reg <= 16'd0;
            reach3_reg <= 16'd0;
            stored_count <= 5'd0;
            temp_reach2 <= 1'b0;
            temp_reach3 <= 1'b0;
            suffix_val <= 32'd0;
            suffix_len <= 2'd0;
            match_found <= 1'b0;
            
            // Clear outputs
            for (integer i = 0; i < 16; i = i + 1) begin
                result_suffixes[i] <= 32'd0;
                result_len[i] <= 2'd0;
                stored_suffixes[i] <= 32'd0;
                stored_lens[i] <= 2'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize DP for last positions
                        reach2_reg <= 16'd0;
                        reach3_reg <= 16'd0;
                        stored_count <= 5'd0;
                        result_count <= 5'd0;
                        cycle_count <= 5'd0;
                        // Mark end positions as reachable (base cases)
                        // If string ends at s_len, positions s_len-2 and s_len-3 are valid ends
                        // provided s_len >= 5
                        if (s_len >= 5) begin
                            if (s_len >= 2'd2) reach2_reg[s_len-2] <= 1'b1;
                            if (s_len >= 3'd3) reach3_reg[s_len-3] <= 1'b1;
                        end
                        // Start from end of string
                        if (s_len >= 5) idx <= s_len - 1;
                        else idx <= 5'd0; // Invalid length, will skip
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    if (idx >= 5'd5 && idx < s_len) begin
                        // Check if we can extend from idx+2 or idx+3
                        // Note: reach arrays track if 'idx' is a valid start of a suffix
                        // We are currently evaluating position 'idx'
                        
                        // 1. Check 2-char suffix at idx
                        // Valid if:
                        //   a) idx+2 is reachable (next suffix exists and is valid)
                        //   b) idx+3 is reachable (next suffix of len 3 exists)
                        //   c) AND adjacency constraint holds
                        //      Constraint: current suffix != next suffix
                        //      If next is len 2: compare s[idx:idx+2] with s[idx+2:idx+4]
                        //      If next is len 3: compare s[idx:idx+2] with s[idx+2:idx+5]
                        //   Wait, problem says: "compare s[i:i+2] with s[i+2:i+4] for length 2 case"
                        //   This implies: if we pick length 2 at i, and the NEXT suffix (starting at i+2) is length 2.
                        //   What if next suffix is length 3?
                        //   The problem description: "compare s[i:i+2] with s[i+2:i+4]"
                        //   It seems specific. Let's interpret: we only care about the immediate neighbor.
                        //   If we place a 2-char at i, and the next part is a 2-char (i+2), compare them.
                        //   If next part is 3-char (i+2), is there a comparison? Problem implies it.
                        //   Let's assume: if next is len 2, compare 2 vs 2. If next is len 3, compare 2 vs 2 of the 3? 
                        //   Or just check existence.
                        //   Let's stick to the text: "compare s[i:i+2] with s[i+2:i+4] for length 2 case"
                        //   This implies the NEXT suffix must be length 2 for this comparison?
                        //   No, "for length 2 case" refers to current suffix.
                        //   Let's simplify: Adjacency constraint applies to the boundary.
                        //   If we take 2 chars, and the next takes 2 chars, they must differ.
                        //   If we take 2 chars, and the next takes 3 chars, they overlap? No, i+2 to i+5.
                        //   Does "consecutive suffixes" mean the literal strings?
                        //   Example: Root + 2 + 3 + 2. Suffix 1 (len 2) vs Suffix 2 (len 3).
                        //   They are consecutive but different lengths -> cannot be "identical" strings.
                        //   So length difference is sufficient to satisfy constraint.
                        //   We only need to compare if lengths are equal.
                        
                        temp_reach2 <= 1'b0;
                        // Check reachability from i+2 (len 2)
                        if (reach2_reg[idx+2] && (idx + 2 >= 5)) begin
                            // Compare current 2-char with next 2-char at idx+2
                            if (cmp2_success) temp_reach2 <= 1'b1;
                        end
                        // Check reachability from i+3 (len 3) -> no comparison needed if lengths differ
                        if (reach3_reg[idx+3] && (idx + 3 >= 5)) begin
                            temp_reach2 <= 1'b1; // Lengths differ (2 vs 3), constraint satisfied
                        end
                        
                        // 2. Check 3-char suffix at idx
                        temp_reach3 <= 1'b0;
                        // Check reachability from i+2 (len 2)
                        if (reach2_reg[idx+2] && (idx + 2 >= 5)) begin
                            temp_reach3 <= 1'b1; // Lengths differ (3 vs 2)
                        end
                        // Check reachability from i+3 (len 3)
                        if (reach3_reg[idx+3] && (idx + 3 >= 5)) begin
                            // Compare current 3-char with next 3-char at idx+3
                            if (cmp3_success) temp_reach3 <= 1'b1;
                        end
                        
                        // Store suffix if reachable
                        // Priority: 2-char suffix
                        if (temp_reach2) begin
                            suffix_val <= {16'b0, char2, char1}; // Packed: char2[7:0], char1[7:0], 16'b0
                            suffix_len <= 2'b01;
                            match_found <= 1'b1;
                        end else if (temp_reach3) begin
                            suffix_val <= {8'b0, char3, char2, char1}; // Packed: char3[7:0], char2[7:0], char1[7:0], 8'b0
                            suffix_len <= 2'b10;
                            match_found <= 1'b1;
                        end else begin
                            match_found <= 1'b0;
                        end
                        
                        // Decrement index for next cycle
                        idx <= idx - 5'd1;
                        
                    end else begin
                        match_found <= 1'b0;
                        // Not in valid range or finished
                    end
                    
                    // Update DP arrays (must be non-blocking or handled carefully)
                    // In this structure, we update reach arrays in previous cycle logic
                    // But we need to store the result of 'idx' calculation.
                    // Since idx decrements, we need to shift storage.
                    // Easier: Store results in a buffer, or update reach array directly.
                    // Updating reach array directly at 'idx' is tricky because idx changes.
                    // We need to latch the result for the current 'idx'.
                    // Let's use a dedicated write back cycle or store in temp regs.
                    
                    // Since we are iterating idx downwards, we can write to reach arrays
                    // using the 'next_idx' logic.
                    // But we need to handle the write operation.
                    // Let's add a pipeline stage or use combinational output for reach update.
                    // Since idx decrements every cycle, we can just write to the current idx
                    // if it was valid.
                    // Wait, 'idx' is the CURRENT index being evaluated.
                    // We compute reachability for 'idx'.
                    // We store 'temp_reach2' and 'temp_reach3' for 'idx'.
                    // We need to write these back to reach2_reg[idx] and reach3_reg[idx].
                    // Since idx changes, we need to write to the OLD idx (before decrement).
                    // Or better: use a shifted write.
                    // Actually, let's just write to the array in a combinational always block
                    // or use the register array directly.
                    
                    // The logic above sets temp_reach. We need to commit it.
                    // But the 'idx' pointer moves. 
                    // We will handle the update in the next clock edge logic if we were sequential,
                    // but here we are calculating for 'idx'.
                    // Let's make reach2/3_reg update based on the calculation.
                    // Since idx is current, we write to reach2_reg[idx] <= temp_reach2.
                    // But only if idx is valid.
                    if (idx >= 5'd5 && idx < s_len) begin
                        reach2_reg[idx] <= temp_reach2;
                        reach3_reg[idx] <= temp_reach3;
                    end
                    
                    // Deduplication logic (Result accumulation)
                    if (match_found) begin
                        // Check if already in stored_suffixes
                        reg found_dup;
                        found_dup = 1'b0;
                        for (integer i = 0; i < 16; i = i + 1) begin
                            if (i < stored_count && stored_suffixes[i] == suffix_val) begin
                                found_dup = 1'b1;
                            end
                        end
                        if (!found_dup && stored_count < 16) begin
                            stored_suffixes[stored_count] <= suffix_val;
                            stored_lens[stored_count] <= suffix_len;
                            stored_count <= stored_count + 5'd1;
                        end
                    end
                end
                
                FINISH: begin
                    // Copy internal storage to output ports
                    result_count <= stored_count;
                    for (integer j = 0; j < 16; j = j + 1) begin
                        result_suffixes[j] <= stored_suffixes[j];
                        result_len[j] <= stored_lens[j];
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule