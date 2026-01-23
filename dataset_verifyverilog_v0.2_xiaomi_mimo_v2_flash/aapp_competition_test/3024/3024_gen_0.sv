module palindrome_partition (
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] str_data,
    input [3:0] str_len,
    output reg [3:0] max_k,
    output reg done
);

    // Parameters
    parameter MAX_LEN = 8;
    parameter MAX_K = 8;

    // States
    localparam IDLE = 3'b001;
    localparam CHECK_MATCH = 3'b010;
    localparam UPDATE_POINTERS = 3'b100;
    localparam DONE_STATE = 3'b000; // Encoded differently to avoid overlap if needed, but safe here
    // Actually, let's use explicit states for synthesis clarity
    localparam S_IDLE = 2'b00;
    localparam S_CHECK = 2'b01;
    localparam S_UPDATE = 2'b10;
    localparam S_DONE = 2'b11;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] left_idx, next_left_idx;
    reg [3:0] right_idx, next_right_idx;
    reg [3:0] k, next_k;
    reg [3:0] i, next_i; // Current length being checked
    reg [3:0] j, next_j; // Character index for comparison
    
    // Internal match signal
    reg match_found;
    reg [3:0] current_len;

    // Combinational logic for matching
    always @(*) begin
        match_found = 1'b0;
        
        // Check if i is within bounds of current substring
        if (i > 0 && i <= (right_idx - left_idx + 1)) begin
            // Check if s[left_idx : left_idx + i - 1] == s[right_idx - i + 1 : right_idx]
            // We are at cycle (j+1) checking character at index j (0 to i-1)
            // Input str_data is packed [7:0][7:0]. str_data[0] is first char.
            // Indices in spec: left_idx 0-based.
            
            if (str_data[left_idx + j] == str_data[right_idx - i + 1 + j]) begin
                if (j == i - 1) begin
                    match_found = 1'b1;
                end
            end
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        next_left_idx = left_idx;
        next_right_idx = right_idx;
        next_k = k;
        next_i = i;
        next_j = j;
        
        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state = S_CHECK;
                    next_left_idx = 0;
                    next_right_idx = str_len - 1;
                    next_k = 0;
                    next_i = 1; // Start with length 1
                    next_j = 0;
                end
            end

            S_CHECK: begin
                // We iterate through possible lengths i from 1 to current substring length
                // For each i, we iterate j from 0 to i-1 to compare characters
                
                if (j < i - 1) begin
                    // Continue comparing characters for current i
                    next_j = j + 1;
                end else if (j == i - 1) begin
                    // Done comparing for current i
                    if (match_found) begin
                        // Found smallest match, go update
                        next_state = S_UPDATE;
                    end else begin
                        // Try next i
                        if (i < (right_idx - left_idx + 1)) begin
                            next_i = i + 1;
                            next_j = 0;
                        end else begin
                            // No match found (should not happen for valid palindromes unless error)
                            // In this greedy spec, we assume a match is always found for the whole string
                            // If we reach here without match, it means the whole substring is the only option
                            // But the loop logic above covers i up to length. 
                            // If i == length and no match (j loop finished without match in middle?), 
                            // actually match_found checks at end. If we exit j loop without match_found true.
                            // Wait, my match_found logic sets it true only if final char matches and j==i-1.
                            // If logic flows here, it means we finished loop and match_found wasn't set.
                            // This implies we exhausted all i without finding a match.
                            // Spec says "find smallest i ... where ... equals". 
                            // If the string is a palindrome, i=len will match.
                            // If not a palindrome partitionable, we might fail. 
                            // Let's assume we take the full length if no smaller match found.
                            // The condition `if (match_found)` handles finding it. 
                            // If we fall through all i's without triggering `if (match_found)`,
                            // we need to force a match (the full string) or handle error.
                            // Let's force update if i reaches length.
                            if (i == (right_idx - left_idx + 1)) begin
                                next_state = S_UPDATE;
                            end else begin
                                // Should not reach here based on logic, but safety
                                next_i = i + 1; 
                            end
                        end
                    end
                end
            end

            S_UPDATE: begin
                // Update indices
                next_left_idx = left_idx + i;
                next_right_idx = right_idx - i;
                next_k = k + 1;
                
                // Check termination
                if (next_left_idx > next_right_idx || next_k == MAX_K) begin
                    next_state = S_DONE;
                end else begin
                    // Start next pass
                    next_state = S_CHECK;
                    next_i = 1;
                    next_j = 0;
                end
            end

            S_DONE: begin
                if (~start) begin
                    next_state = S_IDLE;
                end
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            left_idx <= 0;
            right_idx <= 0;
            k <= 0;
            i <= 1;
            j <= 0;
            max_k <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            left_idx <= next_left_idx;
            right_idx <= next_right_idx;
            k <= next_k;
            i <= next_i;
            j <= next_j;
            
            if (state == S_DONE) begin
                done <= 1;
                max_k <= k;
            end else if (state == S_IDLE && start) begin
                done <= 0;
            end
        end
    end

endmodule
