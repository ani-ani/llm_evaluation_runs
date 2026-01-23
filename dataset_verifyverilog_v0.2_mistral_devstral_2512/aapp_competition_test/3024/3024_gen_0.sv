module palindrome_partition (
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] str_data,
    input [3:0] str_len,
    output reg [3:0] max_k,
    output reg done
);

    parameter MAX_LEN = 8;
    parameter MAX_K = 8;

    typedef enum logic [1:0] {
        IDLE,
        CHECK_MATCH,
        UPDATE_POINTERS,
        DONE
    } state_t;

    state_t current_state, next_state;

    reg [3:0] left_idx;
    reg [3:0] right_idx;
    reg [3:0] current_k;
    reg [3:0] match_i;
    reg [3:0] check_i;
    reg [2:0] char_idx;
    reg match_found;
    reg match_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            left_idx <= 0;
            right_idx <= 0;
            current_k <= 0;
            match_i <= 0;
            check_i <= 0;
            char_idx <= 0;
            match_found <= 0;
            match_valid <= 0;
            max_k <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        left_idx <= 0;
                        right_idx <= str_len - 1;
                        current_k <= 0;
                        match_i <= 0;
                        check_i <= 1;
                        char_idx <= 0;
                        match_found <= 0;
                        match_valid <= 0;
                        next_state <= CHECK_MATCH;
                    end
                end

                CHECK_MATCH: begin
                    if (check_i > (right_idx - left_idx + 1)) begin
                        if (match_found) begin
                            next_state <= UPDATE_POINTERS;
                        end else begin
                            next_state <= DONE;
                        end
                    end else begin
                        if (char_idx == 0) begin
                            match_valid <= 1'b1;
                        end

                        if (match_valid) begin
                            if (str_data[left_idx + char_idx] != str_data[right_idx - check_i + 1 + char_idx]) begin
                                match_valid <= 1'b0;
                            end

                            if (char_idx == check_i - 1) begin
                                if (match_valid) begin
                                    match_found <= 1'b1;
                                    match_i <= check_i;
                                end
                                char_idx <= 0;
                                check_i <= check_i + 1;
                            end else begin
                                char_idx <= char_idx + 1;
                            end
                        end else begin
                            char_idx <= 0;
                            check_i <= check_i + 1;
                        end
                    end
                end

                UPDATE_POINTERS: begin
                    left_idx <= left_idx + match_i;
                    right_idx <= right_idx - match_i;
                    current_k <= current_k + 1;

                    if (left_idx > right_idx || current_k == MAX_K - 1) begin
                        next_state <= DONE;
                    end else begin
                        match_i <= 0;
                        check_i <= 1;
                        char_idx <= 0;
                        match_found <= 0;
                        match_valid <= 0;
                        next_state <= CHECK_MATCH;
                    end
                end

                DONE: begin
                    max_k <= current_k + 1;
                    done <= 1'b1;
                    if (!start) begin
                        done <= 1'b0;
                        next_state <= IDLE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = current_state;
    end

endmodule