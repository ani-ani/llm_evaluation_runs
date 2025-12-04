module reverse_words(
    input clk,
    input rst_n,
    input start,
    input [127:0] str,
    output reg [127:0] reversed_str,
    output reg done
);

    typedef enum logic [2:0] {
        IDLE,
        PARSE,
        STORE_PENDING,
        BUILD,
        PAD,
        DONE
    } state_t;

    state_t state, next_state;
    reg [1:0] word_count;
    reg [7:0] word_buffer [0:3][0:7]; // [word][char]
    reg [2:0] word_lengths [0:3];
    reg [3:0] char_pos;
    reg in_word;
    reg [2:0] current_word_len;
    reg has_pending_word;

    reg [3:0] out_pos;
    reg [1:0] build_word_ptr;
    reg [2:0] build_char_ptr;
    reg build_add_space;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            reversed_str <= '0;
            done <= 0;
            word_count <= 0;
            char_pos <= 0;
            in_word <= 0;
            current_word_len <= 0;
            has_pending_word <= 0;
            out_pos <= 0;
            build_word_ptr <= 0;
            build_char_ptr <= 0;
            build_add_space <= 0;
            for (int i = 0; i < 4; i++) begin
                for (int j = 0; j < 8; j++) word_buffer[i][j] <= '0;
                word_lengths[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        char_pos <= 0;
                        word_count <= 0;
                        in_word <= 0;
                        current_word_len <= 0;
                        reversed_str <= '0;
                        state <= PARSE;
                    end
                end

                PARSE: begin
                    if (char_pos < 16 && word_count <= 3) begin
                        automatic logic [7:0] current_char = str[char_pos*8 +:8];
                        if (current_char == " ") begin
                            if (in_word) begin
                                word_lengths[word_count] <= current_word_len;
                                word_count <= word_count + 1;
                                in_word <= 0;
                                current_word_len <= 0;
                            end
                        end else begin
                            if (!in_word) begin
                                in_word <= 1;
                                current_word_len <= 1;
                                word_buffer[word_count][0] <= current_char;
                            end else if (current_word_len < 8) begin
                                word_buffer[word_count][current_word_len] <= current_char;
                                current_word_len <= current_word_len + 1;
                            end else if (word_count < 3) begin
                                word_lengths[word_count] <= 3'd8;
                                word_count <= word_count + 1;
                                current_word_len <= 1;
                                word_buffer[word_count][0] <= current_char;
                            end
                        end
                    end
                    if (char_pos == 15 || (word_count == 3 && current_word_len == 8)) begin
                        if (in_word) has_pending_word <= 1;
                        next_state <= STORE_PENDING;
                    end else begin
                        char_pos <= char_pos + 1;
                    end
                end

                STORE_PENDING: begin
                    if (has_pending_word) begin
                        word_lengths[word_count] <= current_word_len;
                        word_count <= word_count + 1;
                        has_pending_word <= 0;
                    end
                    state <= BUILD;
                    build_word_ptr <= word_count > 0 ? word_count - 1 : 0;
                    build_char_ptr <= 0;
                    out_pos <= 0;
                    build_add_space <= 0;
                end

                BUILD: begin
                    if (out_pos < 16) begin
                        if (build_add_space) begin
                            reversed_str[out_pos*8 +:8] <= " ";
                            out_pos <= out_pos + 1;
                            build_add_space <= 0;
                            build_char_ptr <= 0;
                            if (build_word_ptr > 0) build_word_ptr <= build_word_ptr - 1;
                        end else if (word_count != 0) begin
                            if (build_char_ptr < word_lengths[build_word_ptr]) begin
                                reversed_str[out_pos*8 +:8] <= word_buffer[build_word_ptr][build_char_ptr];
                                build_char_ptr <= build_char_ptr + 1;
                                out_pos <= out_pos + 1;
                                if (build_char_ptr == word_lengths[build_word_ptr]-1 &&
                                    build_word_ptr != 0) build_add_space <= 1;
                            end else if (build_word_ptr > 0) begin
                                build_char_ptr <= 0;
                                build_word_ptr <= build_word_ptr - 1;
                                build_add_space <= 1;
                            end
                        end else begin // No words
                            state <= PAD;
                        end
                    end else begin
                        state <= PAD;
                    end
                    if (out_pos == 15) state <= PAD;
                end

                PAD: begin
                    if (out_pos < 16) begin
                        reversed_str[out_pos*8 +:8] <= " ";
                        out_pos <= out_pos + 1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    always_comb begin
        next_state = state;
        if (state == PARSE) begin
            if (char_pos == 15 || (word_count == 3 && current_word_len == 8))
                next_state = STORE_PENDING;
        end
    end

endmodule