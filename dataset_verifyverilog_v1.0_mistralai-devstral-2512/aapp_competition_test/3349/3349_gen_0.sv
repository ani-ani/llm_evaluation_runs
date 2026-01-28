module SentenceReconstructor(
    input clk,
    input rst_n,
    input start,
    input [5:0] msg_len,
    input [3:0] word_count,
    input [7:0] msg_char [0:63],
    input [7:0] dict_word [0:15][0:15],
    input [3:0] dict_word_len [0:15],
    input [5:0] dict_word_vowels [0:15],
    output reg [3:0] result_word_idx [0:15],
    output reg [3:0] result_len,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd2048;

    // Internal registers for processing
    reg [5:0] current_msg_pos;
    reg [3:0] current_word_idx;
    reg [3:0] solution_len;
    reg [3:0] solution_word_idx [0:15];
    reg [15:0] max_vowel_sum;
    reg [15:0] current_vowel_sum;

    // Helper function to check if a word matches the message starting at pos
    function [7:0] check_word_match;
        input [3:0] word_idx;
        input [5:0] start_pos;
        reg [5:0] i;
        reg [5:0] msg_pos;
        reg [3:0] word_len;
        reg match;
        
        word_len = dict_word_len[word_idx];
        match = 1'b1;
        
        for (i = 0; i < word_len; i = i + 1) begin
            msg_pos = start_pos + i;
            if (msg_pos >= msg_len) begin
                match = 1'b0;
            end else begin
                // Check if character is a consonant (not a vowel)
                if (dict_word[word_idx][i] == 8'd65 || // A
                    dict_word[word_idx][i] == 8'd69 || // E
                    dict_word[word_idx][i] == 8'd73 || // I
                    dict_word[word_idx][i] == 8'd79 || // O
                    dict_word[word_idx][i] == 8'd85)   // U
                begin
                    match = 1'b0;
                end else if (dict_word[word_idx][i] != msg_char[msg_pos]) begin
                    match = 1'b0;
                end
            end
        end
        
        if (match && (start_pos + word_len) == msg_len) begin
            check_word_match = 8'd1;
        end else if (match) begin
            check_word_match = 8'd2;
        end else begin
            check_word_match = 8'd0;
        end
    endfunction

    // Main processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 10'd0;
            current_msg_pos <= 6'd0;
            current_word_idx <= 4'd0;
            solution_len <= 4'd0;
            max_vowel_sum <= 16'd0;
            current_vowel_sum <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            result_len <= 4'd0;
            
            // Initialize result_word_idx array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result_word_idx[i] <= 4'd0;
                solution_word_idx[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 10'd0;
                    current_msg_pos <= 6'd0;
                    current_word_idx <= 4'd0;
                    solution_len <= 4'd0;
                    max_vowel_sum <= 16'd0;
                    current_vowel_sum <= 16'd0;
                    
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Check if we've exceeded max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Try to match words at current position
                        reg [7:0] match_result;
                        reg [3:0] i;
                        reg found_match;
                        
                        found_match = 1'b0;
                        
                        for (i = 0; i < word_count; i = i + 1) begin
                            match_result = check_word_match(i, current_msg_pos);
                            
                            if (match_result == 8'd1) begin
                                // Complete match found
                                current_vowel_sum = current_vowel_sum + dict_word_vowels[i];
                                
                                if (current_vowel_sum > max_vowel_sum) begin
                                    max_vowel_sum = current_vowel_sum;
                                    solution_len = current_word_idx + 1'b1;
                                    solution_word_idx[current_word_idx] = i;
                                    valid = 1'b1;
                                end
                                
                                found_match = 1'b1;
                            end else if (match_result == 8'd2) begin
                                // Partial match found, continue searching
                                solution_word_idx[current_word_idx] = i;
                                current_word_idx = current_word_idx + 1'b1;
                                current_msg_pos = current_msg_pos + dict_word_len[i];
                                current_vowel_sum = current_vowel_sum + dict_word_vowels[i];
                                found_match = 1'b1;
                                break;
                            end
                        end
                        
                        if (!found_match) begin
                            // Backtrack
                            if (current_word_idx > 0) begin
                                current_word_idx = current_word_idx - 1'b1;
                                current_msg_pos = current_msg_pos - dict_word_len[solution_word_idx[current_word_idx]];
                                current_vowel_sum = current_vowel_sum - dict_word_vowels[solution_word_idx[current_word_idx]];
                            end else begin
                                // No more words to try, finish
                                state <= FINISH;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result_len <= solution_len;
                    
                    // Copy solution to output
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < solution_len) begin
                            result_word_idx[i] <= solution_word_idx[i];
                        end else begin
                            result_word_idx[i] <= 4'd0;
                        end
                    end
                    
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule