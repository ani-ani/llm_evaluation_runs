module substitution_cipher_matcher (
    input clk,
    input rst_n,
    input start,
    input [127:0] encrypted_msg,
    input [63:0] fragment,
    input [4:0] msg_len,
    input [3:0] frag_len,
    output reg [127:0] result_string,
    output reg [4:0] result_pos,
    output reg [7:0] match_count,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        CHECK_POSITION,
        CHECK_MAPPING,
        COUNT_UPDATES,
        UPDATE_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [4:0] current_pos;
    reg [4:0] valid_pos_count;
    reg [4:0] last_valid_pos;
    reg [7:0] char_map [0:25]; // 'a'=0, 'b'=1, ..., 'z'=25
    reg [7:0] reverse_map [0:25];
    reg [7:0] frag_char, msg_char;
    reg [3:0] char_idx;
    reg [3:0] frag_idx;
    reg [3:0] msg_idx;
    reg mapping_valid;
    reg [4:0] pos_counter;
    reg [3:0] frag_len_reg;
    reg [4:0] msg_len_reg;

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result_pos <= 0;
            match_count <= 0;
            result_string <= 0;
            current_pos <= 0;
            valid_pos_count <= 0;
            last_valid_pos <= 0;
            mapping_valid <= 1;
            char_idx <= 0;
            frag_idx <= 0;
            msg_idx <= 0;
            pos_counter <= 0;
            frag_len_reg <= 0;
            msg_len_reg <= 0;
            for (int i = 0; i < 26; i++) begin
                char_map[i] <= 0;
                reverse_map[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                next_state = CHECK_POSITION;
                current_pos = 0;
                valid_pos_count = 0;
                last_valid_pos = 0;
                frag_len_reg = frag_len;
                msg_len_reg = msg_len;
            end
            CHECK_POSITION: begin
                if (current_pos > (msg_len_reg - frag_len_reg)) begin
                    next_state = COUNT_UPDATES;
                end else begin
                    next_state = CHECK_MAPPING;
                    frag_idx = 0;
                    msg_idx = current_pos;
                    mapping_valid = 1;
                    for (int i = 0; i < 26; i++) begin
                        char_map[i] = 0;
                        reverse_map[i] = 0;
                    end
                end
            end
            CHECK_MAPPING: begin
                if (frag_idx == frag_len_reg) begin
                    if (mapping_valid) begin
                        valid_pos_count = valid_pos_count + 1;
                        last_valid_pos = current_pos;
                    end
                    current_pos = current_pos + 1;
                    next_state = CHECK_POSITION;
                end else begin
                    frag_char = fragment[(frag_idx * 8) +: 8];
                    msg_char = encrypted_msg[(msg_idx * 8) +: 8];
                    char_idx = frag_char - 8'd"a";
                    if (char_map[char_idx] == 0) begin
                        if (reverse_map[msg_char - 8'd"a"] == 0) begin
                            char_map[char_idx] = msg_char;
                            reverse_map[msg_char - 8'd"a"] = frag_char;
                        end else begin
                            mapping_valid = 0;
                        end
                    end else if (char_map[char_idx] != msg_char) begin
                        mapping_valid = 0;
                    end
                    frag_idx = frag_idx + 1;
                    msg_idx = msg_idx + 1;
                end
            end
            COUNT_UPDATES: begin
                next_state = UPDATE_RESULT;
            end
            UPDATE_RESULT: begin
                if (valid_pos_count == 1) begin
                    result_pos = last_valid_pos;
                    for (int i = 0; i < 16; i++) begin
                        if (i < frag_len_reg) begin
                            result_string[(i * 8) +: 8] = encrypted_msg[((last_valid_pos + i) * 8) +: 8];
                        end else begin
                            result_string[(i * 8) +: 8] = 8'd" "; // Space padding
                        end
                    end
                end else begin
                    result_pos = 0;
                    result_string = 0;
                end
                match_count = valid_pos_count;
                next_state = DONE;
            end
            DONE: begin
                done = 1;
                if (!start) begin
                    next_state = IDLE;
                    done = 0;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule