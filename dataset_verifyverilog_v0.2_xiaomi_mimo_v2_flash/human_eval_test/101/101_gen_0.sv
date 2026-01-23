module words_string_splitter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg [7:0] words [0:7][0:7],
    output reg [2:0] word_count,
    output reg done,
    output reg error
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SKIP_DELIM = 3'b001;
    localparam READ_WORD = 3'b010;
    localparam CHECK_DELIM = 3'b011;
    localparam DONE = 3'b100;
    localparam ERROR = 3'b101;

    reg [2:0] state, next_state;
    reg [2:0] w_ptr; // word index (0-7)
    reg [2:0] c_ptr; // char index within word (0-7)
    reg [2:0] w_ptr_next;
    reg [2:0] c_ptr_next;
    reg [2:0] word_count_next;
    reg done_next, error_next;
    reg [7:0] words_next [0:7][0:7];
    
    // Helper signals
    wire is_delim;
    assign is_delim = (char_in == 8'h20) || (char_in == 8'h2C);

    integer i, j;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            word_count <= 3'b0;
            done <= 1'b0;
            error <= 1'b0;
            w_ptr <= 3'b0;
            c_ptr <= 3'b0;
            // Reset words array
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    words[i][j] <= 8'h00;
                end
            end
        end else begin
            state <= next_state;
            word_count <= word_count_next;
            done <= done_next;
            error <= error_next;
            w_ptr <= w_ptr_next;
            c_ptr <= c_ptr_next;
            words <= words_next;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        w_ptr_next = w_ptr;
        c_ptr_next = c_ptr;
        word_count_next = word_count;
        done_next = done;
        error_next = error;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                words_next[i][j] = words[i][j];
            end
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SKIP_DELIM;
                    // Reset counters
                    w_ptr_next = 3'b0;
                    c_ptr_next = 3'b0;
                    word_count_next = 3'b0;
                    done_next = 1'b0;
                    error_next = 1'b0;
                    // Clear words (optional but good for clean slate)
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            words_next[i][j] = 8'h00;
                        end
                    end
                end
            end

            SKIP_DELIM: begin
                if (valid_in) begin
                    if (char_in == 8'h00) begin // Null terminator
                        next_state = DONE;
                    end else if (is_delim) begin
                        next_state = SKIP_DELIM; // Ignore
                    end else begin
                        if (w_ptr < 8) begin
                            words_next[w_ptr][0] = char_in;
                            c_ptr_next = 3'b1; // Point to next slot
                            next_state = READ_WORD;
                        end else begin
                            // Too many words
                            next_state = ERROR;
                        end
                    end
                end
            end

            READ_WORD: begin
                if (valid_in) begin
                    if (char_in == 8'h00) begin // Null terminator inside word or after
                        // Treat as word end and done
                        word_count_next = w_ptr + 1;
                        next_state = DONE;
                    end else if (is_delim) begin
                        // Use CHECK_DELIM state as requested
                        word_count_next = w_ptr + 1;
                        w_ptr_next = w_ptr + 1;
                        c_ptr_next = 0;
                        next_state = CHECK_DELIM;
                    end else begin
                        if (c_ptr < 8) begin
                            words_next[w_ptr][c_ptr] = char_in;
                            c_ptr_next = c_ptr + 1;
                            next_state = READ_WORD;
                        end else begin
                            next_state = ERROR;
                        end
                    end
                end
            end

            CHECK_DELIM: begin
                // We have just finished a word and consumed a delimiter (conceptually).
                // Now we wait for the next valid char.
                if (valid_in) begin
                    if (char_in == 8'h00) begin
                        next_state = DONE;
                    end else if (is_delim) begin
                        next_state = CHECK_DELIM; // Ignore multiple delimiters
                    end else begin // New word start
                        // w_ptr was incremented in READ_WORD->CHECK_DELIM transition
                        if (w_ptr < 8) begin
                            words_next[w_ptr][0] = char_in;
                            c_ptr_next = 1;
                            next_state = READ_WORD;
                        end else begin
                            // w_ptr is 8 (0-7 used, 8 is out of bounds)
                            next_state = ERROR;
                        end
                    end
                end
            end

            DONE: begin
                if (start) begin
                    next_state = SKIP_DELIM;
                    w_ptr_next = 0;
                    c_ptr_next = 0;
                    word_count_next = 0;
                    done_next = 0;
                    error_next = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            words_next[i][j] = 0;
                        end
                    end
                end
            end

            ERROR: begin
                if (start) begin // Allow recovery via start
                    next_state = SKIP_DELIM;
                    w_ptr_next = 0;
                    c_ptr_next = 0;
                    word_count_next = 0;
                    done_next = 0;
                    error_next = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            words_next[i][j] = 0;
                        end
                    end
                end
            end
        endcase
    end

endmodule