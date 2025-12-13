module adverb_finder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [511:0] text,        // 64 ASCII characters, text[511:504] is char0
    output reg  [5:0]  start_pos,
    output reg  [5:0]  end_pos,
    output reg  [127:0] found_word,  // up to 16 chars, left aligned, zero-padded
    output reg         done
);

    // FSM states
    typedef enum logic [1:0] {
        S_IDLE  = 2'b00,
        S_SCAN  = 2'b01,
        S_DONE  = 2'b10
    } state_t;

    state_t state, next_state;

    // Position counter: 0..63
    reg [5:0] pos;

    // Track whether we are currently inside a word
    reg        in_word;

    // Current word tracking
    reg [5:0]  word_start_pos;      // start index of current word
    reg [5:0]  word_end_pos;        // end index of current word (updated as we go)
    reg [3:0]  word_len;            // saturates at 16 for buffering
    reg [7:0]  last_char;           // last character of current word
    reg [7:0]  second_last_char;    // second last character of current word
    reg [127:0] word_buf;           // shift-left loaded, char0 at [127:120]

    // Result registers (latched when match found)
    reg        match_found;
    reg [5:0]  match_start_pos;
    reg [5:0]  match_end_pos;
    reg [127:0] match_word;

    // Helper: get character at index idx (0..63)
    function automatic [7:0] get_char(input [511:0] t, input [5:0] idx);
        // char0 (leftmost) is bits [511:504]
        get_char = t[511 - idx*8 -: 8];
    endfunction

    // Helper: determine if a character is a word character: [A-Za-z]
    function automatic is_word_char(input [7:0] c);
        if ((c >= 8'h41 && c <= 8'h5A) || (c >= 8'h61 && c <= 8'h7A))
            is_word_char = 1'b1;
        else
            is_word_char = 1'b0;
    endfunction

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            pos             <= 6'd0;
            in_word         <= 1'b0;
            word_start_pos  <= 6'd0;
            word_end_pos    <= 6'd0;
            word_len        <= 4'd0;
            last_char       <= 8'd0;
            second_last_char<= 8'd0;
            word_buf        <= 128'd0;
            match_found     <= 1'b0;
            match_start_pos <= 6'd0;
            match_end_pos   <= 6'd0;
            match_word      <= 128'd0;
            start_pos       <= 6'd0;
            end_pos         <= 6'd0;
            found_word      <= 128'd0;
            done            <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done        <= 1'b0;
                    match_found <= 1'b0;
                    if (start) begin
                        pos             <= 6'd0;
                        in_word         <= 1'b0;
                        word_len        <= 4'd0;
                        word_buf        <= 128'd0;
                        last_char       <= 8'd0;
                        second_last_char<= 8'd0;
                        match_word      <= 128'd0;
                        match_start_pos <= 6'd0;
                        match_end_pos   <= 6'd0;
                    end
                end

                S_SCAN: begin
                    if (!match_found && pos < 6'd64) begin
                        // Fetch current character
                        reg [7:0] c;
                        reg       is_word;
                        c       = get_char(text, pos);
                        is_word = is_word_char(c);

                        if (!in_word && is_word) begin
                            // Start of a new word
                            in_word         <= 1'b1;
                            word_start_pos  <= pos;
                            word_end_pos    <= pos;
                            word_len        <= 4'd1;
                            second_last_char<= 8'd0;
                            last_char       <= c;
                            // Insert first char into MSB position, rest zero
                            word_buf        <= {c, 120'd0};
                        end else if (in_word && is_word) begin
                            // Continuation of current word
                            in_word      <= 1'b1;
                            word_end_pos <= pos;
                            // Update length up to 16 for buffer management
                            if (word_len < 4'd15) begin
                                word_len <= word_len + 4'd1;
                            end else begin
                                // At 16 or more: keep at 16 (saturate)
                                word_len <= 4'd15;
                            end
                            // Track last two characters for 'ly' check
                            second_last_char <= last_char;
                            last_char        <= c;
                            // Shift buffer left by 8 and append new char at LSB
                            word_buf <= {word_buf[119:0], c};
                        end else if (in_word && !is_word) begin
                            // End of word: check for 'ly'
                            // At word end, last_char is final char, second_last_char is previous
                            if (second_last_char == 8'h6C && last_char == 8'h79 && !match_found) begin
                                match_found     <= 1'b1;
                                match_start_pos <= word_start_pos;
                                match_end_pos   <= word_end_pos;
                                match_word      <= word_buf;
                            end
                            // Exit word
                            in_word         <= 1'b0;
                            word_len        <= 4'd0;
                            second_last_char<= 8'd0;
                            last_char       <= 8'd0;
                            word_buf        <= 128'd0;
                        end

                        // Advance position
                        pos <= pos + 6'd1;
                    end else if (!match_found && pos == 6'd64) begin
                        // Reached after last character: if we were in a word, close it
                        if (in_word) begin
                            if (second_last_char == 8'h6C && last_char == 8'h79 && !match_found) begin
                                match_found     <= 1'b1;
                                match_start_pos <= word_start_pos;
                                match_end_pos   <= word_end_pos;
                                match_word      <= word_buf;
                            end
                        end
                        in_word         <= 1'b0;
                        word_len        <= 4'd0;
                        second_last_char<= 8'd0;
                        last_char       <= 8'd0;
                        word_buf        <= 128'd0;
                    end

                    // Latch outputs when match_found transitions or when scanning completes
                    if (match_found) begin
                        start_pos  <= match_start_pos;
                        end_pos    <= match_end_pos;
                        found_word <= match_word;
                    end else if (pos == 6'd64) begin
                        // No match: keep outputs cleared
                        start_pos  <= 6'd0;
                        end_pos    <= 6'd0;
                        found_word <= 128'd0;
                    end

                    // done is asserted in S_DONE
                    done <= 1'b0;
                end

                S_DONE: begin
                    // Hold results and done until next start or reset
                    done <= 1'b1;
                    if (start) begin
                        // If a new start comes, prepare for next scan
                        done            <= 1'b0;
                        match_found     <= 1'b0;
                        pos             <= 6'd0;
                        in_word         <= 1'b0;
                        word_len        <= 4'd0;
                        word_buf        <= 128'd0;
                        second_last_char<= 8'd0;
                        last_char       <= 8'd0;
                        // Outputs will be updated during next scan
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_SCAN;
            end
            S_SCAN: begin
                // Early termination if match_found
                if (match_found) begin
                    next_state = S_DONE;
                end else if (pos == 6'd64) begin
                    // Completed scanning all characters
                    next_state = S_DONE;
                end
            end
            S_DONE: begin
                if (start)
                    next_state = S_SCAN;
            end
            default: next_state = S_IDLE;
        endcase
    end

endmodule