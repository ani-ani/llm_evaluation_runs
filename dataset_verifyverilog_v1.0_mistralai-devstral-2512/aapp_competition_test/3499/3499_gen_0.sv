module palindromic_counter(
    input clk,
    input rst_n,
    input start,
    input [25:0] s_chars,
    input [2:0] s_len,
    output reg [29:0] result,
    output reg done
);

    // Constants
    localparam [29:0] MOD = 30'd1000000007;
    localparam [29:0] POW26_0 = 30'd1;
    localparam [29:0] POW26_1 = 30'd26;
    localparam [29:0] POW26_2 = 30'd676;
    localparam [29:0] POW26_3 = 30'd17576;
    localparam [29:0] POW26_4 = 30'd456976;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINALIZE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // DP table: dp[pos][match]
    reg [29:0] dp [0:4][0:4];
    reg [29:0] temp_dp [0:4][0:4];

    // State and control registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [1:0] pos;
    reg [2:0] match;
    reg [2:0] new_match;
    reg [4:0] letter;
    reg [29:0] sum;
    reg [29:0] temp_sum;
    reg [29:0] pow26_val;

    // Modulo addition
    function [29:0] mod_add;
        input [29:0] a, b;
        begin
            mod_add = (a + b) % MOD;
        end
    endfunction

    // Modulo multiplication
    function [29:0] mod_mul;
        input [29:0] a, b;
        begin
            mod_mul = (a * b) % MOD;
        end
    endfunction

    // Get character from s_chars
    function [2:0] get_char_pos;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: get_char_pos = 3'd0;
                3'd1: get_char_pos = 3'd1;
                3'd2: get_char_pos = 3'd2;
                3'd3: get_char_pos = 3'd3;
                default: get_char_pos = 3'd0;
            endcase
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 30'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            pos <= 2'd0;
            match <= 3'd0;
            sum <= 30'd0;
            temp_sum <= 30'd0;

            // Initialize DP table
            integer i, j;
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    dp[i][j] <= 30'd0;
                    temp_dp[i][j] <= 30'd0;
                end
            end
            dp[0][0] <= 30'd1;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Reset DP table
                    integer i, j;
                    for (i = 0; i < 5; i = i + 1) begin
                        for (j = 0; j < 5; j = j + 1) begin
                            dp[i][j] <= 30'd0;
                            temp_dp[i][j] <= 30'd0;
                        end
                    end
                    dp[0][0] <= 30'd1;
                    pos <= 2'd0;
                    match <= 3'd0;
                    sum <= 30'd0;
                    temp_sum <= 30'd0;
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Process current position
                    if (pos < s_len) begin
                        // For each letter
                        letter <= letter + 5'd1;
                        if (letter == 5'd26) begin
                            letter <= 5'd0;
                            pos <= pos + 2'd1;
                        end else begin
                            // Calculate new_match
                            if (match < s_len && s_chars[letter] && letter == s_chars[get_char_pos(match)]) begin
                                new_match <= match + 3'd1;
                            end else begin
                                new_match <= match;
                            end

                            // Update temp_dp
                            temp_dp[pos+1][new_match] <= mod_add(temp_dp[pos+1][new_match], dp[pos][match]);
                        end
                    end else begin
                        // Move to finalize
                        next_state <= FINALIZE;
                    end

                    // Safety counter
                    if (cycle_count >= 8'd255) begin
                        next_state <= IDLE;
                    end
                end

                FINALIZE: begin
                    // Sum all dp[N][match] * 26^(N-match)
                    integer m;
                    for (m = 0; m < 5; m = m + 1) begin
                        case (s_len - m)
                            3'd0: pow26_val = POW26_0;
                            3'd1: pow26_val = POW26_1;
                            3'd2: pow26_val = POW26_2;
                            3'd3: pow26_val = POW26_3;
                            3'd4: pow26_val = POW26_4;
                            default: pow26_val = 30'd0;
                        endcase
                        temp_sum <= mod_add(temp_sum, mod_mul(dp[s_len][m], pow26_val));
                    end

                    // Multiply by 26^N for second half
                    case (s_len)
                        3'd0: result <= mod_mul(temp_sum, POW26_0);
                        3'd1: result <= mod_mul(temp_sum, POW26_1);
                        3'd2: result <= mod_mul(temp_sum, POW26_2);
                        3'd3: result <= mod_mul(temp_sum, POW26_3);
                        3'd4: result <= mod_mul(temp_sum, POW26_4);
                        default: result <= 30'd0;
                    endcase

                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Initialize letter counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            letter <= 5'd0;
        end else if (state == INIT) begin
            letter <= 5'd0;
        end
    end

endmodule