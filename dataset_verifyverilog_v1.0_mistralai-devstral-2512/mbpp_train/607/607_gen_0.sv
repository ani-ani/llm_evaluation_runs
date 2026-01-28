module pattern_search(
    input clk,
    input rst_n,
    input start,
    input [7:0] text [0:63],
    input [5:0] text_len,
    input [7:0] pattern [0:7],
    input [3:0] pattern_len,
    output reg [5:0] result_start,
    output reg [5:0] result_end,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SEARCH   = 3'd1;
    localparam [2:0] COMPARE  = 3'd2;
    localparam [2:0] FOUND    = 3'd3;
    localparam [2:0] NO_MATCH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] text_pos;       // Current position in text
    reg [2:0] char_pos;       // Current character in pattern
    reg [5:0] match_start;    // Start position of match
    reg [5:0] match_end;      // End position of match
    reg match_found;          // Match found flag
    reg [7:0] cycle_count;    // Cycle counter for timeout
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Default assignments
    assign done = (state == FOUND || state == NO_MATCH) ? 1'b1 : 1'b0;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && text_len >= pattern_len && pattern_len > 0) begin
                    next_state = SEARCH;
                end else begin
                    next_state = IDLE;
                end
            end

            SEARCH: begin
                if (text_pos <= text_len - pattern_len) begin
                    next_state = COMPARE;
                end else begin
                    next_state = NO_MATCH;
                end
            end

            COMPARE: begin
                if (char_pos == pattern_len - 1) begin
                    if (text[text_pos + char_pos] == pattern[char_pos]) begin
                        next_state = FOUND;
                    end else begin
                        next_state = SEARCH;
                    end
                end else begin
                    if (text[text_pos + char_pos] == pattern[char_pos]) begin
                        next_state = COMPARE;
                    end else begin
                        next_state = SEARCH;
                    end
                end
            end

            FOUND:    next_state = IDLE;
            NO_MATCH: next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            text_pos <= 6'd0;
            char_pos <= 3'd0;
            match_start <= 6'd63;
            match_end <= 6'd64;
            match_found <= 1'b0;
            cycle_count <= 8'd0;
            result_start <= 6'd63;
            result_end <= 6'd64;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    text_pos <= 6'd0;
                    char_pos <= 3'd0;
                    match_start <= 6'd63;
                    match_end <= 6'd64;
                    match_found <= 1'b0;
                    cycle_count <= 8'd0;
                    result_start <= 6'd63;
                    result_end <= 6'd64;
                    done <= 1'b0;
                end

                SEARCH: begin
                    if (text_pos <= text_len - pattern_len) begin
                        text_pos <= text_pos + 6'd1;
                    end
                    char_pos <= 3'd0;
                    cycle_count <= cycle_count + 8'd1;
                end

                COMPARE: begin
                    if (char_pos == 3'd0) begin
                        match_start <= text_pos;
                    end
                    char_pos <= char_pos + 3'd1;
                    cycle_count <= cycle_count + 8'd1;
                end

                FOUND: begin
                    match_end <= match_start + pattern_len;
                    result_start <= match_start;
                    result_end <= match_end;
                    done <= 1'b1;
                end

                NO_MATCH: begin
                    result_start <= 6'd63;
                    result_end <= 6'd64;
                    done <= 1'b1;
                end

                default: begin
                    text_pos <= 6'd0;
                    char_pos <= 3'd0;
                    match_start <= 6'd63;
                    match_end <= 6'd64;
                    match_found <= 1'b0;
                    cycle_count <= 8'd0;
                    result_start <= 6'd63;
                    result_end <= 6'd64;
                    done <= 1'b0;
                end
            endcase

            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                state <= NO_MATCH;
                result_start <= 6'd63;
                result_end <= 6'd64;
                done <= 1'b1;
            end
        end
    end

endmodule