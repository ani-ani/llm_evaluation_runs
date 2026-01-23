module adverb_finder(
    input clk,
    input rst_n,
    input start,
    input [127:0] text,
    output reg [3:0] start_pos,
    output reg [3:0] end_pos,
    output reg found,
    output reg done
);

    // State encoding
    localparam IDLE    = 3'b000;
    localparam SCAN    = 3'b001;
    localparam CHECK_LY = 3'b010;
    localparam VERIFY  = 3'b011;
    localparam DONE    = 3'b100;

    reg [2:0] state;
    reg [3:0] pos;
    reg [3:0] word_start;
    reg [7:0] char_curr;
    reg [7:0] char_next;
    reg is_word_char_curr;
    reg is_word_char_next;
    reg match_found;

    // Helper function to check if character is alphanumeric (word char)
    // Simplified: A-Z (0x41-0x5A), a-z (0x61-0x7A), 0-9 (0x30-0x39)
    function automatic logic is_word_char(input [7:0] c);
        begin
            if ((c >= 8'h30 && c <= 8'h39) || 
                (c >= 8'h41 && c <= 8'h5A) || 
                (c >= 8'h61 && c <= 8'h7A))
                is_word_char = 1'b1;
            else
                is_word_char = 1'b0;
        end
    endfunction

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_pos <= 4'b0;
            end_pos <= 4'b0;
            found <= 1'b0;
            done <= 1'b0;
            pos <= 4'b0;
            word_start <= 4'b0;
            match_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    if (start) begin
                        state <= SCAN;
                        pos <= 4'b0;
                        word_start <= 4'b0;
                        match_found <= 1'b0;
                    end
                end

                SCAN: begin
                    // Extract current and next chars
                    char_curr = text[{pos, 3'b0} +: 8];
                    // Bounds check for next char to prevent out of range read on null pad
                    if (pos < 4'hF)
                        char_next = text[{pos, 3'b0} + 8 +: 8];
                    else
                        char_next = 8'h00;

                    is_word_char_curr = is_word_char(char_curr);
                    is_word_char_next = is_word_char(char_next);

                    // Logic: Detect end of word (curr is word, next is not)
                    // And check for 'l' at end of word
                    if (is_word_char_curr && !is_word_char_next && (char_curr == 8'h6C || char_curr == 8'h4C)) begin
                        // Potential adverb found (word ending in 'l')
                        // Need to verify next char is 'y'
                        state <= CHECK_LY;
                    end else begin
                        // Continue scanning
                        if (pos < 4'hF) begin
                            pos <= pos + 1;
                        end else begin
                            // End of string reached without match
                            state <= DONE;
                        end
                    end
                end

                CHECK_LY: begin
                    // We stopped at 'l' (pos). Next char should be 'y' (pos + 1)
                    char_next = text[{pos, 3'b0} + 8 +: 8];
                    if (char_next == 8'h79 || char_next == 8'h59) begin // 'y' or 'Y'
                        match_found <= 1'b1;
                        state <= VERIFY;
                    end else begin
                        // Not 'y', continue scanning from next position
                        state <= SCAN;
                        if (pos < 4'hF) begin
                            pos <= pos + 1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                VERIFY: begin
                    // Capture positions
                    // Word ends at pos (l). Next is pos+1 (y).
                    // Length calculation: (End - Start + 1)
                    // Start is word_start.
                    // End pos is pos + 1 (where 'y' is).
                    start_pos <= word_start;
                    end_pos <= pos + 1;
                    found <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
