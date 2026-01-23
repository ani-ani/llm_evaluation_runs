module regex_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_index,
    output reg match_result,
    output reg done
);

    // State encoding
    localparam STATE_IDLE = 2'b00;
    localparam STATE_SEARCH = 2'b01;
    localparam STATE_FOUND_A = 2'b10;
    localparam STATE_COMPLETE = 2'b11;

    // ASCII constants
    localparam CHAR_A = 8'h61;
    localparam CHAR_B = 8'h62;

    // State registers
    reg [1:0] current_state;
    reg [1:0] next_state;

    // Internal control signals
    reg pattern_found;
    reg pattern_found_next;
    reg done_reg;
    reg done_reg_next;

    // State transition logic
    always @(*) begin
        next_state = current_state;
        pattern_found_next = pattern_found;
        done_reg_next = done_reg;

        case (current_state)
            STATE_IDLE: begin
                if (start) begin
                    next_state = STATE_SEARCH;
                    pattern_found_next = 1'b0;
                    done_reg_next = 1'b0;
                end
            end

            STATE_SEARCH: begin
                if (char_in == CHAR_A) begin
                    next_state = STATE_FOUND_A;
                end else if (char_in == CHAR_B) begin
                    // Unexpected 'b' without 'a', stay in SEARCH
                    next_state = STATE_SEARCH;
                end
                // For any other character, stay in SEARCH
                
                // Check if we've processed all characters
                if (char_index == 3'd7) begin
                    next_state = STATE_COMPLETE;
                end
            end

            STATE_FOUND_A: begin
                if (char_in == CHAR_B) begin
                    // Found 'b' after 'a', pattern is satisfied
                    pattern_found_next = 1'b1;
                    next_state = STATE_SEARCH; // Continue searching for more 'b's or another 'a'
                end else if (char_in == CHAR_A) begin
                    // Found another 'a', reset expectation
                    next_state = STATE_FOUND_A;
                    // pattern_found stays as is (could be 1 if we already found it)
                end else begin
                    // Character other than 'b' or 'a', go back to searching
                    next_state = STATE_SEARCH;
                end

                // Check if we've processed all characters
                if (char_index == 3'd7) begin
                    next_state = STATE_COMPLETE;
                end
            end

            STATE_COMPLETE: begin
                // Stay in complete state until reset or start
                if (start) begin
                    next_state = STATE_SEARCH;
                    pattern_found_next = 1'b0;
                    done_reg_next = 1'b0;
                end
            end

            default: begin
                next_state = STATE_IDLE;
                pattern_found_next = 1'b0;
                done_reg_next = 1'b0;
            end
        endcase

        // When reaching the last character, we need to handle the final state
        // This is a special case: if we're in STATE_FOUND_A at the last char and get 'b'
        if (char_index == 3'd7 && current_state != STATE_COMPLETE) begin
            if (current_state == STATE_FOUND_A && char_in == CHAR_B) begin
                pattern_found_next = 1'b1;
            end
            done_reg_next = 1'b1;
            next_state = STATE_COMPLETE;
        end
    end

    // State register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            pattern_found <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            current_state <= next_state;
            pattern_found <= pattern_found_next;
            done_reg <= done_reg_next;
        end
    end

    // Output assignments
    always @(*) begin
        match_result = pattern_found;
        done = done_reg;
    end

endmodule