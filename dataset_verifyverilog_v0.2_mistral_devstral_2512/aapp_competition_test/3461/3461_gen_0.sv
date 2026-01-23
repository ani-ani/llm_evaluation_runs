module hearing_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] s [0:7],
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        CALCULATE,
        DIVIDE,
        FINALIZE,
        DONE
    } state_t;

    state_t state;
    reg [2:0] i, j, t;
    reg [31:0] dp [0:8];
    reg [31:0] numerator;
    reg [31:0] denominator;
    reg [31:0] temp_sum;
    reg [31:0] temp_val;
    reg [31:0] max_val;
    reg [31:0] next_j;
    reg [31:0] prob;
    reg [31:0] one;

    parameter ONE = 32'h00010000; // 1.0 in Q16.16

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            i <= 0;
            j <= 0;
            t <= 0;
            numerator <= 0;
            denominator <= 0;
            temp_sum <= 0;
            temp_val <= 0;
            max_val <= 0;
            next_j <= 0;
            prob <= 0;
            one <= ONE;
            for (int k = 0; k < 9; k++) begin
                dp[k] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        done <= 0;
                    end
                end
                LOAD: begin
                    // Initialize DP array
                    dp[8] <= 0;
                    i <= n - 1;
                    state <= CALCULATE;
                end
                CALCULATE: begin
                    if (i >= 0) begin
                        // Calculate E_attend
                        numerator <= 0;
                        denominator <= (b[i] - a[i]) + 1;
                        temp_sum <= 0;
                        for (t = s[i] + a[i]; t <= s[i] + b[i]; t = t + 1) begin
                            // Find first j > i where s[j] >= t
                            next_j <= 8;
                            for (j = i + 1; j < n; j = j + 1) begin
                                if (s[j] >= t) begin
                                    next_j <= j;
                                    break;
                                end
                            end
                            // Add (1 + dp[next_j]) to numerator
                            temp_val <= ONE + dp[next_j];
                            numerator <= numerator + temp_val;
                        end
                        // E_attend = numerator / denominator
                        if (denominator != 0) begin
                            temp_val <= numerator << 16;
                            temp_val <= temp_val / denominator;
                        end else begin
                            temp_val <= 0;
                        end
                        // E_skip = dp[i+1]
                        max_val <= temp_val > dp[i+1] ? temp_val : dp[i+1];
                        dp[i] <= max_val;
                        i <= i - 1;
                    end else begin
                        state <= DIVIDE;
                    end
                end
                DIVIDE: begin
                    // No division needed here, proceed to finalize
                    state <= FINALIZE;
                end
                FINALIZE: begin
                    result <= dp[0];
                    state <= DONE;
                end
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule