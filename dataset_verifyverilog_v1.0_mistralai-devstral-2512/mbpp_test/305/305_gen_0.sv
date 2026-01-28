module StartWithP(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] words_in [0:7],
    output reg [127:0] word1_out,
    output reg [127:0] word2_out,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SCAN_STR  = 3'd1;
    localparam [2:0] PARSE_WORD = 3'd2;
    localparam [2:0] CHECK_P   = 3'd3;
    localparam [2:0] FOUND     = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] str_idx;           // Current string index (0-7)
    reg [3:0] char_idx;          // Current character index (0-15)
    reg [3:0] word_idx;          // Current word index (0-7)
    reg [7:0] current_char;     // Current character being processed
    reg [127:0] current_word;    // Current word being parsed
    reg [3:0] word_char_idx;     // Character index within current word
    reg found_first_word;       // Flag indicating first 'P' word found
    reg [127:0] first_word;      // Storage for first matching word
    reg [7:0] prev_char;         // Previous character for space detection
    reg [7:0] space_char = 8'd32; // ASCII space
    reg [7:0] p_char = 8'd80;    // ASCII 'P'
    reg [7:0] null_char = 8'd0;  // Null terminator
    reg [7:0] zero_char = 8'd0;   // Zero for padding

    // Cycle counter for timeout
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCAN_STR;
                end else begin
                    next_state = IDLE;
                end
            end

            SCAN_STR: begin
                if (str_idx == 3'd7 && char_idx == 4'd15) begin
                    next_state = DONE_STATE;
                end else if (char_idx == 4'd15) begin
                    next_state = SCAN_STR;
                end else begin
                    next_state = PARSE_WORD;
                end
            end

            PARSE_WORD: begin
                if (current_char == space_char || char_idx == 4'd15) begin
                    next_state = CHECK_P;
                end else begin
                    next_state = PARSE_WORD;
                end
            end

            CHECK_P: begin
                if (found_first_word && current_word[127:120] == p_char) begin
                    next_state = FOUND;
                end else if (current_word[127:120] == p_char) begin
                    next_state = SCAN_STR;
                end else begin
                    next_state = SCAN_STR;
                end
            end

            FOUND: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            str_idx <= 3'd0;
            char_idx <= 4'd0;
            word_idx <= 4'd0;
            word_char_idx <= 4'd0;
            current_char <= 8'd0;
            current_word <= 128'd0;
            found_first_word <= 1'b0;
            first_word <= 128'd0;
            prev_char <= 8'd0;
            word1_out <= 128'd0;
            word2_out <= 128'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                end

                SCAN_STR: begin
                    if (str_idx == 3'd7 && char_idx == 4'd15) begin
                        // No match found
                        done <= 1'b1;
                        valid <= 1'b0;
                    end else if (char_idx == 4'd15) begin
                        str_idx <= str_idx + 3'd1;
                        char_idx <= 4'd0;
                        word_idx <= 4'd0;
                        word_char_idx <= 4'd0;
                        current_word <= 128'd0;
                        prev_char <= 8'd0;
                    end else begin
                        char_idx <= char_idx + 4'd1;
                        current_char <= words_in[str_idx][(char_idx << 3) +: 8];
                        prev_char <= (char_idx == 4'd0) ? 8'd0 : words_in[str_idx][((char_idx - 4'd1) << 3) +: 8];
                    end
                end

                PARSE_WORD: begin
                    if (current_char != space_char && char_idx != 4'd15) begin
                        current_word[(15 - word_char_idx) << 3 +: 8] <= current_char;
                        word_char_idx <= word_char_idx + 4'd1;
                        char_idx <= char_idx + 4'd1;
                    end
                end

                CHECK_P: begin
                    if (found_first_word && current_word[127:120] == p_char) begin
                        // Found second word
                        word2_out <= current_word;
                        valid <= 1'b1;
                        done <= 1'b1;
                        found_first_word <= 1'b0;
                    end else if (current_word[127:120] == p_char) begin
                        // Found first word
                        first_word <= current_word;
                        found_first_word <= 1'b1;
                        current_word <= 128'd0;
                        word_char_idx <= 4'd0;
                        char_idx <= char_idx + 4'd1;
                    end else begin
                        // Not a match, reset word parsing
                        current_word <= 128'd0;
                        word_char_idx <= 4'd0;
                        char_idx <= char_idx + 4'd1;
                    end
                end

                FOUND: begin
                    word1_out <= first_word;
                    valid <= 1'b1;
                    done <= 1'b1;
                    found_first_word <= 1'b0;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) begin
                        valid <= 1'b0;
                    end
                end

                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Null-terminate output words if shorter than 16 characters
    always @(*) begin
        if (word1_out[127:120] == null_char) begin
            // Already null-terminated or empty
        end else begin
            // Find first null in word1_out and pad with zeros
            for (integer i = 0; i < 16; i = i + 1) begin
                if (word1_out[(15 - i) << 3 +: 8] == null_char) begin
                    // Found null, no need to pad
                end else if (i == 15 || word1_out[((15 - i) - 1) << 3 +: 8] == null_char) begin
                    word1_out[(15 - i) << 3 +: 8] <= null_char;
                end
            end
        end
    end

    always @(*) begin
        if (word2_out[127:120] == null_char) begin
            // Already null-terminated or empty
        end else begin
            // Find first null in word2_out and pad with zeros
            for (integer i = 0; i < 16; i = i + 1) begin
                if (word2_out[(15 - i) << 3 +: 8] == null_char) begin
                    // Found null, no need to pad
                end else if (i == 15 || word2_out[((15 - i) - 1) << 3 +: 8] == null_char) begin
                    word2_out[(15 - i) << 3 +: 8] <= null_char;
                end
            end
        end
    end

endmodule