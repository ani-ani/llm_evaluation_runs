module find_max_occurrences(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] s [0:15],
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] FETCH    = 3'd1;
localparam [2:0] COMPUTE  = 3'd2;
localparam [2:0] UPDATE   = 3'd3;
localparam [2:0] FINALIZE = 3'd4;
localparam [2:0] DONE_ST  = 3'd5;

// Registers
reg [2:0] state, next_state;
reg [15:0] freq_reg [0:25];  // Frequency counts for each letter
reg [15:0] pair_reg [0:25][0:25];  // Pair counts: 26 x 26
reg [15:0] global_max;
reg [15:0] char_max;
reg [15:0] pair_max;

// Control registers
reg [3:0] char_idx;        // Index through input string (0-15)
reg [4:0] prev_char;       // Previous character (0-25)
reg [4:0] curr_char;       // Current character (0-25)
reg [4:0] letter_a;        // Loop counter for letter 'a' (0-25)
reg [4:0] letter_b;        // Loop counter for letter 'b' (0-25)
reg [7:0] current_char_val; // Current ASCII value
reg [4:0] char_code;       // Converted character code (0-25)
reg [15:0] temp_sum;       // Temporary sum for pair update
reg [15:0] temp_count;     // Temporary count for single update

// Loop control for 16x16 inner operations
reg [3:0] inner_idx;       // 0-15
reg [3:0] outer_idx;       // 0-15

// Initialize all registers function
function reg [2:0] init_all;
    integer i, j;
    begin
        // Initialize frequency array
        for (i = 0; i < 26; i = i + 1) begin
            freq_reg[i] <= 16'd0;
        end
        // Initialize pair array
        for (i = 0; i < 26; i = i + 1) begin
            for (j = 0; j < 26; j = j + 1) begin
                pair_reg[i][j] <= 16'd0;
            end
        end
        // Initialize other registers
        global_max <= 16'd0;
        char_max <= 16'd0;
        pair_max <= 16'd0;
        char_idx <= 4'd0;
        prev_char <= 5'd0;
        curr_char <= 5'd0;
        letter_a <= 5'd0;
        letter_b <= 5'd0;
        current_char_val <= 8'd0;
        char_code <= 5'd0;
        inner_idx <= 4'd0;
        outer_idx <= 4'd0;
        temp_sum <= 16'd0;
        temp_count <= 16'd0;
        result <= 16'd0;
        done <= 1'b0;
    end
endfunction

