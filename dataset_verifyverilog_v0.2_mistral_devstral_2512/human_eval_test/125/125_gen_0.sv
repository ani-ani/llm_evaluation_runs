module split_words (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] str_len,
    output reg [127:0] word0,
    output reg [127:0] word1,
    output reg [127:0] word2,
    output reg [127:0] word3,
    output reg [3:0] result_count,
    output reg result_is_count,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        READ_CHAR,
        PROCESS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] char_buffer [0:15]; // Buffer for input characters
    reg [3:0] char_index; // Current character index
    reg [3:0] word_index; // Current word index
    reg [3:0] word_start; // Start index of current word
    reg delimiter_found; // Indicates if delimiter was found
    reg is_space_delimiter; // Indicates if delimiter is space
    reg [3:0] odd_lowercase_count; // Count of odd lowercase letters

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            char_index <= 0;
            word_index <= 0;
            word_start <= 0;
            delimiter_found <= 0;
            is_space_delimiter <= 0;
            odd_lowercase_count <= 0;
            result_count <= 0;
            result_is_count <= 0;
            done <= 0;
            word0 <= 0;
            word1 <= 0;
            word2 <= 0;
            word3 <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // State transition logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = READ_CHAR;
                    char_index = 0;
                    word_index = 0;
                    word_start = 0;
                    delimiter_found = 0;
                    is_space_delimiter = 0;
                    odd_lowercase_count = 0;
                    result_count = 0;
                    result_is_count = 0;
                    done = 0;
                    word0 = 0;
                    word1 = 0;
                    word2 = 0;
                    word3 = 0;
                end
            end
            READ_CHAR: begin
                if (char_index == str_len) begin
                    next_state = PROCESS;
                end else begin
                    char_buffer[char_index] = char_in;
                    char_index = char_index + 1;
                end
            end
            PROCESS: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Processing logic
    always @(posedge clk) begin
        if (current_state == PROCESS) begin
            // Check for delimiters
            for (int i = 0; i < str_len; i = i + 1) begin
                if (!delimiter_found && (char_buffer[i] == 8'h20 || char_buffer[i] == 8'h2C)) begin
                    delimiter_found = 1;
                    is_space_delimiter = (char_buffer[i] == 8'h20);
                end
            end

            // Split or count based on delimiter
            if (delimiter_found) begin
                result_is_count = 0;
                word_index = 0;
                word_start = 0;
                for (int i = 0; i < str_len; i = i + 1) begin
                    if (char_buffer[i] == (is_space_delimiter ? 8'h20 : 8'h2C)) begin
                        // Copy word to output
                        for (int j = 0; j < 16; j = j + 1) begin
                            if (j < (i - word_start)) begin
                                case (word_index)
                                    0: word0[(j << 3) +: 8] = char_buffer[word_start + j];
                                    1: word1[(j << 3) +: 8] = char_buffer[word_start + j];
                                    2: word2[(j << 3) +: 8] = char_buffer[word_start + j];
                                    3: word3[(j << 3) +: 8] = char_buffer[word_start + j];
                                endcase
                            end else begin
                                case (word_index)
                                    0: word0[(j << 3) +: 8] = 8'h00;
                                    1: word1[(j << 3) +: 8] = 8'h00;
                                    2: word2[(j << 3) +: 8] = 8'h00;
                                    3: word3[(j << 3) +: 8] = 8'h00;
                                endcase
                            end
                        end
                        word_index = word_index + 1;
                        word_start = i + 1;
                    end
                end
                // Copy last word
                if (word_index < 4) begin
                    for (int j = 0; j < 16; j = j + 1) begin
                        if (j < (str_len - word_start)) begin
                            case (word_index)
                                0: word0[(j << 3) +: 8] = char_buffer[word_start + j];
                                1: word1[(j << 3) +: 8] = char_buffer[word_start + j];
                                2: word2[(j << 3) +: 8] = char_buffer[word_start + j];
                                3: word3[(j << 3) +: 8] = char_buffer[word_start + j];
                            endcase
                        end else begin
                            case (word_index)
                                0: word0[(j << 3) +: 8] = 8'h00;
                                1: word1[(j << 3) +: 8] = 8'h00;
                                2: word2[(j << 3) +: 8] = 8'h00;
                                3: word3[(j << 3) +: 8] = 8'h00;
                            endcase
                        end
                    end
                end
            end else begin
                result_is_count = 1;
                odd_lowercase_count = 0;
                for (int i = 0; i < str_len; i = i + 1) begin
                    if (char_buffer[i] >= 8'h61 && char_buffer[i] <= 8'h7A) begin
                        if ((char_buffer[i] - 8'h61) % 2 == 1) begin
                            odd_lowercase_count = odd_lowercase_count + 1;
                        end
                    end
                end
                result_count = odd_lowercase_count;
            end
            done = 1;
        end
    end

endmodule