module WordFilter (
    input clk,
    input rst_n,
    input start,
    input [3:0] threshold,
    input [63:0] input_str,
    output reg [3:0] result_count,
    output reg [127:0] result_words,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] STORE   = 3'd3;
    localparam [3:0] COMPLETE = 4'd4;
    localparam [3:0] FLUSH   = 4'd5;
    
    reg [2:0] state, next_state;
    reg [2:0] byte_ptr;      // 0-7: index in input string
    reg [2:0] word_ptr;      // 0-7: index in result_words
    reg [3:0] char_cnt;      // 0-15: count of chars in current word
    reg [3:0] result_cnt_reg;
    reg [127:0] result_words_reg;
    reg [7:0] word_buffer[0:7]; // Stores current word chars
    reg [2:0] buffer_idx;       // Index in word_buffer
    reg [7:0] current_char;
    reg [7:0] space_char;
    reg [2:0] flush_ptr;
    
    // Initialize constants
    initial begin
        space_char = 8'h20;
    end
    
    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = PARSE;
            end
            PARSE: begin
                if (byte_ptr == 3'd7) begin
                    if (char_cnt > 4'd0)
                        next_state = COMPARE;
                    else
                        next_state = COMPLETE;
                end else begin
                    if (current_char == space_char && char_cnt > 4'd0)
                        next_state = COMPARE;
                    else if (current_char == space_char && char_cnt == 4'd0)
                        next_state = PARSE; // Skip leading spaces
                    else if (current_char != space_char)
                        next_state = PARSE; // Continue reading char
                    else if (byte_ptr == 3'd7)
                        next_state = COMPLETE;
                    else
                        next_state = PARSE;
                end
            end
            COMPARE: begin
                if (char_cnt > threshold) begin
                    if (word_ptr < 3'd7)
                        next_state = STORE;
                    else
                        next_state = FLUSH;
                end else begin
                    if (byte_ptr == 3'd7 && char_cnt == 4'd0)
                        next_state = COMPLETE;
                    else
                        next_state = PARSE;
                end
            end
            STORE: begin
                next_state = FLUSH;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            FLUSH: begin
                if (flush_ptr == 3'd7)
                    next_state = COMPLETE;
                else
                    next_state = FLUSH;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            byte_ptr <= 3'd0;
            word_ptr <= 3'd0;
            char_cnt <= 4'd0;
            result_count <= 4'd0;
            result_words <= 128'd0;
            done <= 1'b0;
            buffer_idx <= 3'd0;
            current_char <= 8'd0;
            result_cnt_reg <= 4'd0;
            result_words_reg <= 128'd0;
            flush_ptr <= 3'd0;
            word_buffer[0] <= 8'd0;
            word_buffer[1] <= 8'd0;
            word_buffer[2] <= 8'd0;
            word_buffer[3] <= 8'd0;
            word_buffer[4] <= 8'd0;
            word_buffer[5] <= 8'd0;
            word_buffer[6] <= 8'd0;
            word_buffer[7] <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    byte_ptr <= 3'd0;
                    word_ptr <= 3'd0;
                    char_cnt <= 4'd0;
                    buffer_idx <= 3'd0;
                    result_cnt_reg <= 4'd0;
                    result_words_reg <= 128'd0;
                    flush_ptr <= 3'd0;
                    word_buffer[0] <= 8'd0;
                    word_buffer[1] <= 8'd0;
                    word_buffer[2] <= 8'd0;
                    word_buffer[3] <= 8'd0;
                    word_buffer[4] <= 8'd0;
                    word_buffer[5] <= 8'd0;
                    word_buffer[6] <= 8'd0;
                    word_buffer[7] <= 8'd0;
                end
                PARSE: begin
                    if (byte_ptr < 3'd7) begin
                        // Get next character from input_str
                        case (byte_ptr)
                            3'd0: current_char <= input_str[63:56];
                            3'd1: current_char <= input_str[55:48];
                            3'd2: current_char <= input_str[47:40];
                            3'd3: current_char <= input_str[39:32];
                            3'd4: current_char <= input_str[31:24];
                            3'd5: current_char <= input_str[23:16];
                            3'd6: current_char <= input_str[15:8];
                            3'd7: current_char <= input_str[7:0];
                        endcase
                        
                        // Update counters
                        if (current_char != space_char && char_cnt < 4'd8) begin
                            word_buffer[buffer_idx] <= current_char;
                            buffer_idx <= buffer_idx + 3'd1;
                            char_cnt <= char_cnt + 4'd1;
                        end
                        byte_ptr <= byte_ptr + 3'd1;
                    end else begin
                        // Handle last character (byte_ptr == 7)
                        current_char <= input_str[7:0];
                        if (input_str[7:0] != space_char && char_cnt < 4'd8) begin
                            word_buffer[buffer_idx] <= input_str[7:0];
                            buffer_idx <= buffer_idx + 3'd1;
                            char_cnt <= char_cnt + 4'd1;
                        end
                        byte_ptr <= byte_ptr + 3'd1;
                    end
                end
                COMPARE: begin
                    // Comparison happens in combinational logic
                    // Reset for next word if not storing
                    if (char_cnt <= threshold) begin
                        char_cnt <= 4'd0;
                        buffer_idx <= 3'd0;
                        word_buffer[0] <= 8'd0;
                        word_buffer[1] <= 8'd0;
                        word_buffer[2] <= 8'd0;
                        word_buffer[3] <= 8'd0;
                        word_buffer[4] <= 8'd0;
                        word_buffer[5] <= 8'd0;
                        word_buffer[6] <= 8'd0;
                        word_buffer[7] <= 8'd0;
                    end
                end
                STORE: begin
                    // Pack word into result_words_reg
                    if (word_ptr < 3'd7) begin
                        case (word_ptr)
                            3'd0: begin
                                result_words_reg[7:0]   <= word_buffer[0];
                                result_words_reg[15:8]  <= word_buffer[1];
                                result_words_reg[23:16] <= word_buffer[2];
                                result_words_reg[31:24] <= word_buffer[3];
                                result_words_reg[39:32] <= word_buffer[4];
                                result_words_reg[47:40] <= word_buffer[5];
                                result_words_reg[55:48] <= word_buffer[6];
                                result_words_reg[63:56] <= word_buffer[7];
                            end
                            3'd1: begin
                                result_words_reg[71:64]  <= word_buffer[0];
                                result_words_reg[79:72]  <= word_buffer[1];
                                result_words_reg[87:80]  <= word_buffer[2];
                                result_words_reg[95:88]  <= word_buffer[3];
                                result_words_reg[103:96] <= word_buffer[4];
                                result_words_reg[111:104] <= word_buffer[5];
                                result_words_reg[119:112] <= word_buffer[6];
                                result_words_reg[127:120] <= word_buffer[7];
                            end
                        endcase
                        word_ptr <= word_ptr + 3'd1;
                        result_cnt_reg <= result_cnt_reg + 4'd1;
                    end
                    // Reset buffer for next word
                    char_cnt <= 4'd0;
                    buffer_idx <= 3'd0;
                    word_buffer[0] <= 8'd0;
                    word_buffer[1] <= 8'd0;
                    word_buffer[2] <= 8'd0;
                    word_buffer[3] <= 8'd0;
                    word_buffer[4] <= 8'd0;
                    word_buffer[5] <= 8'd0;
                    word_buffer[6] <= 8'd0;
                    word_buffer[7] <= 8'd0;
                    // Prepare for next word in PARSE
                    byte_ptr <= byte_ptr + 3'd1;
                    if (byte_ptr >= 3'd7) begin
                        // We reached the end of string
                        if (byte_ptr > 3'd7) begin
                            // Should transition to COMPLETE
                        end
                    end
                end
                COMPLETE: begin
                    result_count <= result_cnt_reg;
                    result_words <= result_words_reg;
                    done <= 1'b1;
                end
                FLUSH: begin
                    // Zero out remaining result_words positions
                    if (flush_ptr < 3'd7 && flush_ptr >= word_ptr) begin
                        case (flush_ptr)
                            3'd0: begin
                                result_words_reg[7:0]   <= 8'd0;
                                result_words_reg[15:8]  <= 8'd0;
                                result_words_reg[23:16] <= 8'd0;
                                result_words_reg[31:24] <= 8'd0;
                                result_words_reg[39:32] <= 8'd0;
                                result_words_reg[47:40] <= 8'd0;
                                result_words_reg[55:48] <= 8'd0;
                                result_words_reg[63:56] <= 8'd0;
                            end
                            3'd1: begin
                                result_words_reg[71:64]  <= 8'd0;
                                result_words_reg[79:72]  <= 8'd0;
                                result_words_reg[87:80]  <= 8'd0;
                                result_words_reg[95:88]  <= 8'd0;
                                result_words_reg[103:96] <= 8'd0;
                                result_words_reg[111:104] <= 8'd0;
                                result_words_reg[119:112] <= 8'd0;
                                result_words_reg[127:120] <= 8'd0;
                            end
                        endcase
                    end
                    flush_ptr <= flush_ptr + 3'd1;
                end
            endcase
        end
    end
endmodule