module bracket_validator (
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] bracket_str,
    input [4:0] str_len,
    output reg result,
    output reg done
);

    // State definitions
    typedef enum logic [4:0] {
        IDLE,
        CHECK_ORIGINAL,
        INVERT_SEGMENT,
        CHECK_VALID,
        EVALUATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Counters and registers
    reg [4:0] l, r;
    reg [4:0] char_idx;
    reg [4:0] balance;
    reg [7:0] current_char;
    reg [15:0][7:0] inverted_str;
    reg valid_flag;
    reg [4:0] l_next, r_next;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            l <= 0;
            r <= 0;
            char_idx <= 0;
            balance <= 0;
            current_char <= 0;
            valid_flag <= 0;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        l <= 16; // Special value for original check
                        r <= 16;
                        char_idx <= 0;
                        balance <= 0;
                        valid_flag <= 0;
                    end
                end
                
                CHECK_ORIGINAL: begin
                    if (char_idx == str_len) begin
                        if (balance == 0 && valid_flag) begin
                            result <= 1;
                            next_state <= DONE;
                        end else begin
                            l <= 0;
                            r <= 0;
                            char_idx <= 0;
                            next_state <= INVERT_SEGMENT;
                        end
                    end else begin
                        char_idx <= char_idx + 1;
                    end
                end
                
                INVERT_SEGMENT: begin
                    if (r == 16) begin
                        // Move to next segment
                        l_next = l + 1;
                        if (l_next == 16) begin
                            next_state <= DONE;
                        end else begin
                            r_next = l_next;
                            l <= l_next;
                            r <= r_next;
                        end
                    end else begin
                        // Apply inversion
                        inverted_str <= bracket_str;
                        for (int i = l; i <= r; i = i + 1) begin
                            if (bracket_str[i] == 8'h28) begin
                                inverted_str[i] = 8'h29;
                            end else if (bracket_str[i] == 8'h29) begin
                                inverted_str[i] = 8'h28;
                            end
                        end
                        char_idx <= 0;
                        balance <= 0;
                        valid_flag <= 1;
                        next_state <= CHECK_VALID;
                    end
                end
                
                CHECK_VALID: begin
                    if (char_idx == str_len) begin
                        if (balance == 0 && valid_flag) begin
                            result <= 1;
                            next_state <= DONE;
                        end else begin
                            r <= r + 1;
                            next_state <= INVERT_SEGMENT;
                        end
                    end else begin
                        char_idx <= char_idx + 1;
                    end
                end
                
                EVALUATE: begin
                    if (valid_flag && balance == 0) begin
                        result <= 1;
                        next_state <= DONE;
                    end else begin
                        r <= r + 1;
                        next_state <= INVERT_SEGMENT;
                    end
                end
                
                DONE: begin
                    done <= 1;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_ORIGINAL;
                end
            end
            
            CHECK_ORIGINAL: begin
                if (char_idx == str_len) begin
                    if (balance == 0 && valid_flag) begin
                        next_state = DONE;
                    end else begin
                        next_state = INVERT_SEGMENT;
                    end
                end
            end
            
            INVERT_SEGMENT: begin
                if (r == 16) begin
                    if (l == 15) begin
                        next_state = DONE;
                    end else begin
                        next_state = INVERT_SEGMENT;
                    end
                end else begin
                    next_state = CHECK_VALID;
                end
            end
            
            CHECK_VALID: begin
                if (char_idx == str_len) begin
                    next_state = EVALUATE;
                end
            end
            
            EVALUATE: begin
                next_state = INVERT_SEGMENT;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Balance calculation
    always @(*) begin
        if (current_state == CHECK_ORIGINAL) begin
            if (char_idx < str_len) begin
                current_char = bracket_str[char_idx];
                if (current_char == 8'h28) begin
                    balance = balance + 1;
                end else if (current_char == 8'h29) begin
                    balance = balance - 1;
                    if (balance < 0) begin
                        valid_flag = 0;
                    end
                end
            end
        end else if (current_state == CHECK_VALID) begin
            if (char_idx < str_len) begin
                current_char = inverted_str[char_idx];
                if (current_char == 8'h28) begin
                    balance = balance + 1;
                end else if (current_char == 8'h29) begin
                    balance = balance - 1;
                    if (balance < 0) begin
                        valid_flag = 0;
                    end
                end
            end
        end
    end

    // Handle empty string case
    always @(*) begin
        if (str_len == 0) begin
            result = 1;
            done = 1;
        end
    end

endmodule