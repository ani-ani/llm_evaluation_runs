module AdverbFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire sentence_end,
    output reg found,
    output reg [7:0] start_pos,
    output reg [7:0] end_pos,
    output reg [127:0] adverb,
    output reg done,
    output reg error
);
    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] WAIT_START = 3'd1;
    localparam [2:0] SEARCH     = 3'd2;
    localparam [2:0] IN_WORD    = 3'd3;
    localparam [2:0] CHECK_END  = 3'd4;
    localparam [2:0] FOUND      = 3'd5;
    localparam [2:0] FINISH     = 3'd6;
    
    reg [2:0] state, next_state;
    reg [7:0] pos_counter;
    reg [7:0] word_start_pos;
    reg [7:0] word_len;
    reg [7:0] ly_count;
    reg [3:0] buffer_idx;
    reg [127:0] temp_adverb;
    reg is_word_start;
    reg in_word;
    reg last_char_was_space;
    reg [7:0] prev_char;
    
    // Helper function to check if character is alphabetic
    function automatic is_alpha(input [7:0] c);
        begin
            is_alpha = ((c >= 8'h41 && c <= 8'h5A) || (c >= 8'h61 && c <= 8'h7A));
        end
    endfunction
    
    // Helper function to check if character is lowercase
    function automatic is_lower(input [7:0] c);
        begin
            is_lower = (c >= 8'h61 && c <= 8'h7A);
        end
    endfunction
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                next_state = WAIT_START;
            end
            WAIT_START: begin
                if (start) begin
                    next_state = SEARCH;
                end else begin
                    next_state = WAIT_START;
                end
            end
            SEARCH: begin
                if (char_valid && !found) begin
                    next_state = IN_WORD;
                end else if (sentence_end) begin
                    next_state = FINISH;
                end else begin
                    next_state = SEARCH;
                end
            end
            IN_WORD: begin
                if (found) begin
                    next_state = FOUND;
                end else if (!is_alpha(char_in)) begin
                    next_state = CHECK_END;
                end else begin
                    next_state = SEARCH;
                end
            end
            CHECK_END: begin
                if (sentence_end) begin
                    next_state = FINISH;
                end else begin
                    next_state = SEARCH;
                end
            end
            FOUND: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = WAIT_START;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 1'b0;
            start_pos <= 8'd0;
            end_pos <= 8'd0;
            adverb <= 128'd0;
            done <= 1'b0;
            error <= 1'b0;
            pos_counter <= 8'd0;
            word_start_pos <= 8'd0;
            word_len <= 8'd0;
            ly_count <= 8'd0;
            buffer_idx <= 4'd0;
            temp_adverb <= 128'd0;
            in_word <= 1'b0;
            last_char_was_space <= 1'b1;
            prev_char <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    found <= 1'b0;
                    start_pos <= 8'd0;
                    end_pos <= 8'd0;
                    adverb <= 128'd0;
                    done <= 1'b0;
                    error <= 1'b0;
                    pos_counter <= 8'd0;
                    word_start_pos <= 8'd0;
                    word_len <= 8'd0;
                    ly_count <= 8'd0;
                    buffer_idx <= 4'd0;
                    temp_adverb <= 128'd0;
                    in_word <= 1'b0;
                    last_char_was_space <= 1'b1;
                    prev_char <= 8'd0;
                end
                
                WAIT_START: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    found <= 1'b0;
                end
                
                SEARCH: begin
                    if (char_valid && !found) begin
                        pos_counter <= pos_counter + 8'd1;
                        prev_char <= char_in;
                        
                        // Check for word start
                        if (!in_word && is_alpha(char_in) && last_char_was_space) begin
                            word_start_pos <= pos_counter;
                            in_word <= 1'b1;
                            word_len <= 8'd1;
                            ly_count <= 8'd0;
                            buffer_idx <= 4'd0;
                            temp_adverb <= 128'd0;
                            // Store first character
                            temp_adverb[127:120] <= char_in;
                        end else if (in_word && is_alpha(char_in)) begin
                            word_len <= word_len + 8'd1;
                            // Store in buffer if within limit
                            if (word_len < 8'd16) begin
                                temp_adverb[127-(buffer_idx*8) -: 8] <= char_in;
                                buffer_idx <= buffer_idx + 4'd1;
                            end
                            // Check for 'ly' ending
                            if (is_lower(char_in) && (buffer_idx > 4'd0)) begin
                                if (prev_char == 8'h6C && char_in == 8'h79) begin
                                    ly_count <= ly_count + 8'd1;
                                end
                            end
                        end else if (in_word && !is_alpha(char_in)) begin
                            in_word <= 1'b0;
                            last_char_was_space <= 1'b1;
                            // Check if word was adverb
                            if (word_len >= 8'd3 && ly_count >= 8'd1) begin
                                found <= 1'b1;
                                start_pos <= word_start_pos;
                                end_pos <= pos_counter - 8'd1;
                                adverb <= temp_adverb;
                            end
                        end else if (!in_word) begin
                            if (!is_alpha(char_in)) begin
                                last_char_was_space <= 1'b1;
                            end else begin
                                last_char_was_space <= 1'b0;
                            end
                        end
                    end
                end
                
                IN_WORD: begin
                    // Character processing moved to SEARCH
                    if (found) begin
                        // Already found
                    end
                end
                
                CHECK_END: begin
                    if (sentence_end) begin
                        if (!found) begin
                            error <= 1'b1;
                        end
                    end
                end
                
                FOUND: begin
                    done <= 1'b1;
                end
                
                FINISH: begin
                    if (!found) begin
                        error <= 1'b1;
                    end
                    done <= 1'b0;
                    // Reset for next operation
                    pos_counter <= 8'd0;
                    in_word <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    found <= 1'b0;
                    start_pos <= 8'd0;
                    end_pos <= 8'd0;
                    adverb <= 128'd0;
                    done <= 1'b0;
                    error <= 1'b0;
                end
            endcase
        end
    end
endmodule