module text_decipher (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [7:0] dict_word [0:7][0:7],
    input [3:0] dict_size,
    input [3:0] input_length,
    output reg [7:0] result [0:31],
    output reg [1:0] status,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD_DICT,
        LOAD_STRING,
        PROCESS_DP,
        BUILD_OUTPUT,
        DONE
    } state_t;

    state_t state;
    reg [3:0] dict_idx;
    reg [3:0] str_idx;
    reg [3:0] dp_idx;
    reg [3:0] word_idx;
    reg [3:0] char_idx;
    reg [3:0] output_idx;
    reg [3:0] path_idx;
    reg [3:0] temp_idx1;
    reg [3:0] temp_idx2;
    reg [3:0] sort_idx1;
    reg [3:0] sort_idx2;
    reg [3:0] sort_pass;

    reg [7:0] input_string [0:15];
    reg [7:0] sorted_middle [0:7];
    reg [7:0] temp_sorted [0:7];
    reg [7:0] temp_word [0:7];

    reg [15:0] dp [0:16];
    reg [3:0] parent [0:16];
    reg [3:0] word_used [0:16];

    reg [7:0] current_word [0:7];
    reg [3:0] current_word_len;
    reg [3:0] current_pos;
    reg [3:0] current_start;

    reg [7:0] temp_char;
    reg [7:0] temp_char2;

    reg match;
    reg unique;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            dict_idx <= 0;
            str_idx <= 0;
            dp_idx <= 0;
            word_idx <= 0;
            char_idx <= 0;
            output_idx <= 0;
            path_idx <= 0;
            temp_idx1 <= 0;
            temp_idx2 <= 0;
            sort_idx1 <= 0;
            sort_idx2 <= 0;
            sort_pass <= 0;

            for (int i = 0; i < 16; i = i + 1) begin
                input_string[i] <= 0;
                dp[i] <= 0;
                parent[i] <= 0;
                word_used[i] <= 0;
            end

            for (int i = 0; i < 8; i = i + 1) begin
                sorted_middle[i] <= 0;
                temp_sorted[i] <= 0;
                temp_word[i] <= 0;
            end

            current_word_len <= 0;
            current_pos <= 0;
            current_start <= 0;
            temp_char <= 0;
            temp_char2 <= 0;
            match <= 0;
            unique <= 0;

            for (int i = 0; i < 32; i = i + 1) begin
                result[i] <= 0;
            end

            status <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_DICT;
                        dict_idx <= 0;
                    end
                end

                LOAD_DICT: begin
                    if (dict_idx < dict_size) begin
                        // Store dictionary word (already provided in dict_word)
                        dict_idx <= dict_idx + 1;
                    end else begin
                        state <= LOAD_STRING;
                        str_idx <= 0;
                    end
                end

                LOAD_STRING: begin
                    if (str_idx < input_length) begin
                        input_string[str_idx] <= char_in;
                        str_idx <= str_idx + 1;
                    end else begin
                        state <= PROCESS_DP;
                        dp_idx <= 0;
                        dp[0] <= 1;
                        parent[0] <= 0;
                    end
                end

                PROCESS_DP: begin
                    if (dp_idx < input_length) begin
                        dp[dp_idx + 1] <= 0;
                        word_idx <= 0;
                        state <= PROCESS_DP_WORD;
                    end else begin
                        state <= BUILD_OUTPUT;
                        path_idx <= input_length;
                        output_idx <= 0;

                        if (dp[input_length] == 0) begin
                            status <= 2; // impossible
                        end else if (dp[input_length] > 1) begin
                            status <= 3; // ambiguous
                        end else begin
                            status <= 1; // done_unique
                        end
                    end
                end

                PROCESS_DP_WORD: begin
                    if (word_idx < dict_size) begin
                        // Get current word from dictionary
                        current_word_len <= 0;
                        for (int i = 0; i < 8; i = i + 1) begin
                            temp_char <= dict_word[word_idx][i];
                            if (temp_char != 8'hFF) begin
                                current_word[i] <= temp_char;
                                current_word_len <= current_word_len + 1;
                            end else begin
                                current_word[i] <= 0;
                            end
                        end

                        // Check if word can fit at current position
                        if (dp_idx + 1 >= current_word_len) begin
                            current_start <= dp_idx + 1 - current_word_len;
                            current_pos <= current_start;

                            // Check first and last characters
                            if ((current_word[0] == input_string[current_start]) &&
                                (current_word[current_word_len - 1] == input_string[current_start + current_word_len - 1])) begin

                                // Sort middle characters of dictionary word
                                for (int i = 0; i < 8; i = i + 1) begin
                                    if (i < current_word_len - 2) begin
                                        temp_sorted[i] <= current_word[i + 1];
                                    end else begin
                                        temp_sorted[i] <= 0;
                                    end
                                end

                                // Bubble sort for dictionary word middle
                                sort_pass <= 0;
                                state <= SORT_DICT_MIDDLE;
                            end else begin
                                word_idx <= word_idx + 1;
                            end
                        end else begin
                            word_idx <= word_idx + 1;
                        end
                    end else begin
                        dp_idx <= dp_idx + 1;
                        state <= PROCESS_DP;
                    end
                end

                SORT_DICT_MIDDLE: begin
                    if (sort_pass < current_word_len - 2) begin
                        sort_idx1 <= 0;
                        state <= SORT_DICT_INNER;
                    end else begin
                        // Sort middle characters of input substring
                        for (int i = 0; i < 8; i = i + 1) begin
                            if (i < current_word_len - 2) begin
                                sorted_middle[i] <= input_string[current_start + 1 + i];
                            end else begin
                                sorted_middle[i] <= 0;
                            end
                        end

                        sort_pass <= 0;
                        state <= SORT_INPUT_MIDDLE;
                    end
                end

                SORT_DICT_INNER: begin
                    if (sort_idx1 < (current_word_len - 3 - sort_pass)) begin
                        if (temp_sorted[sort_idx1] > temp_sorted[sort_idx1 + 1]) begin
                            temp_char <= temp_sorted[sort_idx1];
                            temp_sorted[sort_idx1] <= temp_sorted[sort_idx1 + 1];
                            temp_sorted[sort_idx1 + 1] <= temp_char;
                        end
                        sort_idx1 <= sort_idx1 + 1;
                    end else begin
                        sort_pass <= sort_pass + 1;
                        state <= SORT_DICT_MIDDLE;
                    end
                end

                SORT_INPUT_MIDDLE: begin
                    if (sort_pass < current_word_len - 2) begin
                        sort_idx1 <= 0;
                        state <= SORT_INPUT_INNER;
                    end else begin
                        // Compare sorted middle characters
                        match <= 1;
                        for (int i = 0; i < current_word_len - 2; i = i + 1) begin
                            if (temp_sorted[i] != sorted_middle[i]) begin
                                match <= 0;
                            end
                        end

                        if (match) begin
                            dp[dp_idx + 1] <= dp[dp_idx + 1] + dp[current_start];
                            parent[dp_idx + 1] <= current_start;
                            word_used[dp_idx + 1] <= word_idx;
                        end

                        word_idx <= word_idx + 1;
                        state <= PROCESS_DP_WORD;
                    end
                end

                SORT_INPUT_INNER: begin
                    if (sort_idx1 < (current_word_len - 3 - sort_pass)) begin
                        if (sorted_middle[sort_idx1] > sorted_middle[sort_idx1 + 1]) begin
                            temp_char <= sorted_middle[sort_idx1];
                            sorted_middle[sort_idx1] <= sorted_middle[sort_idx1 + 1];
                            sorted_middle[sort_idx1 + 1] <= temp_char;
                        end
                        sort_idx1 <= sort_idx1 + 1;
                    end else begin
                        sort_pass <= sort_pass + 1;
                        state <= SORT_INPUT_MIDDLE;
                    end
                end

                BUILD_OUTPUT: begin
                    if (path_idx > 0) begin
                        // Get the word used at this position
                        current_word_len <= 0;
                        for (int i = 0; i < 8; i = i + 1) begin
                            temp_char <= dict_word[word_used[path_idx]][i];
                            if (temp_char != 8'hFF) begin
                                current_word[i] <= temp_char;
                                current_word_len <= current_word_len + 1;
                            end else begin
                                current_word[i] <= 0;
                            end
                        end

                        // Copy word to result
                        for (int i = 0; i < current_word_len; i = i + 1) begin
                            result[output_idx] <= current_word[i];
                            output_idx <= output_idx + 1;
                        end

                        // Add space if not the first word
                        if (path_idx != input_length) begin
                            result[output_idx] <= 8'h20; // space
                            output_idx <= output_idx + 1;
                        end

                        path_idx <= parent[path_idx];
                    end else begin
                        done <= 1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule