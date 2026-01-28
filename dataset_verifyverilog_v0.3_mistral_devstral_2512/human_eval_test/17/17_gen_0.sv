module parse_music(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_idx,
    input valid_char,
    input last_char,
    output reg [3:0] beats_out,
    output reg beats_valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PARSE   = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] current_char;
    reg [3:0] current_idx;
    reg char_processed;
    reg token_complete;
    reg [3:0] token_beats;

    // ASCII values
    localparam [7:0] ASCII_o    = 8'd111;
    localparam [7:0] ASCII_dot  = 8'd46;
    localparam [7:0] ASCII_pipe = 8'd124;
    localparam [7:0] ASCII_space = 8'd32;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            beats_out <= 4'd0;
            beats_valid <= 1'b0;
            done <= 1'b0;
            current_char <= 8'd0;
            current_idx <= 4'd0;
            char_processed <= 1'b0;
            token_complete <= 1'b0;
            token_beats <= 4'd0;
        end else begin
            state <= next_state;
            
            // Sample character when valid
            if (valid_char && !char_processed) begin
                current_char <= char_in;
                current_idx <= char_idx;
                char_processed <= 1'b1;
            end
            
            // Clear char_processed flag
            if (state == PARSE && char_processed) begin
                char_processed <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        beats_valid = 1'b0;
        token_complete = 1'b0;
        token_beats = 4'd0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE;
                end
            end

            PARSE: begin
                if (valid_char && !char_processed) begin
                    // Process current character
                    if (current_char == ASCII_o) begin
                        // Look ahead to next character
                        if (char_idx < 15'd15 && !last_char) begin
                            // Next character will be processed in next cycle
                            // For now, just mark we're processing 'o'
                        end else begin
                            // End of input after 'o' - treat as 4 beats
                            token_beats = 4'd4;
                            token_complete = 1'b1;
                        end
                    end else if (current_char == ASCII_dot) begin
                        // Look ahead for '|'
                        if (char_idx < 15'd15 && !last_char) begin
                            // Next character will be processed in next cycle
                        end else begin
                            // End of input after '.' - ignore (no pipe)
                        end
                    end else if (current_char == ASCII_pipe) begin
                        // Previous character determines beat value
                        // This is handled in the lookahead logic
                    end else if (current_char == ASCII_space) begin
                        // Space separates tokens - ignore
                    end
                end
                
                // Lookahead logic for token completion
                if (current_char == ASCII_o && char_processed) begin
                    // Check if next character is space or end
                    if ((char_idx == 15'd15) || last_char || 
                        (valid_char && char_in == ASCII_space)) begin
                        token_beats = 4'd4;
                        token_complete = 1'b1;
                    end else if (valid_char && char_in == ASCII_pipe) begin
                        token_beats = 4'd2;
                        token_complete = 1'b1;
                    end
                end else if (current_char == ASCII_dot && char_processed) begin
                    // Check if next character is pipe
                    if (valid_char && char_in == ASCII_pipe) begin
                        token_beats = 4'd1;
                        token_complete = 1'b1;
                    end
                end
                
                // Move to OUTPUT state when token complete
                if (token_complete) begin
                    next_state = OUTPUT;
                end
                
                // Check for end of input
                if (last_char && !valid_char) begin
                    next_state = DONE;
                end
            end

            OUTPUT: begin
                beats_valid = 1'b1;
                beats_out = token_beats;
                next_state = PARSE;
            end

            DONE: begin
                done = 1'b1;
                if (start) begin
                    next_state = IDLE;
                    done = 1'b0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule