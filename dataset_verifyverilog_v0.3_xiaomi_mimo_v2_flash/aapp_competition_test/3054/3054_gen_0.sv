module HaikuFormer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] text_data [0:199],
    input wire [7:0] text_length,
    output reg [7:0] line1 [0:79],
    output reg [7:0] line2 [0:79],
    output reg [7:0] line3 [0:79],
    output reg valid,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_WORDS = 4'd10;
    localparam [4:0] MAX_WORD_LEN = 5'd20;
    localparam [2:0] SYLLABLE_WIDTH = 3'd4;

    // State machine states
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_PARSE = 3'd1;
    localparam [2:0] STATE_COUNT = 3'd2;
    localparam [2:0] STATE_SPLIT = 3'd3;
    localparam [2:0] STATE_FORMAT = 3'd4;
    localparam [2:0] STATE_OUTPUT = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Word storage
    reg [7:0] words [0:9][0:19];
    reg [4:0] word_lengths [0:9];
    reg [3:0] syllable_counts [0:9];
    reg [3:0] num_words;

    // Split indices
    reg [3:0] split1_end;
    reg [3:0] split2_end;

    // Counters
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] char_idx;
    reg [3:0] word_idx;
    reg [4:0] char_pos;

    // Syllable counting
    reg [3:0] vowel_run_count;
    reg [3:0] syllable_acc;

    // Temporary line storage
    reg [7:0] temp_line1 [0:79];
    reg [7:0] temp_line2 [0:79];
    reg [7:0] temp_line3 [0:79];
    reg [6:0] temp_idx;
    reg [6:0] copy_idx;

    // Helper function: is vowel
    function automatic is_vowel_char(input [7:0] c);
        begin
            case (c)
                8'h41, 8'h61, // A, a
                8'h45, 8'h65, // E, e
                8'h49, 8'h69, // I, i
                8'h4F, 8'h6F, // O, o
                8'h55, 8'h75, // U, u
                8'h59, 8'h79: // Y, y
                    is_vowel_char = 1'b1;
                default:
                    is_vowel_char = 1'b0;
            endcase
        end
    endfunction

    // Helper function: is QU pair
    function automatic is_qu_pair(input [7:0] c1, input [7:0] c2);
        begin
            is_qu_pair = ((c1 == 8'h51 || c1 == 8'h71) && 
                         (c2 == 8'h55 || c2 == 8'h75));
        end
    endfunction

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            num_words <= 4'd0;
            char_idx <= 8'd0;
            word_idx <= 4'd0;
            split1_end <= 4'd0;
            split2_end <= 4'd0;
            char_pos <= 5'd0;
            vowel_run_count <= 4'd0;
            syllable_acc <= 4'd0;
            temp_idx <= 7'd0;
            copy_idx <= 7'd0;
            for (i = 0; i < 10; i = i + 1) begin
                word_lengths[i] <= 5'd0;
                syllable_counts[i] <= 4'd0;
                for (j = 0; j < 20; j = j + 1) begin
                    words[i][j] <= 8'd0;
                end
            end
            for (i = 0; i < 80; i = i + 1) begin
                line1[i] <= 8'd0;
                line2[i] <= 8'd0;
                line3[i] <= 8'd0;
                temp_line1[i] <= 8'd0;
                temp_line2[i] <= 8'd0;
                temp_line3[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (start && text_length > 8'd0)
                    next_state = STATE_PARSE;
            end
            
            STATE_PARSE: begin
                if (char_idx >= text_length || num_words >= MAX_WORDS)
                    next_state = STATE_COUNT;
            end
            
            STATE_COUNT: begin
                if (word_idx >= num_words)
                    next_state = STATE_SPLIT;
            end
            
            STATE_SPLIT: begin
                if (valid || (split1_end >= num_words && split2_end >= num_words))
                    next_state = STATE_FORMAT;
            end
            
            STATE_FORMAT: begin
                next_state = STATE_OUTPUT;
            end
            
            STATE_OUTPUT: begin
                next_state = STATE_IDLE;
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end

    // Main processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            case (state)
                STATE_PARSE: begin
                    if (char_idx < text_length && num_words < MAX_WORDS) begin
                        // Get current character
                        if (char_idx < text_length) begin
                            reg [7:0] current_char;
                            current_char = text_data[char_idx];
                            
                            // Check if alphabetic
                            if ((current_char >= 8'h41 && current_char <= 8'h5A) || 
                                (current_char >= 8'h61 && current_char <= 8'h7A)) begin
                                if (word_lengths[num_words] < MAX_WORD_LEN) begin
                                    words[num_words][word_lengths[num_words]] <= current_char;
                                    word_lengths[num_words] <= word_lengths[num_words] + 5'd1;
                                end
                            end else if (current_char == 8'h20 && word_lengths[num_words] > 0) begin
                                num_words <= num_words + 4'd1;
                            end else if (word_lengths[num_words] > 0) begin
                                words[num_words][word_lengths[num_words]] <= current_char;
                                word_lengths[num_words] <= word_lengths[num_words] + 5'd1;
                            end
                        end
                        char_idx <= char_idx + 8'd1;
                    end
                end
                
                STATE_COUNT: begin
                    if (word_idx < num_words) begin
                        if (char_pos == 5'd0 && syllable_acc == 4'd0) begin
                            vowel_run_count <= 4'd0;
                            syllable_acc <= 4'd0;
                        end
                        
                        if (char_pos < word_lengths[word_idx]) begin
                            reg [7:0] char;
                            reg [7:0] prev_char;
                            reg [7:0] next_char;
                            reg is_vowel;
                            reg is_next_vowel;
                            
                            char = words[word_idx][char_pos];
                            prev_char = (char_pos > 0) ? words[word_idx][char_pos-1] : 8'd0;
                            next_char = (char_pos < word_lengths[word_idx]-1) ? words[word_idx][char_pos+1] : 8'd0;
                            
                            is_vowel = is_vowel_char(char);
                            is_next_vowel = is_vowel_char(next_char);
                            
                            // QU rule
                            if (is_qu_pair(char, next_char)) begin
                                is_vowel = 1'b0;
                            end
                            
                            // Y rule
                            if ((char == 8'h59 || char == 8'h79) && is_next_vowel) begin
                                is_vowel = 1'b0;
                            end
                            
                            if (is_vowel) begin
                                if (vowel_run_count == 4'd0) begin
                                    syllable_acc <= syllable_acc + 4'd1;
                                end
                                vowel_run_count <= vowel_run_count + 4'd1;
                            end else begin
                                vowel_run_count <= 4'd0;
                            end
                            
                            char_pos <= char_pos + 5'd1;
                        end else begin
                            // End of word
                            if (word_lengths[word_idx] >= 5'd2) begin
                                reg [7:0] end_char = words[word_idx][word_lengths[word_idx]-1];
                                reg [7:0] prev_end_char = words[word_idx][word_lengths[word_idx]-2];
                                
                                // Silent E rule
                                if (end_char == 8'h45 || end_char == 8'h65) begin
                                    if (word_lengths[word_idx] >= 5'd3) begin
                                        reg [7:0] prev_prev_char = words[word_idx][word_lengths[word_idx]-3];
                                        // Check LE pattern
                                        if ((prev_end_char == 8'h4C || prev_end_char == 8'h6C) && 
                                            !is_vowel_char(prev_prev_char)) begin
                                            // Keep syllable
                                        end else begin
                                            if (syllable_acc > 4'd0)
                                                syllable_acc <= syllable_acc - 4'd1;
                                        end
                                    end else begin
                                        if (syllable_acc > 4'd0)
                                            syllable_acc <= syllable_acc - 4'd1;
                                    end
                                end
                                
                                // ES rule
                                if (word_lengths[word_idx] >= 5'd2) begin
                                    if ((end_char == 8'h53 || end_char == 8'h73) && 
                                        (prev_end_char == 8'h45 || prev_end_char == 8'h65)) begin
                                        reg [2:0] cons_count = 3'd0;
                                        for (k = 0; k < word_lengths[word_idx]-5'd2; k = k + 1) begin
                                            reg [7:0] c = words[word_idx][k];
                                            if (!is_vowel_char(c)) 
                                                cons_count = cons_count + 3'd1;
                                        end
                                        if (cons_count < 3'd2 && syllable_acc > 4'd0)
                                            syllable_acc <= syllable_acc - 4'd1;
                                    end
                                end
                            end
                            
                            if (syllable_acc == 4'd0)
                                syllable_acc <= 4'd1;
                            
                            syllable_counts[word_idx] <= syllable_acc;
                            char_pos <= 5'd0;
                            syllable_acc <= 4'd0;
                            word_idx <= word_idx + 4'd1;
                        end
                    end
                end
                
                STATE_SPLIT: begin
                    if (split1_end < num_words) begin
                        reg [4:0] syl_5 = 5'd0;
                        for (i = 0; i <= split1_end; i = i + 1) begin
                            syl_5 = syl_5 + syllable_counts[i];
                        end
                        
                        if (syl_5 == 5'd5) begin
                            if (split2_end < num_words && split2_end > split1_end) begin
                                reg [4:0] syl_7 = 5'd0;
                                for (j = split1_end + 4'd1; j <= split2_end; j = j + 1) begin
                                    syl_7 = syl_7 + syllable_counts[j];
                                end
                                
                                if (syl_7 == 5'd7) begin
                                    reg [4:0] syl_5_2 = 5'd0;
                                    for (k = split2_end + 4'd1; k < num_words; k = k + 1) begin
                                        syl_5_2 = syl_5_2 + syllable_counts[k];
                                    end
                                    
                                    if (syl_5_2 == 5'd5) begin
                                        valid <= 1'b1;
                                    end
                                end
                            end
                            split2_end <= split2_end + 4'd1;
                        end
                        split1_end <= split1_end + 4'd1;
                    end
                end
                
                STATE_FORMAT: begin
                    temp_idx <= 7'd0;
                    if (valid) begin
                        // Line 1
                        for (i = 0; i <= split1_end; i = i + 1) begin
                            for (j = 0; j < word_lengths[i]; j = j + 1) begin
                                temp_line1[temp_idx] <= words[i][j];
                                temp_idx <= temp_idx + 7'd1;
                            end
                            if (i < split1_end) begin
                                temp_line1[temp_idx] <= 8'h20;
                                temp_idx <= temp_idx + 7'd1;
                            end
                        end
                        // Line 2
                        temp_idx <= 7'd0;
                        for (i = split1_end + 4'd1; i <= split2_end; i = i + 1) begin
                            for (j = 0; j < word_lengths[i]; j = j + 1) begin
                                temp_line2[temp_idx] <= words[i][j];
                                temp_idx <= temp_idx + 7'd1;
                            end
                            if (i < split2_end) begin
                                temp_line2[temp_idx] <= 8'h20;
                                temp_idx <= temp_idx + 7'd1;
                            end
                        end
                        // Line 3
                        temp_idx <= 7'd0;
                        for (i = split2_end + 4'd1; i < num_words; i = i + 1) begin
                            for (j = 0; j < word_lengths[i]; j = j + 1) begin
                                temp_line3[temp_idx] <= words[i][j];
                                temp_idx <= temp_idx + 7'd1;
                            end
                            if (i < num_words - 4'd1) begin
                                temp_line3[temp_idx] <= 8'h20;
                                temp_idx <= temp_idx + 7'd1;
                            end
                        end
                    end
                end
                
                STATE_OUTPUT: begin
                    if (valid) begin
                        for (copy_idx = 0; copy_idx < 80; copy_idx = copy_idx + 1) begin
                            line1[copy_idx] <= temp_line1[copy_idx];
                            line2[copy_idx] <= temp_line2[copy_idx];
                            line3[copy_idx] <= temp_line3[copy_idx];
                        end
                    end else begin
                        temp_idx <= 7'd0;
                        for (i = 0; i < num_words; i = i + 1) begin
                            for (j = 0; j < word_lengths[i]; j = j + 1) begin
                                line1[temp_idx] <= words[i][j];
                                temp_idx <= temp_idx + 7'd1;
                            end
                            if (i < num_words - 4'd1) begin
                                line1[temp_idx] <= 8'h20;
                                temp_idx <= temp_idx + 7'd1;
                            end
                        end
                        for (copy_idx = temp_idx; copy_idx < 80; copy_idx = copy_idx + 1) begin
                            line1[copy_idx] <= 8'd0;
                        end
                        for (copy_idx = 0; copy_idx < 80; copy_idx = copy_idx + 1) begin
                            line2[copy_idx] <= 8'd0;
                            line3[copy_idx] <= 8'd0;
                        end
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Use k in STATE_COUNT
    wire [3:0] k;
    assign k = split2_end;

endmodule