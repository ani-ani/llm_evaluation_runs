module word_consonant_filter(
    input  clk,
    input  rst_n,
    input  start,
    input  [511:0] string_data,
    input  [3:0] target_count,
    output reg [7:0] matched_words,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam RUN  = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;

    // Character index: 0..63 (64 characters)
    reg [5:0] char_index;

    // Word tracking
    reg [2:0] word_index;           // up to 8 words
    reg [3:0] consonant_count;      // per current word
    reg       in_word;              // currently inside a word

    // Latched inputs
    reg [511:0] string_data_reg;
    reg [3:0]  target_count_reg;

    // Current character and lowercase
    wire [7:0] curr_char;
    reg  [7:0] lower_char;

    assign curr_char = string_data_reg[511 - (char_index * 8) -: 8];

    // Lowercase conversion combinational
    always @* begin
        if (curr_char >= 8'h41 && curr_char <= 8'h5A)
            lower_char = curr_char + 8'h20;
        else
            lower_char = curr_char;
    end

    // Alphabetic check
    wire is_alpha;
    assign is_alpha = (lower_char >= "a" && lower_char <= "z");

    // Vowel check
    wire is_vowel;
    assign is_vowel = (lower_char == "a") || (lower_char == "e") ||
                      (lower_char == "i") || (lower_char == "o") ||
                      (lower_char == "u");

    // Space delimiter (word separator)
    wire is_space;
    assign is_space = (curr_char == 8'h20);

    // Consonant check: alphabetic and not vowel
    wire is_consonant;
    assign is_consonant = is_alpha && !is_vowel;

    // FSM state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM next state logic
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = RUN;
            end
            RUN: begin
                if (char_index == 6'd63)
                    next_state = DONE;
            end
            DONE: begin
                // Done is one-cycle pulse, then go back to IDLE
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main sequential logic
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            matched_words      <= 8'b0;
            done               <= 1'b0;
            char_index         <= 6'd0;
            word_index         <= 3'd0;
            consonant_count    <= 4'd0;
            in_word            <= 1'b0;
            string_data_reg    <= 512'd0;
            target_count_reg   <= 4'd0;
        end else begin
            done <= 1'b0; // default, asserted only in DONE state

            case (state)
                IDLE: begin
                    // Wait for start; clear outputs and counters when start asserted
                    if (start) begin
                        string_data_reg  <= string_data;
                        target_count_reg <= target_count;
                        matched_words    <= 8'b0;
                        char_index       <= 6'd0;
                        word_index       <= 3'd0;
                        consonant_count  <= 4'd0;
                        in_word          <= 1'b0;
                    end
                end

                RUN: begin
                    // Process one character per cycle

                    if (!is_space) begin
                        // Non-space character
                        if (!in_word) begin
                            // Start of a new word if we still have slots
                            if (word_index < 3'd8) begin
                                in_word         <= 1'b1;
                                consonant_count <= is_consonant ? 4'd1 : 4'd0;
                            end
                            // If word_index >= 8, ignore additional words
                        end else begin
                            // Inside a word, accumulate consonants if within word limit
                            if (word_index < 3'd8 && is_consonant) begin
                                // Saturation not required since target_count is 4-bit
                                consonant_count <= consonant_count + 4'd1;
                            end
                        end
                    end else begin
                        // Space character: possible word boundary
                        if (in_word) begin
                            // End of current word
                            if (word_index < 3'd8) begin
                                if (consonant_count == target_count_reg)
                                    matched_words[word_index] <= 1'b1;
                                else
                                    matched_words[word_index] <= matched_words[word_index];
                            end
                            in_word         <= 1'b0;
                            consonant_count <= 4'd0;
                            if (word_index < 3'd8)
                                word_index <= word_index + 3'd1;
                        end
                    end

                    // Advance character index
                    if (char_index < 6'd63) begin
                        char_index <= char_index + 6'd1;
                    end
                end

                DONE: begin
                    // Handle possible last word not terminated by space
                    if (in_word && word_index < 3'd8) begin
                        if (consonant_count == target_count_reg)
                            matched_words[word_index] <= 1'b1;
                    end
                    done        <= 1'b1;
                    in_word     <= 1'b0;
                    // Next state will go to IDLE on next cycle
                end

                default: ;
            endcase
        end
    end

endmodule