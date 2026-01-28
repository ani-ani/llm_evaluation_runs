module words_in_sentence(
    input clk,
    input rst_n,
    input start,
    input [799:0] sentence,
    input [6:0] length,
    output reg [799:0] result,
    output reg [6:0] result_len,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] COPY    = 3'd3;
    localparam [2:0] UPDATE  = 3'd4;
    localparam [2:0] FINISH  = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Word tracking
    reg [6:0] word_start;      // Start index of current word
    reg [6:0] word_end;        // End index (exclusive)
    reg [6:0] word_len;        // Length of current word
    reg [6:0] parse_idx;       // Current position in sentence
    reg [6:0] result_pos;      // Current position in result buffer
    reg [6:0] copy_idx;        // Current position during copy
    reg [4:0] cycle_count;     // Safety counter (max 32 cycles)
    
    // Prime check: 7-bit LUT (1-100)
    reg is_prime;
    
    // Combinational prime check
    always @(*) begin
        case (word_len)
            7'd2, 7'd3, 7'd5, 7'd7, 7'd11, 7'd13, 7'd17, 7'd19,
            7'd23, 7'd29, 7'd31, 7'd37, 7'd41, 7'd43, 7'd47, 7'd53,
            7'd59, 7'd61, 7'd67, 7'd71, 7'd73, 7'd79, 7'd83, 7'd89,
            7'd97: is_prime = 1'b1;
            default: is_prime = 1'b0;
        endcase
    end
    
    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 800'd0;
            result_len <= 7'd0;
            done <= 1'b0;
            word_start <= 7'd0;
            word_end <= 7'd0;
            word_len <= 7'd0;
            parse_idx <= 7'd0;
            result_pos <= 7'd0;
            copy_idx <= 7'd0;
            cycle_count <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_len <= 7'd0;
                    result_pos <= 7'd0;
                    parse_idx <= 7'd0;
                    word_start <= 7'd0;
                    cycle_count <= 5'd0;
                end
                
                PARSE: begin
                    // Find next word boundary
                    if (parse_idx < length) begin
                        // Check for space or end of sentence
                        if (parse_idx == length - 1'd1) begin
                            // Last character is part of word
                            word_end <= parse_idx + 1'd1;
                            word_len <= word_end - word_start + 1'd1;
                            parse_idx <= parse_idx + 1'd1;
                        end else if (sentence[parse_idx*8+:8] == 8'h20) begin
                            // Space found, word ends here
                            word_end <= parse_idx;
                            word_len <= parse_idx - word_start;
                            parse_idx <= parse_idx + 1'd1;
                        end else begin
                            parse_idx <= parse_idx + 1'd1;
                        end
                    end
                    cycle_count <= cycle_count + 5'd1;
                end
                
                CHECK: begin
                    // is_prime already computed
                    cycle_count <= cycle_count + 5'd1;
                end
                
                COPY: begin
                    // Copy word byte by byte
                    if (copy_idx < word_len) begin
                        // Assign byte from sentence to result
                        // This is a pseudo-assignment; actual copy happens in UPDATE
                        // We'll use a temp reg for the byte
                        result[result_pos*8+:8] <= sentence[(word_start + copy_idx)*8+:8];
                        copy_idx <= copy_idx + 7'd1;
                        result_pos <= result_pos + 7'd1;
                    end
                    cycle_count <= cycle_count + 5'd1;
                end
                
                UPDATE: begin
                    // Add space after word
                    if (result_len > 7'd0) begin
                        result[result_len*8+:8] <= 8'h20;
                        result_len <= result_len + 7'd1;
                    end
                    result_len <= result_len + word_len;
                    word_start <= word_end + 7'd1;
                    copy_idx <= 7'd0;
                    cycle_count <= cycle_count + 5'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    cycle_count <= 5'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE;
                end
            end
            
            PARSE: begin
                // Check if we found a complete word or reached end
                if (parse_idx >= length) begin
                    // Reached end, check if last word is pending
                    if (word_start < length && sentence[word_start*8+:8] != 8'h20) begin
                        word_end <= length;
                        word_len <= length - word_start;
                        next_state = CHECK;
                    end else begin
                        next_state = FINISH;
                    end
                end else if (sentence[parse_idx*8+:8] == 8'h20) begin
                    // Space found, go to check
                    next_state = CHECK;
                end else if (parse_idx == length - 1'd1 && sentence[parse_idx*8+:8] != 8'h20) begin
                    // End of sentence, go to check
                    next_state = CHECK;
                end else begin
                    // Continue parsing
                    next_state = PARSE;
                end
            end
            
            CHECK: begin
                if (is_prime && word_len > 7'd0) begin
                    // Prime word found, need to copy
                    // Check if we need to add space first
                    if (result_len > 7'd0) begin
                        next_state = COPY;  // Will add space in COPY
                    end else begin
                        next_state = COPY;
                    end
                end else begin
                    // Not prime, skip to next word
                    next_state = PARSE;
                end
            end
            
            COPY: begin
                if (copy_idx >= word_len) begin
                    // Copy complete, update state
                    next_state = UPDATE;
                end else begin
                    next_state = COPY;
                end
            end
            
            UPDATE: begin
                // Go back to parse next word
                next_state = PARSE;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Safety: timeout after 32 cycles
        if (cycle_count >= 5'd31) begin
            next_state = FINISH;
        end
    end
endmodule