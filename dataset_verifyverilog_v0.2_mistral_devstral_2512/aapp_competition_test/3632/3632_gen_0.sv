module composite_rank (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] k,
    input [255:0] str_0, str_1, str_2, str_3, str_4, str_5, str_6, str_7,
    input [7:0] len_0, len_1, len_2, len_3, len_4, len_5, len_6, len_7,
    input [511:0] test_str,
    input [7:0] test_len,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 1000000007;
    localparam MAX_N = 8;
    localparam MAX_K = 8;

    // Precomputed factorials modulo MOD
    localparam [31:0] fact [0:MAX_N] = '{40320, 5040, 720, 120, 24, 6, 2, 1, 1};

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        MATCH,
        CALCULATE,
        UPDATE,
        DONE
    } state_t;

    state_t state;

    // Internal registers
    reg [7:0] used_mask;
    reg [7:0] pos;
    reg [7:0] str_idx;
    reg [7:0] test_pos;
    reg [7:0] match_len;
    reg [31:0] rank;
    reg [31:0] count_smaller;
    reg [31:0] perm;
    reg [31:0] temp;
    reg [31:0] factorial [0:MAX_N];

    // String storage
    reg [255:0] strings [0:MAX_N-1];
    reg [7:0] lengths [0:MAX_N-1];

    // Initialize factorial lookup table
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            used_mask <= 0;
            pos <= 0;
            str_idx <= 0;
            test_pos <= 0;
            match_len <= 0;
            rank <= 0;
            count_smaller <= 0;
            perm <= 0;
            temp <= 0;
            done <= 0;
            result <= 0;

            // Initialize factorial table
            factorial[0] <= 1;
            factorial[1] <= 1;
            factorial[2] <= 2;
            factorial[3] <= 6;
            factorial[4] <= 24;
            factorial[5] <= 120;
            factorial[6] <= 720;
            factorial[7] <= 5040;
            factorial[8] <= 40320;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                    end
                end

                INIT: begin
                    // Load strings and lengths
                    strings[0] <= str_0;
                    strings[1] <= str_1;
                    strings[2] <= str_2;
                    strings[3] <= str_3;
                    strings[4] <= str_4;
                    strings[5] <= str_5;
                    strings[6] <= str_6;
                    strings[7] <= str_7;

                    lengths[0] <= len_0;
                    lengths[1] <= len_1;
                    lengths[2] <= len_2;
                    lengths[3] <= len_3;
                    lengths[4] <= len_4;
                    lengths[5] <= len_5;
                    lengths[6] <= len_6;
                    lengths[7] <= len_7;

                    used_mask <= 0;
                    pos <= 0;
                    test_pos <= 0;
                    rank <= 0;
                    state <= MATCH;
                end

                MATCH: begin
                    // Find next match in test string
                    if (test_pos >= test_len) begin
                        state <= DONE;
                    end else begin
                        str_idx <= 0;
                        match_len <= 0;
                        count_smaller <= 0;

                        // Check each unused string for prefix match
                        for (int i = 0; i < n; i = i + 1) begin
                            if (!used_mask[i] && lengths[i] > 0) begin
                                // Check if string matches at current test position
                                reg match = 1;
                                for (int j = 0; j < lengths[i]; j = j + 1) begin
                                    if (test_str[test_pos + j] != strings[i][j]) begin
                                        match = 0;
                                    end
                                end

                                if (match) begin
                                    str_idx <= i;
                                    match_len <= lengths[i];
                                    break;
                                end
                            end
                        end

                        if (match_len > 0) begin
                            state <= CALCULATE;
                        end else begin
                            // No match found (shouldn't happen per problem statement)
                            state <= DONE;
                        end
                    end
                end

                CALCULATE: begin
                    // Count unused strings lexicographically smaller than matched string
                    count_smaller <= 0;
                    for (int i = 0; i < n; i = i + 1) begin
                        if (!used_mask[i] && i != str_idx) begin
                            reg smaller = 1;
                            for (int j = 0; j < 32; j = j + 1) begin
                                if (strings[i][j] != strings[str_idx][j]) begin
                                    smaller = (strings[i][j] < strings[str_idx][j]);
                                    break;
                                end
                            end
                            if (smaller) begin
                                count_smaller <= count_smaller + 1;
                            end
                        end
                    end

                    // Calculate permutations: P(n - pos - 1, k - pos - 1)
                    if (k - pos - 1 == 0) begin
                        perm <= 1;
                    end else begin
                        temp <= factorial[n - pos - 1];
                        perm <= temp / factorial[n - pos - 1 - (k - pos - 1)];
                    end

                    state <= UPDATE;
                end

                UPDATE: begin
                    // Update rank
                    temp <= count_smaller * perm;
                    rank <= (rank + temp) % MOD;

                    // Mark string as used
                    used_mask <= used_mask | (1 << str_idx);

                    // Move to next position
                    pos <= pos + 1;
                    test_pos <= test_pos + match_len;

                    if (pos == k) begin
                        state <= DONE;
                    end else begin
                        state <= MATCH;
                    end
                end

                DONE: begin
                    // Result is rank + 1 (1-indexed)
                    result <= (rank + 1) % MOD;
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule