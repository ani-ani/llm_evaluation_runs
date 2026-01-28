module CountPalindromes(
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
    localparam [29:0] POW26_5 = 30'd11881376;  // 26^5
    localparam [29:0] POW26_6 = 30'd308915776; // 26^6
    localparam [29:0] POW26_7 = 30'd8031810176; // 26^7
    localparam [29:0] POW26_8 = 30'd208827064576; // 26^8

    // FSM States
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT_DP     = 3'd1;
    localparam [2:0] CALC_DP     = 3'd2;
    localparam [2:0] SUM_DP      = 3'd3;
    localparam [2:0] CALC_FINAL  = 3'd4;
    localparam [2:0] DONE_STATE  = 3'd5;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // DP Table: [0..4][0..4]
    reg [29:0] dp [0:4][0:4];
    
    // Loop counters
    reg [2:0] pos;
    reg [4:0] match;
    reg [4:0] letter;
    
    // Intermediate results
    reg [29:0] sum_val;
    reg [29:0] temp_mult;
    reg [29:0] temp_result;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Helper wires for DP update
    wire [4:0] next_match;
    wire match_found;
    
    assign match_found = (letter < s_len) && (s_chars[letter] == 1'b1);
    assign next_match = match + (match_found ? 5'd1 : 5'd0);

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 30'd0;
            pos <= 3'd0;
            match <= 5'd0;
            letter <= 5'd0;
            sum_val <= 30'd0;
            temp_result <= 30'd0;
            cycle_count <= 8'd0;
            // Initialize DP table
            dp[0][0] <= 30'd0; dp[0][1] <= 30'd0; dp[0][2] <= 30'd0; dp[0][3] <= 30'd0; dp[0][4] <= 30'd0;
            dp[1][0] <= 30'd0; dp[1][1] <= 30'd0; dp[1][2] <= 30'd0; dp[1][3] <= 30'd0; dp[1][4] <= 30'd0;
            dp[2][0] <= 30'd0; dp[2][1] <= 30'd0; dp[2][2] <= 30'd0; dp[2][3] <= 30'd0; dp[2][4] <= 30'd0;
            dp[3][0] <= 30'd0; dp[3][1] <= 30'd0; dp[3][2] <= 30'd0; dp[3][3] <= 30'd0; dp[3][4] <= 30'd0;
            dp[4][0] <= 30'd0; dp[4][1] <= 30'd0; dp[4][2] <= 30'd0; dp[4][3] <= 30'd0; dp[4][4] <= 30'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT_DP;
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                INIT_DP: begin
                    // Initialize dp[0][0] = 1
                    dp[0][0] <= 30'd1;
                    dp[0][1] <= 30'd0;
                    dp[0][2] <= 30'd0;
                    dp[0][3] <= 30'd0;
                    dp[0][4] <= 30'd0;
                    pos <= 3'd0;
                    state <= CALC_DP;
                    cycle_count <= cycle_count + 8'd1;
                end

                CALC_DP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (pos < s_len) begin
                        // Process position pos
                        if (letter < 30'd26) begin
                            // For current position, update all match states from previous position
                            for (match = 0; match < 5; match = match + 1) begin
                                if (match <= pos) begin
                                    // Check if this letter matches the next character in S
                                    if ((letter < s_len) && s_chars[letter]) begin
                                        // Matches: transition from match to match+1
                                        if (match < 4) begin
                                            if (match + 1 <= 4) begin
                                                dp[pos + 1][match + 1] <= (dp[pos + 1][match + 1] + dp[pos][match]) % MOD;
                                            end
                                        end
                                    end
                                    // Also count non-matching letters (stay at same match count)
                                    // But only if we haven't completed the string
                                    if (match <= pos) begin
                                        dp[pos + 1][match] <= (dp[pos + 1][match] + dp[pos][match]) % MOD;
                                    end
                                end
                            end
                            letter <= letter + 5'd1;
                        end else begin
                            // Reset for next position
                            letter <= 5'd0;
                            pos <= pos + 3'd1;
                            // Clear next row for next iteration
                            dp[pos + 1][0] <= 30'd0;
                            dp[pos + 1][1] <= 30'd0;
                            dp[pos + 1][2] <= 30'd0;
                            dp[pos + 1][3] <= 30'd0;
                            dp[pos + 1][4] <= 30'd0;
                        end
                    end else begin
                        // Done with all positions
                        state <= SUM_DP;
                        sum_val <= 30'd0;
                        match <= 5'd0;
                    end
                end

                SUM_DP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (match <= s_len) begin
                        // Get pow26 value based on N - match
                        case (s_len - match[2:0])
                            3'd0: temp_mult <= POW26_0;
                            3'd1: temp_mult <= POW26_1;
                            3'd2: temp_mult <= POW26_2;
                            3'd3: temp_mult <= POW26_3;
                            3'd4: temp_mult <= POW26_4;
                            default: temp_mult <= POW26_0;
                        endcase
                        sum_val <= (sum_val + (dp[s_len][match] * temp_mult) % MOD) % MOD;
                        match <= match + 5'd1;
                    end else begin
                        state <= CALC_FINAL;
                    end
                end

                CALC_FINAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Multiply by 26^N
                    case (s_len)
                        3'd0: temp_result <= sum_val;
                        3'd1: temp_result <= (sum_val * POW26_1) % MOD;
                        3'd2: temp_result <= (sum_val * POW26_2) % MOD;
                        3'd3: temp_result <= (sum_val * POW26_3) % MOD;
                        3'd4: temp_result <= (sum_val * POW26_4) % MOD;
                        default: temp_result <= sum_val;
                    endcase
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Timeout protection
            if ((state != IDLE) && (cycle_count >= MAX_CYCLES)) begin
                state <= DONE_STATE;
                result <= 30'd0;
            end
        end
    end

endmodule