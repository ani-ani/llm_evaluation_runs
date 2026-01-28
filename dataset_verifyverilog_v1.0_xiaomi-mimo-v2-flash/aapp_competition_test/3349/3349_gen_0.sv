module SentenceReconstructor (
    input clk,
    input rst_n,
    input start,
    input [5:0] msg_len,
    input [3:0] word_count,
    input [7:0] msg_char [0:63],
    input [7:0] dict_word_char [0:15][0:15],
    input [3:0] dict_word_len [0:15],
    input [5:0] dict_word_vowels [0:15],
    output reg [3:0] result_word_idx [0:15],
    output reg [3:0] result_len,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_INPUT  = 3'd1;
    localparam [2:0] SEARCH_START = 3'd2;
    localparam [2:0] SEARCH_LOOP  = 3'd3;
    localparam [2:0] BACKTRACK    = 3'd4;
    localparam [2:0] UPDATE_BEST  = 3'd5;
    localparam [2:0] FINISH       = 3'd6;

    // Registers for state machine
    reg [2:0] state;
    reg [2:0] next_state;
    reg [11:0] cycle_count; // Counter to enforce 2048 cycle limit
    localparam [11:0] MAX_CYCLES = 12'd2048;

    // Data Registers
    reg [5:0] pos; // Current position in message (0 to msg_len)
    reg [3:0] stack_idx; // Current word count in stack
    reg [3:0] stack [0:15]; // Stack of word indices used
    reg [3:0] word_ptr; // Pointer to current word in dictionary being checked
    
    // Best Solution Registers
    reg [3:0] best_stack [0:15];
    reg [3:0] best_len;
    reg [5:0] best_vowel_sum;
    reg solution_found;
    
    // Temporary calculation registers
    reg [5:0] current_vowel_sum;
    reg match_found;
    reg [3:0] char_idx;
    reg [3:0] dict_char_idx;
    reg [7:0] msg_char_val;
    reg [7:0] dict_char_val;
    reg [3:0] current_word_len;
    
    // Loop counters
    integer i;

    // Combinational Logic for Next State
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CHECK_INPUT : IDLE;
            
            CHECK_INPUT: begin
                if (msg_len == 6'd0 || word_count == 4'd0)
                    next_state = FINISH;
                else
                    next_state = SEARCH_START;
            end
            
            SEARCH_START: next_state = SEARCH_LOOP;
            
            SEARCH_LOOP: begin
                if (cycle_count >= MAX_CYCLES)
                    next_state = FINISH;
                else if (stack_idx > 0 && pos > msg_len)
                    next_state = BACKTRACK;
                else if (stack_idx > 0 && pos == msg_len)
                    next_state = UPDATE_BEST;
                else if (word_ptr < word_count)
                    next_state = SEARCH_LOOP; // Keep checking words
                else if (stack_idx > 0)
                    next_state = BACKTRACK;
                else
                    next_state = FINISH;
            end
            
            BACKTRACK: next_state = SEARCH_LOOP;
            
            UPDATE_BEST: next_state = BACKTRACK;
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result_len <= 4'd0;
            cycle_count <= 12'd0;
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                result_word_idx[i] <= 4'd0;
                best_stack[i] <= 4'd0;
                stack[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 12'd0;
                end
                
                CHECK_INPUT: begin
                    // Initialization for search
                    pos <= 6'd0;
                    stack_idx <= 4'd0;
                    word_ptr <= 4'd0;
                    current_vowel_sum <= 6'd0;
                    solution_found <= 1'b0;
                    best_len <= 4'd0;
                    best_vowel_sum <= 6'd0;
                end
                
                SEARCH_START: begin
                    word_ptr <= 4'd0;
                end
                
                SEARCH_LOOP: begin
                    if (cycle_count < MAX_CYCLES) begin
                        cycle_count <= cycle_count + 12'd1;
                    end

                    // Check word logic: Only if within bounds and not backtracking
                    if (word_ptr < word_count) begin
                        current_word_len <= dict_word_len[word_ptr];
                        
                        // Perform comparison check
                        if (match_found) begin
                            // Match found, push to stack
                            if (stack_idx < 16) begin
                                stack[stack_idx] <= word_ptr;
                                stack_idx <= stack_idx + 4'd1;
                                pos <= pos + {2'd0, dict_word_len[word_ptr]}; // pos = pos + word_len
                                current_vowel_sum <= current_vowel_sum + dict_word_vowels[word_ptr];
                            end
                            word_ptr <= 4'd0; // Reset word pointer for next search at new pos
                        end else begin
                            // No match, check next word
                            word_ptr <= word_ptr + 4'd1;
                        end
                    end else begin
                        // Exhausted words at this position (or invalid match)
                        // If stack_idx is 0 and no words matched, we are done
                        if (stack_idx == 4'd0) begin
                            // No solution found at start
                            // Go to finish if no solution yet, or backtracking logic will handle
                            // Handled by state transition logic
                        end
                    end
                end
                
                BACKTRACK: begin
                    if (stack_idx > 4'd0) begin
                        stack_idx <= stack_idx - 4'd1;
                        current_word_len <= dict_word_len[stack[stack_idx - 4'd1]];
                        pos <= pos - {2'd0, dict_word_len[stack[stack_idx - 4'd1]]};
                        current_vowel_sum <= current_vowel_sum - dict_word_vowels[stack[stack_idx - 4'd1]];
                        word_ptr <= stack[stack_idx - 4'd1] + 4'd1; // Try next word after the one we popped
                    end else begin
                        word_ptr <= 4'd0; // Should already be handled
                    end
                end
                
                UPDATE_BEST: begin
                    if (stack_idx > 0) begin
                        if (!solution_found || (current_vowel_sum > best_vowel_sum)) begin
                            best_vowel_sum <= current_vowel_sum;
                            best_len <= stack_idx;
                            solution_found <= 1'b1;
                            // Copy stack to best_stack
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < stack_idx)
                                    best_stack[i] <= stack[i];
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (solution_found) begin
                        valid <= 1'b1;
                        result_len <= best_len;
                        // Copy best stack to output
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < best_len)
                                result_word_idx[i] <= best_stack[i];
                            else
                                result_word_idx[i] <= 4'd0;
                        end
                    end else begin
                        valid <= 1'b0;
                        result_len <= 4'd0;
                    end
                end
            endcase
        end
    end

    // Combinational matching logic (optimised for single cycle check)
    always @(*) begin
        match_found = 1'b0;
        if (word_ptr < word_count && (pos + dict_word_len[word_ptr]) <= msg_len) begin
            // Check if characters match
            match_found = 1'b1;
            for (char_idx = 0; char_idx < 16; char_idx = char_idx + 1) begin
                if (char_idx < dict_word_len[word_ptr]) begin
                    msg_char_val = msg_char[pos + char_idx];
                    dict_char_val = dict_word_char[word_ptr][char_idx];
                    if (msg_char_val != dict_char_val) begin
                        match_found = 1'b0;
                    end
                end
            end
        end
    end

endmodule