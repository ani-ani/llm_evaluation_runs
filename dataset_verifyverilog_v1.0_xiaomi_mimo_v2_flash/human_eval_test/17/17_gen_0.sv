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
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] PARSE    = 3'd1;
    localparam [2:0] OUTPUT   = 3'd2;
    localparam [2:0] DONE     = 3'd3;

    // Token type definitions
    localparam [2:0] TOKEN_NONE   = 3'd0;
    localparam [2:0] TOKEN_O      = 3'd1;
    localparam [2:0] TOKEN_O_SPACE = 3'd2;
    localparam [2:0] TOKEN_O_BAR  = 3'd3;
    localparam [2:0] TOKEN_DOT_BAR = 3'd4;

    // ASCII character constants
    localparam [7:0] CHAR_O     = 8'h6F;
    localparam [7:0] CHAR_DOT   = 8'h2E;
    localparam [7:0] CHAR_SPACE = 8'h20;
    localparam [7:0] CHAR_BAR   = 8'h7C;

    // Beat value constants
    localparam [3:0] BEATS_WHOLE  = 4'd4;
    localparam [3:0] BEATS_HALF   = 4'd2;
    localparam [3:0] BEATS_QUARTER = 4'd1;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] token_state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;
    reg parse_active;
    reg char_consumed;

    // FSM combinational logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE;
                end
            end
            
            PARSE: begin
                if (valid_char) begin
                    // Determine next state based on current token state and new character
                    case (token_state)
                        TOKEN_NONE: begin
                            if (char_in == CHAR_O) begin
                                next_state = PARSE;
                            end else if (char_in == CHAR_DOT) begin
                                next_state = PARSE;
                            end else if (char_in == CHAR_SPACE) begin
                                next_state = PARSE; // Skip whitespace
                            end else begin
                                next_state = PARSE; // Invalid, skip
                            end
                        end
                        
                        TOKEN_O: begin
                            if (char_in == CHAR_SPACE) begin
                                next_state = OUTPUT; // 'o ' -> whole note
                            end else if (char_in == CHAR_BAR) begin
                                next_state = OUTPUT; // 'o|' -> half note
                            end else begin
                                next_state = PARSE; // Invalid, reset
                            end
                        end
                        
                        TOKEN_O_SPACE: begin
                            next_state = PARSE; // Should not reach here
                        end
                        
                        TOKEN_O_BAR: begin
                            next_state = OUTPUT; // 'o|' complete
                        end
                        
                        TOKEN_DOT_BAR: begin
                            next_state = OUTPUT; // '.|' complete
                        end
                        
                        default: begin
                            next_state = PARSE;
                        end
                    endcase
                    
                    // Special handling for last character
                    if (last_char) begin
                        if ((token_state == TOKEN_O) || (token_state == TOKEN_O_SPACE)) begin
                            next_state = OUTPUT; // 'o' at end -> whole note
                        end else begin
                            next_state = DONE;
                        end
                    end
                end else begin
                    // No valid character, stay in PARSE or move to DONE if last_char was processed
                    if (last_char) begin
                        if (token_state == TOKEN_O) begin
                            next_state = OUTPUT; // 'o' followed by end
                        end else begin
                            next_state = DONE;
                        end
                    end
                end
            end
            
            OUTPUT: begin
                next_state = PARSE; // Continue parsing after output
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            token_state <= TOKEN_NONE;
            beats_out <= 4'd0;
            beats_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            parse_active <= 1'b0;
            char_consumed <= 1'b0;
        end else begin
            state <= next_state;
            beats_valid <= 1'b0;
            done <= 1'b0;
            char_consumed <= 1'b0;
            
            case (state)
                IDLE: begin
                    token_state <= TOKEN_NONE;
                    cycle_count <= 4'd0;
                    parse_active <= 1'b0;
                end
                
                PARSE: begin
                    if (valid_char && !char_consumed) begin
                        char_consumed <= 1'b1;
                        cycle_count <= cycle_count + 4'd1;
                        
                        case (token_state)
                            TOKEN_NONE: begin
                                if (char_in == CHAR_O) begin
                                    token_state <= TOKEN_O;
                                end else if (char_in == CHAR_DOT) begin
                                    token_state <= TOKEN_DOT_BAR; // Waiting for bar
                                end else begin
                                    token_state <= TOKEN_NONE; // Skip
                                end
                            end
                            
                            TOKEN_O: begin
                                if (char_in == CHAR_SPACE) begin
                                    // Token complete: 'o ' -> whole note (4 beats)
                                    // Will output in OUTPUT state
                                end else if (char_in == CHAR_BAR) begin
                                    // Token complete: 'o|' -> half note (2 beats)
                                    token_state <= TOKEN_O_BAR;
                                end else begin
                                    token_state <= TOKEN_NONE; // Invalid, reset
                                end
                            end
                            
                            TOKEN_DOT_BAR: begin
                                if (char_in == CHAR_BAR) begin
                                    token_state <= TOKEN_NONE; // '.|' complete, ready to output
                                end else begin
                                    token_state <= TOKEN_NONE; // Invalid
                                end
                            end
                            
                            default: begin
                                token_state <= TOKEN_NONE;
                            end
                        endcase
                    end
                    
                    // Handle last character without valid_char pulse
                    if (last_char && !valid_char && (token_state == TOKEN_O)) begin
                        // Special case: 'o' at end -> whole note
                    end
                end
                
                OUTPUT: begin
                    beats_valid <= 1'b1;
                    case (token_state)
                        TOKEN_O, TOKEN_O_SPACE: begin
                            beats_out <= BEATS_WHOLE;
                        end
                        TOKEN_O_BAR: begin
                            beats_out <= BEATS_HALF;
                        end
                        TOKEN_DOT_BAR: begin
                            beats_out <= BEATS_QUARTER;
                        end
                        default: begin
                            beats_out <= 4'd0;
                        end
                    endcase
                    token_state <= TOKEN_NONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
            
            // Handle output for single character tokens at end of input
            if (state == PARSE && last_char && token_state == TOKEN_O) begin
                // Will transition to OUTPUT on next cycle
            end
        end
    end

endmodule