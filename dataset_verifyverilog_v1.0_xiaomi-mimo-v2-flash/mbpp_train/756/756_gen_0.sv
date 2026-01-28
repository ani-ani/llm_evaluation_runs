module ab_plus_pattern_matcher (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_char,
    input wire char_valid,
    input wire [3:0] input_string_len,
    output reg match,
    output reg done,
    output reg [3:0] char_index
);

    // State declarations
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CHECK_CHAR     = 3'd1;
    localparam [2:0] WAIT_FOR_B     = 3'd2;
    localparam [2:0] FOUND_B        = 3'd3;
    localparam [2:0] PATTERN_FOUND  = 3'd4;
    localparam [2:0] PATTERN_FAIL   = 3'd5;
    localparam [2:0] DONE_STATE     = 3'd6;

    reg [2:0] state, next_state;
    reg [3:0] chars_processed;
    reg pattern_found_reg;
    reg wait_for_b_flag;
    reg valid_b_seen;

    // ASCII constants
    localparam [7:0] CHAR_A = 8'd97;   // 'a'
    localparam [7:0] CHAR_B = 8'd98;   // 'b'

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_CHAR;
                else
                    next_state = IDLE;
            end
            
            CHECK_CHAR: begin
                if (char_valid) begin
                    if (input_char == CHAR_A) begin
                        next_state = WAIT_FOR_B;
                    end else begin
                        if (chars_processed >= input_string_len)
                            next_state = PATTERN_FAIL;
                        else
                            next_state = CHECK_CHAR;
                    end
                end else begin
                    next_state = CHECK_CHAR;
                end
            end
            
            WAIT_FOR_B: begin
                if (char_valid) begin
                    if (input_char == CHAR_B) begin
                        next_state = FOUND_B;
                    end else if (input_char == CHAR_A) begin
                        // New 'a' found, restart pattern search
                        next_state = WAIT_FOR_B;
                    end else begin
                        // Other character breaks pattern
                        if (chars_processed >= input_string_len)
                            next_state = PATTERN_FAIL;
                        else
                            next_state = CHECK_CHAR;
                    end
                end else begin
                    next_state = WAIT_FOR_B;
                end
            end
            
            FOUND_B: begin
                if (char_valid) begin
                    if (input_char == CHAR_B) begin
                        // More 'b's found, stay in FOUND_B
                        next_state = FOUND_B;
                    end else if (input_char == CHAR_A) begin
                        // New 'a' found, restart pattern search
                        next_state = WAIT_FOR_B;
                    end else begin
                        // Other character - pattern is satisfied
                        if (chars_processed >= input_string_len)
                            next_state = PATTERN_FOUND;
                        else
                            next_state = PATTERN_FOUND;
                    end
                end else begin
                    next_state = FOUND_B;
                end
            end
            
            PATTERN_FOUND: begin
                if (chars_processed >= input_string_len)
                    next_state = DONE_STATE;
                else
                    next_state = CHECK_CHAR;
            end
            
            PATTERN_FAIL: begin
                if (chars_processed >= input_string_len)
                    next_state = DONE_STATE;
                else
                    next_state = CHECK_CHAR;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State register and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match <= 1'b0;
            done <= 1'b0;
            char_index <= 4'd0;
            chars_processed <= 4'd0;
            pattern_found_reg <= 1'b0;
            wait_for_b_flag <= 1'b0;
            valid_b_seen <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    match <= 1'b0;
                    char_index <= 4'd0;
                    chars_processed <= 4'd0;
                    pattern_found_reg <= 1'b0;
                    wait_for_b_flag <= 1'b0;
                    valid_b_seen <= 1'b0;
                end
                
                CHECK_CHAR: begin
                    done <= 1'b0;
                    if (char_valid) begin
                        if (input_char == CHAR_A) begin
                            wait_for_b_flag <= 1'b1;
                        end else begin
                            wait_for_b_flag <= 1'b0;
                            if (chars_processed < input_string_len)
                                chars_processed <= chars_processed + 4'd1;
                        end
                    end
                end
                
                WAIT_FOR_B: begin
                    done <= 1'b0;
                    if (char_valid) begin
                        if (input_char == CHAR_B) begin
                            valid_b_seen <= 1'b1;
                            wait_for_b_flag <= 1'b1;
                        end else if (input_char == CHAR_A) begin
                            // Restart pattern search
                            wait_for_b_flag <= 1'b1;
                            valid_b_seen <= 1'b0;
                        end else begin
                            // Other character - break pattern
                            wait_for_b_flag <= 1'b0;
                            valid_b_seen <= 1'b0;
                            if (chars_processed < input_string_len)
                                chars_processed <= chars_processed + 4'd1;
                        end
                    end
                end
                
                FOUND_B: begin
                    done <= 1'b0;
                    if (char_valid) begin
                        if (input_char == CHAR_B) begin
                            valid_b_seen <= 1'b1;
                        end else if (input_char == CHAR_A) begin
                            // Restart pattern search with new 'a'
                            wait_for_b_flag <= 1'b1;
                            valid_b_seen <= 1'b0;
                        end else begin
                            // Pattern satisfied with other character
                            pattern_found_reg <= 1'b1;
                            if (chars_processed < input_string_len)
                                chars_processed <= chars_processed + 4'd1;
                        end
                    end
                end
                
                PATTERN_FOUND: begin
                    pattern_found_reg <= 1'b1;
                    wait_for_b_flag <= 1'b0;
                    valid_b_seen <= 1'b0;
                    if (chars_processed < input_string_len)
                        chars_processed <= chars_processed + 4'd1;
                    match <= 1'b1;
                end
                
                PATTERN_FAIL: begin
                    pattern_found_reg <= 1'b0;
                    wait_for_b_flag <= 1'b0;
                    valid_b_seen <= 1'b0;
                    if (chars_processed < input_string_len)
                        chars_processed <= chars_processed + 4'd1;
                    match <= 1'b0;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (pattern_found_reg)
                        match <= 1'b1;
                    else
                        match <= 1'b0;
                    char_index <= chars_processed;
                end
            endcase
        end
    end

endmodule