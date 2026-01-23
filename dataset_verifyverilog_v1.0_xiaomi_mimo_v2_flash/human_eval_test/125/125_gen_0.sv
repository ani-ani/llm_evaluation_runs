module split_words_fsm (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input last_char,
    output reg [15:0] result,
    output reg done,
    output reg is_split_mode
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] word_count;
    reg [15:0] odd_char_count;
    reg delimiter_found;
    reg in_word;
    reg [3:0] char_index;  // 0-15 for 16 chars
    reg [7:0] delayed_char;
    reg delayed_valid;
    reg delayed_last;
    
    // Delimiter detection
    wire is_delimiter;
    assign is_delimiter = (char_in == 8'h20) || (char_in == 8'h2C);
    
    // Lowercase odd detection
    wire is_lower_odd;
    wire [7:0] ascii_offset;
    assign ascii_offset = char_in - 8'h61;  // 0 for 'a', 1 for 'b', etc.
    assign is_lower_odd = (char_in >= 8'h61) && (char_in <= 8'h7A) && (ascii_offset[0] == 1'b1);
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN;
                else
                    next_state = IDLE;
            end
            SCAN: begin
                if (delayed_valid && delayed_last)
                    next_state = DONE;
                else
                    next_state = SCAN;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            is_split_mode <= 1'b0;
            word_count <= 16'd0;
            odd_char_count <= 16'd0;
            delimiter_found <= 1'b0;
            in_word <= 1'b0;
            char_index <= 4'd0;
            delayed_char <= 8'd0;
            delayed_valid <= 1'b0;
            delayed_last <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset counters
                        word_count <= 16'd0;
                        odd_char_count <= 16'd0;
                        delimiter_found <= 1'b0;
                        in_word <= 1'b0;
                        char_index <= 4'd0;
                        result <= 16'd0;
                        is_split_mode <= 1'b0;
                    end
                end
                
                SCAN: begin
                    // Input buffering pipeline
                    delayed_char <= char_in;
                    delayed_valid <= valid_in;
                    delayed_last <= last_char;
                    
                    if (valid_in) begin
                        // Check for delimiters (Detection Phase)
                        if (is_delimiter) begin
                            delimiter_found <= 1'b1;
                            in_word <= 1'b0;  // End of word
                        end else begin
                            // Non-delimiter character
                            
                            // Word counting logic
                            if (!in_word) begin
                                in_word <= 1'b1;  // Start new word
                                word_count <= word_count + 16'd1;
                            end
                            
                            // Odd letter counting logic
                            if (is_lower_odd) begin
                                odd_char_count <= odd_char_count + 16'd1;
                            end
                        end
                        
                        char_index <= char_index + 4'd1;
                    end
                end
                
                DONE: begin
                    // Set outputs based on detection results
                    if (delimiter_found) begin
                        is_split_mode <= 1'b1;
                        result <= word_count;
                    end else begin
                        is_split_mode <= 1'b0;
                        result <= odd_char_count;
                    end
                    done <= 1'b1;  // Assert done for one cycle
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule