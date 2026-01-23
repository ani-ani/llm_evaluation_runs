module goldbach_checker (
    input clk,
    input rst_n,
    input [7:0] char_in,
    input char_valid,
    input char_last,
    output reg result,
    output reg done
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        PARSING_TOKEN,
        VERIFY_PRIME_1,
        VERIFY_PRIME_2,
        VERIFY_SUM,
        VALID,
        INVALID
    } state_t;

    state_t current_state, next_state;

    // Token storage
    reg [15:0] token1, token2, token3;
    reg [3:0] token_count;

    // Parsing variables
    reg [15:0] current_token;
    reg [3:0] digit_count;
    reg has_leading_zero;

    // Primality check variables
    reg [15:0] prime_candidate;
    reg [7:0] divisor;
    reg is_prime;

    // Precomputed primes up to 224 (sqrt(50000))
    reg [223:0] prime_lookup;

    // Initialize prime lookup table
    initial begin
        prime_lookup = 224'b0;
        prime_lookup[2] = 1'b1;  // 2
        prime_lookup[3] = 1'b1;  // 3
        prime_lookup[5] = 1'b1;  // 5
        prime_lookup[7] = 1'b1;  // 7
        prime_lookup[11] = 1'b1; // 11
        prime_lookup[13] = 1'b1; // 13
        prime_lookup[17] = 1'b1; // 17
        prime_lookup[19] = 1'b1; // 19
        prime_lookup[23] = 1'b1; // 23
        prime_lookup[29] = 1'b1; // 29
        prime_lookup[31] = 1'b1; // 31
        prime_lookup[37] = 1'b1; // 37
        prime_lookup[41] = 1'b1; // 41
        prime_lookup[43] = 1'b1; // 43
        prime_lookup[47] = 1'b1; // 47
        prime_lookup[53] = 1'b1; // 53
        prime_lookup[59] = 1'b1; // 59
        prime_lookup[61] = 1'b1; // 61
        prime_lookup[67] = 1'b1; // 67
        prime_lookup[71] = 1'b1; // 71
        prime_lookup[73] = 1'b1; // 73
        prime_lookup[79] = 1'b1; // 79
        prime_lookup[83] = 1'b1; // 83
        prime_lookup[89] = 1'b1; // 89
        prime_lookup[97] = 1'b1; // 97
        prime_lookup[101] = 1'b1; // 101
        prime_lookup[103] = 1'b1; // 103
        prime_lookup[107] = 1'b1; // 107
        prime_lookup[109] = 1'b1; // 109
        prime_lookup[113] = 1'b1; // 113
        prime_lookup[127] = 1'b1; // 127
        prime_lookup[131] = 1'b1; // 131
        prime_lookup[137] = 1'b1; // 137
        prime_lookup[139] = 1'b1; // 139
        prime_lookup[149] = 1'b1; // 149
        prime_lookup[151] = 1'b1; // 151
        prime_lookup[157] = 1'b1; // 157
        prime_lookup[163] = 1'b1; // 163
        prime_lookup[167] = 1'b1; // 167
        prime_lookup[173] = 1'b1; // 173
        prime_lookup[179] = 1'b1; // 179
        prime_lookup[181] = 1'b1; // 181
        prime_lookup[191] = 1'b1; // 191
        prime_lookup[193] = 1'b1; // 193
        prime_lookup[197] = 1'b1; // 197
        prime_lookup[199] = 1'b1; // 199
        prime_lookup[211] = 1'b1; // 211
        prime_lookup[223] = 1'b1; // 223
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            token_count <= 0;
            current_token <= 0;
            digit_count <= 0;
            has_leading_zero <= 0;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (char_valid && char_in != 8'd32 && char_in != 8'd9 && char_in != 8'd10 && char_in != 8'd13) begin
                    if (char_in == 8'd48) begin
                        has_leading_zero = 1'b1;
                        next_state = PARSING_TOKEN;
                    end else if (char_in >= 8'd49 && char_in <= 8'd57) begin
                        has_leading_zero = 1'b0;
                        next_state = PARSING_TOKEN;
                    end else begin
                        next_state = INVALID;
                    end
                end
            end

            PARSING_TOKEN: begin
                if (char_valid) begin
                    if (char_in >= 8'd48 && char_in <= 8'd57) begin
                        if (has_leading_zero && digit_count > 0) begin
                            current_token = current_token * 10 + (char_in - 8'd48);
                        end else if (!has_leading_zero) begin
                            current_token = current_token * 10 + (char_in - 8'd48);
                        end
                        digit_count = digit_count + 1;
                    end else if (char_in == 8'd32 || char_in == 8'd9 || char_in == 8'd10 || char_in == 8'd13 || char_last) begin
                        if (digit_count == 0 || (has_leading_zero && digit_count > 1)) begin
                            next_state = INVALID;
                        end else begin
                            token_count = token_count + 1;
                            case (token_count)
                                1: token1 = current_token;
                                2: token2 = current_token;
                                3: token3 = current_token;
                            endcase
                            current_token = 0;
                            digit_count = 0;
                            has_leading_zero = 0;
                            if (token_count == 3 || char_last) begin
                                if (token_count != 3) begin
                                    next_state = INVALID;
                                end else begin
                                    next_state = VERIFY_PRIME_1;
                                end
                            end else begin
                                next_state = IDLE;
                            end
                        end
                    end else begin
                        next_state = INVALID;
                    end
                end
            end

            VERIFY_PRIME_1: begin
                if (token2 <= 1) begin
                    next_state = INVALID;
                end else if (token2 <= 223) begin
                    if (prime_lookup[token2]) begin
                        next_state = VERIFY_PRIME_2;
                    end else begin
                        next_state = INVALID;
                    end
                end else begin
                    // Check divisibility
                    if (divisor == 0) begin
                        divisor = 2;
                    end else if (divisor * divisor > token2) begin
                        next_state = VERIFY_PRIME_2;
                    end else if (token2 % divisor == 0) begin
                        next_state = INVALID;
                    end else begin
                        divisor = divisor + 1;
                    end
                end
            end

            VERIFY_PRIME_2: begin
                if (token3 <= 1) begin
                    next_state = INVALID;
                end else if (token3 <= 223) begin
                    if (prime_lookup[token3]) begin
                        next_state = VERIFY_SUM;
                    end else begin
                        next_state = INVALID;
                    end
                end else begin
                    // Check divisibility
                    if (divisor == 0) begin
                        divisor = 2;
                    end else if (divisor * divisor > token3) begin
                        next_state = VERIFY_SUM;
                    end else if (token3 % divisor == 0) begin
                        next_state = INVALID;
                    end else begin
                        divisor = divisor + 1;
                    end
                end
            end

            VERIFY_SUM: begin
                if (token1 > 3 && token1 <= 50000 && token1 % 2 == 0 && token2 + token3 == token1) begin
                    next_state = VALID;
                end else begin
                    next_state = INVALID;
                end
            end

            VALID: begin
                result = 1'b1;
                done = 1'b1;
            end

            INVALID: begin
                result = 1'b0;
                done = 1'b1;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule