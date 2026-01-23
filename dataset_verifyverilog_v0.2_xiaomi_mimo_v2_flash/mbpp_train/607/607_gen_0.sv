module string_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] text [0:7],
    input [7:0] pattern [0:3],
    input [2:0] pattern_length,
    output reg [2:0] start_index,
    output reg [2:0] end_index,
    output reg found,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam COMPARE = 3'b001;
    localparam SLIDE = 3'b010;
    localparam FOUND = 3'b011;
    localparam NOT_FOUND = 3'b100;

    reg [2:0] state;
    reg [2:0] current_pos;
    reg [2:0] char_idx;
    reg [2:0] saved_start_pos;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_index <= 0;
            end_index <= 0;
            found <= 0;
            done <= 0;
            current_pos <= 0;
            char_idx <= 0;
            saved_start_pos <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    found <= 0;
                    if (start) begin
                        current_pos <= 0;
                        saved_start_pos <= 0;
                        if (pattern_length > 0 && pattern_length <= 4) begin
                            state <= COMPARE;
                        end else begin
                            // Invalid pattern length, treat as not found
                            state <= NOT_FOUND;
                        end
                    end
                end

                COMPARE: begin
                    // Check if we can fit the pattern at current_pos
                    if (current_pos + pattern_length > 8) begin
                        // Cannot fit, slide is handled in SLIDE state, but here we just end
                        state <= NOT_FOUND;
                    end else begin
                        // Compare pattern[char_idx] with text[current_pos + char_idx]
                        if (char_idx < pattern_length) begin
                            if (text[current_pos + char_idx] == pattern[char_idx]) begin
                                char_idx <= char_idx + 1;
                                // Stay in COMPARE if more chars to match
                                if (char_idx + 1 == pattern_length) begin
                                    // Match complete
                                    state <= FOUND;
                                end else begin
                                    state <= COMPARE;
                                end
                            end else begin
                                // Mismatch, slide to next position
                                char_idx <= 0;
                                state <= SLIDE;
                            end
                        end else begin
                            // Should not reach here, but reset char_idx and slide
                            char_idx <= 0;
                            state <= SLIDE;
                        end
                    end
                end

                SLIDE: begin
                    char_idx <= 0;
                    if (current_pos + 1 + pattern_length > 8) begin
                        state <= NOT_FOUND;
                    end else begin
                        current_pos <= current_pos + 1;
                        state <= COMPARE;
                    end
                end

                FOUND: begin
                    start_index <= saved_start_pos;
                    end_index <= saved_start_pos + pattern_length;
                    found <= 1;
                    done <= 1;
                    state <= IDLE;
                end

                NOT_FOUND: begin
                    start_index <= 0;
                    end_index <= 0;
                    found <= 0;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule