module substring_matcher (
    input clk,
    input rst_n,
    input start,
    input [7:0] text [0:15],
    input [7:0] pattern [0:7],
    input [4:0] text_len,
    input [3:0] pattern_len,
    output reg [3:0] start_pos,
    output reg [3:0] end_pos,
    output reg match_found,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        SEARCHING,
        MATCHING,
        COMPLETE,
        NOT_FOUND
    } state_t;

    state_t current_state, next_state;

    // Counters
    reg [4:0] text_index;
    reg [3:0] pattern_index;
    reg [3:0] match_start_pos;

    // Character comparison
    reg char_match;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            text_index <= 0;
            pattern_index <= 0;
            match_start_pos <= 0;
            start_pos <= 15;
            end_pos <= 15;
            match_found <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;

            // Update counters based on state transitions
            case (current_state)
                IDLE: begin
                    text_index <= 0;
                    pattern_index <= 0;
                    match_start_pos <= 0;
                    start_pos <= 15;
                    end_pos <= 15;
                    match_found <= 0;
                    done <= 0;
                end
                SEARCHING: begin
                    if (text_index + pattern_len > text_len) begin
                        // No space left for pattern
                        text_index <= text_len;
                    end else if (char_match) begin
                        // First character matched, start matching
                        match_start_pos <= text_index;
                        pattern_index <= 1;
                    end else begin
                        // Mismatch, move to next position
                        text_index <= text_index + 1;
                    end
                end
                MATCHING: begin
                    if (char_match) begin
                        if (pattern_index == pattern_len - 1) begin
                            // Complete match found
                            start_pos <= match_start_pos;
                            end_pos <= match_start_pos + pattern_len;
                            match_found <= 1;
                        end else begin
                            pattern_index <= pattern_index + 1;
                        end
                    end else begin
                        // Mismatch, reset to searching
                        text_index <= match_start_pos + 1;
                        pattern_index <= 0;
                    end
                end
                COMPLETE, NOT_FOUND: begin
                    // Keep outputs stable
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        char_match = 0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    if (pattern_len == 0 || text_len < pattern_len) begin
                        next_state = NOT_FOUND;
                    end else begin
                        next_state = SEARCHING;
                    end
                end
            end
            SEARCHING: begin
                if (text_index + pattern_len > text_len) begin
                    next_state = NOT_FOUND;
                end else begin
                    char_match = (text[text_index] == pattern[0]);
                    if (char_match) begin
                        next_state = MATCHING;
                    end
                end
            end
            MATCHING: begin
                char_match = (text[text_index + pattern_index] == pattern[pattern_index]);
                if (!char_match) begin
                    next_state = SEARCHING;
                end else if (pattern_index == pattern_len - 1) begin
                    next_state = COMPLETE;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
                done = 1;
            end
            NOT_FOUND: begin
                next_state = IDLE;
                done = 1;
                match_found = 0;
                start_pos = 15;
                end_pos = 15;
            end
        endcase
    end

endmodule