// State transition and reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        // Initialize all registers
        integer i, j;
        for (i = 0; i < 26; i = i + 1) begin
            freq_reg[i] <= 16'd0;
        end
        for (i = 0; i < 26; i = i + 1) begin
            for (j = 0; j < 26; j = j + 1) begin
                pair_reg[i][j] <= 16'd0;
            end
        end
        global_max <= 16'd0;
        char_max <= 16'd0;
        pair_max <= 16'd0;
        char_idx <= 4'd0;
        prev_char <= 5'd0;
        curr_char <= 5'd0;
        letter_a <= 5'd0;
        letter_b <= 5'd0;
        current_char_val <= 8'd0;
        char_code <= 5'd0;
        inner_idx <= 4'd0;
        outer_idx <= 4'd0;
        temp_sum <= 16'd0;
        temp_count <= 16'd0;
        result <= 16'd0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Reset all counters for new operation
                    integer i, j;
                    for (i = 0; i < 26; i = i + 1) begin
                        freq_reg[i] <= 16'd0;
                    end
                    for (i = 0; i < 26; i = i + 1) begin
                        for (j = 0; j < 26; j = j + 1) begin
                            pair_reg[i][j] <= 16'd0;
                        end
                    end
                    global_max <= 16'd0;
                    char_max <= 16'd0;
                    pair_max <= 16'd0;
                    char_idx <= 4'd0;
                    prev_char <= 5'd0;
                    curr_char <= 5'd0;
                    letter_a <= 5'd0;
                    letter_b <= 5'd0;
                    current_char_val <= 8'd0;
                    char_code <= 5'd0;
                    inner_idx <= 4'd0;
                    outer_idx <= 4'd0;
                    temp_sum <= 16'd0;
                    temp_count <= 16'd0;
                    result <= 16'd0;
                end
            end
            
            FETCH: begin
                // Read current character
                if (char_idx < len) begin
                    current_char_val <= s[char_idx];
                    // Convert ASCII to 0-25 (assuming 'a'=97)
                    if (s[char_idx] >= 97 && s[char_idx] <= 122) begin
                        char_code <= s[char_idx] - 8'd97;
                    end else begin
                        char_code <= 5'd26; // Invalid marker
                    end
                end
            end
            
            COMPUTE: begin
                // Update pair counts for all previous letters
                // pair[letter_a][char_code] += freq_reg[letter_a]
                if (char_code < 26 && letter_a < 26 && letter_a < char_idx) begin
                    temp_sum <= pair_reg[letter_a][char_code] + freq_reg[letter_a];
                end
                // Update char_max for single character
                if (letter_a < 26 && letter_a == char_code) begin
                    temp_count <= freq_reg[char_code] + 16'd1;
                end
            end
            
            UPDATE: begin
                // Update pair counts in register array
                if (char_code < 26 && letter_a < 26 && letter_a < char_idx) begin
                    pair_reg[letter_a][char_code] <= temp_sum;
                    // Update pair_max
                    if (temp_sum > pair_max) begin
                        pair_max <= temp_sum;
                    end
                end
                // Update single character frequency
                if (char_code < 26 && letter_a < 26 && letter_a == char_code) begin
                    freq_reg[char_code] <= temp_count;
                    // Update char_max
                    if (temp_count > char_max) begin
                        char_max <= temp_count;
                    end
                end
            end
            
            FINALIZE: begin
                // Compare char_max and pair_max for final global_max
                if (pair_max > char_max) begin
                    global_max <= pair_max;
                end else begin
                    global_max <= char_max;
                end
            end
            
            DONE_ST: begin
                result <= global_max;
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start && len > 0 && len <= 16) begin
                next_state = FETCH;
            end else begin
                next_state = IDLE;
            end
        end
        
        FETCH: begin
            if (char_idx < len) begin
                if (char_code < 26) begin
                    // Character is valid, go to compute for pair updates
                    next_state = COMPUTE;
                end else begin
                    // Invalid character, skip to next
                    if (char_idx + 1 < len) begin
                        next_state = FETCH;
                    end else begin
                        next_state = FINALIZE;
                    end
                end
            end else begin
                next_state = FINALIZE;
            end
        end
        
        COMPUTE: begin
            // Always go to update
            next_state = UPDATE;
        end
        
        UPDATE: begin
            // Continue with all 26 letters, or move to next char
            if (letter_a < 25'd25) begin
                next_state = COMPUTE; // Continue loop for next letter_a
            end else begin
                // Done with current character
                if (char_idx + 1 < len) begin
                    next_state = FETCH; // Go to next character
                end else begin
                    next_state = FINALIZE; // All characters processed
                end
            end
        end
        
        FINALIZE: begin
            next_state = DONE_ST;
        end
        
        DONE_ST: begin
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

// Control signal updates
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        char_idx <= 4'd0;
        letter_a <= 5'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    char_idx <= 4'd0;
                    letter_a <= 5'd0;
                end
            end
            
            FETCH: begin
                // Keep current char_idx and letter_a
            end
            
            COMPUTE: begin
                // Increment letter_a for loop
                letter_a <= letter_a + 5'd1;
            end
            
            UPDATE: begin
                // letter_a was incremented in COMPUTE
                // After UPDATE, check if we need to reset for next char
                if (letter_a >= 5'd25) begin
                    letter_a <= 5'd0; // Reset for next character
                    if (char_code < 26) begin
                        // Only increment char_idx for valid characters
                        char_idx <= char_idx + 4'd1;
                    end else begin
                        // Skip invalid characters
                        char_idx <= char_idx + 4'd1;
                    end
                end
            end
            
            FINALIZE, DONE_ST: begin
                // Keep values
            end
        endcase
    end
end

endmodule