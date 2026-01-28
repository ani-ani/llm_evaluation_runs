module FileNameValidator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_done,
    output reg result,
    output reg done,
    output reg [2:0] err_type
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] READING_NAME = 3'd1;
    localparam [2:0] READING_EXT  = 3'd2;
    localparam [2:0] VALIDATING   = 3'd3;
    localparam [2:0] ERROR_STATE  = 3'd4;
    
    // Error type definitions
    localparam [2:0] ERR_NONE        = 3'd0;
    localparam [2:0] ERR_NO_DOT      = 3'd1;
    localparam [2:0] ERR_BAD_EXT     = 3'd2;
    localparam [2:0] ERR_TOO_MANY_DIGITS = 3'd3;
    localparam [2:0] ERR_BAD_START   = 3'd4;
    localparam [2:0] ERR_BAD_LENGTH  = 3'd5;
    localparam [2:0] ERR_MULTIPLE_DOTS = 3'd6;
    localparam [2:0] ERR_EMPTY_NAME  = 3'd7;
    
    // Internal state registers
    reg [2:0] state, next_state;
    reg [5:0] pos;                // 0-63, max 32 needed
    reg [5:0] dot_pos;            // 0-63, position of dot
    reg [2:0] digit_count;        // 0-7, counts digits 0-9
    reg [7:0] ext_char_count;     // Count chars after dot
    reg [7:0] processed_chars;    // Total processed chars
    reg dot_seen;
    reg valid_start;
    reg is_valid;
    reg [2:0] error_code;
    
    // For extension checking
    reg [2:0] ext_state;          // 0: waiting, 1-3: checking chars
    reg [7:0] ext_char_1;
    reg [7:0] ext_char_2;
    reg [7:0] ext_char_3;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 6'd0;
            dot_pos <= 6'd0;
            digit_count <= 3'd0;
            ext_char_count <= 8'd0;
            processed_chars <= 8'd0;
            dot_seen <= 1'b0;
            valid_start <= 1'b0;
            is_valid <= 1'b0;
            error_code <= ERR_NONE;
            result <= 1'b0;
            done <= 1'b0;
            ext_state <= 3'd0;
            ext_char_1 <= 8'd0;
            ext_char_2 <= 8'd0;
            ext_char_3 <= 8'd0;
        end else begin
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset all counters and state
                        pos <= 6'd0;
                        dot_pos <= 6'd0;
                        digit_count <= 3'd0;
                        ext_char_count <= 8'd0;
                        processed_chars <= 8'd0;
                        dot_seen <= 1'b0;
                        valid_start <= 1'b0;
                        is_valid <= 1'b0;
                        error_code <= ERR_NONE;
                        result <= 1'b0;
                        ext_state <= 3'd0;
                        ext_char_1 <= 8'd0;
                        ext_char_2 <= 8'd0;
                        ext_char_3 <= 8'd0;
                        state <= READING_NAME;
                    end
                end
                
                READING_NAME: begin
                    if (char_valid) begin
                        processed_chars <= processed_chars + 8'd1;
                        
                        // Check max length
                        if (processed_chars >= 8'd32) begin
                            error_code <= ERR_BAD_LENGTH;
                            state <= ERROR_STATE;
                        end else if (char_done) begin
                            // End of string before dot
                            if (!dot_seen) begin
                                error_code <= ERR_NO_DOT;
                                state <= ERROR_STATE;
                            end else if (ext_char_count == 3'd0) begin
                                error_code <= ERR_EMPTY_NAME;
                                state <= ERROR_STATE;
                            end else begin
                                state <= VALIDATING;
                            end
                        end else begin
                            // Process character
                            pos <= pos + 6'd1;
                            
                            // Check if it's a dot
                            if (char_in == 8'h2E) begin
                                if (pos == 6'd0) begin
                                    error_code <= ERR_EMPTY_NAME;
                                    state <= ERROR_STATE;
                                end else if (dot_seen) begin
                                    error_code <= ERR_MULTIPLE_DOTS;
                                    state <= ERROR_STATE;
                                end else begin
                                    dot_seen <= 1'b1;
                                    dot_pos <= pos;
                                    state <= READING_EXT;
                                end
                            end else begin
                                // Check valid start
                                if (pos == 6'd0) begin
                                    // First character must be Latin letter
                                    if ((char_in >= 8'h41 && char_in <= 8'h5A) ||  // A-Z
                                        (char_in >= 8'h61 && char_in <= 8'h7A)) begin // a-z
                                        valid_start <= 1'b1;
                                    end else begin
                                        error_code <= ERR_BAD_START;
                                        state <= ERROR_STATE;
                                    end
                                end
                                
                                // Check for valid characters in name
                                if (state != ERROR_STATE) begin
                                    // Letters, digits, underscore, hyphen
                                    if ((char_in >= 8'h41 && char_in <= 8'h5A) ||  // A-Z
                                        (char_in >= 8'h61 && char_in <= 8'h7A) ||  // a-z
                                        (char_in >= 8'h30 && char_in <= 8'h39) ||  // 0-9
                                        (char_in == 8'h5F) ||  // underscore
                                        (char_in == 8'h2D)) begin  // hyphen
                                        
                                        // Count digits
                                        if (char_in >= 8'h30 && char_in <= 8'h39) begin
                                            digit_count <= digit_count + 3'd1;
                                            if (digit_count >= 3'd3) begin
                                                error_code <= ERR_TOO_MANY_DIGITS;
                                                state <= ERROR_STATE;
                                            end
                                        end
                                    end else begin
                                        error_code <= ERR_BAD_START;
                                        state <= ERROR_STATE;
                                    end
                                end
                            end
                        end
                    end
                end
                
                READING_EXT: begin
                    if (char_valid) begin
                        if (char_done) begin
                            // End of string
                            if (ext_char_count == 3'd3) begin
                                state <= VALIDATING;
                            end else begin
                                error_code <= ERR_BAD_EXT;
                                state <= ERROR_STATE;
                            end
                        end else begin
                            // Process extension character
                            ext_char_count <= ext_char_count + 8'd1;
                            
                            if (ext_char_count == 3'd0) begin
                                ext_char_1 <= char_in;
                            end else if (ext_char_count == 3'd1) begin
                                ext_char_2 <= char_in;
                            end else if (ext_char_count == 3'd2) begin
                                ext_char_3 <= char_in;
                            end else begin
                                // Too many chars in extension
                                error_code <= ERR_BAD_EXT;
                                state <= ERROR_STATE;
                            end
                        end
                    end
                end
                
                VALIDATING: begin
                    // Check extension: txt, exe, dll (case-insensitive)
                    if (ext_char_count == 3'd3) begin
                        // Check 'txt' (54 78 74)
                        if (((ext_char_1 == 8'h74) || (ext_char_1 == 8'h54)) &&  // t/T
                            ((ext_char_2 == 8'h78) || (ext_char_2 == 8'h58)) &&  // x/X
                            ((ext_char_3 == 8'h74) || (ext_char_3 == 8'h54))) begin  // t/T
                            is_valid <= 1'b1;
                        end
                        // Check 'exe' (65 78 65)
                        else if (((ext_char_1 == 8'h65) || (ext_char_1 == 8'h45)) &&  // e/E
                                 ((ext_char_2 == 8'h78) || (ext_char_2 == 8'h58)) &&  // x/X
                                 ((ext_char_3 == 8'h65) || (ext_char_3 == 8'h45))) begin  // e/E
                            is_valid <= 1'b1;
                        end
                        // Check 'dll' (64 6C 6C)
                        else if (((ext_char_1 == 8'h64) || (ext_char_1 == 8'h44)) &&  // d/D
                                 ((ext_char_2 == 8'h6C) || (ext_char_2 == 8'h4C)) &&  // l/L
                                 ((ext_char_3 == 8'h6C) || (ext_char_3 == 8'h4C))) begin  // l/L
                            is_valid <= 1'b1;
                        end else begin
                            is_valid <= 1'b0;
                            error_code <= ERR_BAD_EXT;
                        end
                    end else begin
                        is_valid <= 1'b0;
                        error_code <= ERR_BAD_EXT;
                    end
                    
                    // Check digit count (already checked during processing)
                    // Check start character (already checked during processing)
                    // Check dot position (already checked during processing)
                    
                    // Final result
                    if (is_valid && 
                        dot_seen && 
                        (digit_count <= 3'd3) && 
                        (ext_char_count == 3'd3) &&
                        valid_start &&
                        (dot_pos < pos - 3)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR_STATE: begin
                    // Immediate error detection
                    if (char_done) begin
                        // Wait for char_done before outputting error
                        result <= 1'b0;
                        done <= 1'b1;
                        state <= IDLE;
                    end else if (char_valid) begin
                        // Continue reading to consume remaining chars
                        // But don't update state or counters
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Assign err_type output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            err_type <= ERR_NONE;
        end else begin
            if (state == IDLE && start) begin
                err_type <= ERR_NONE;
            end else if (state == VALIDATING || state == ERROR_STATE) begin
                err_type <= error_code;
            end
        end
    end

endmodule