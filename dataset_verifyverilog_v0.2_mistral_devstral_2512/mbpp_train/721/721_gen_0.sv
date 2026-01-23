module max_path_average (
    input clk,
    input rst_n,
    input start,
    input [7:0] cost_0_0, cost_0_1, cost_0_2,
    input [7:0] cost_1_0, cost_1_1, cost_1_2,
    input [7:0] cost_2_0, cost_2_1, cost_2_2,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        ROW0,
        ROW1,
        ROW2,
        DIVIDE,
        DONE
    } state_t;

    state_t state;
    reg [11:0] dp [0:2][0:2]; // 12-bit DP array
    reg [31:0] dividend; // Q16.16 dividend
    reg [31:0] divisor = 5; // Fixed divisor
    reg [31:0] quotient; // Q16.16 result
    reg [4:0] div_cycle; // Division cycle counter

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            div_cycle <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load costs into DP array
                        dp[0][0] <= cost_0_0;
                        dp[0][1] <= cost_0_1;
                        dp[0][2] <= cost_0_2;
                        dp[1][0] <= cost_1_0;
                        dp[1][1] <= cost_1_1;
                        dp[1][2] <= cost_1_2;
                        dp[2][0] <= cost_2_0;
                        dp[2][1] <= cost_2_1;
                        dp[2][2] <= cost_2_2;
                        state <= ROW0;
                    end
                end
                ROW0: begin
                    // Process first row
                    dp[0][0] <= cost_0_0;
                    dp[0][1] <= dp[0][0] + cost_0_1;
                    dp[0][2] <= dp[0][1] + cost_0_2;
                    state <= ROW1;
                end
                ROW1: begin
                    // Process second row
                    dp[1][0] <= dp[0][0] + cost_1_0;
                    dp[1][1] <= (dp[0][1] > dp[1][0] ? dp[0][1] : dp[1][0]) + cost_1_1;
                    dp[1][2] <= (dp[0][2] > dp[1][1] ? dp[0][2] : dp[1][1]) + cost_1_2;
                    state <= ROW2;
                end
                ROW2: begin
                    // Process third row
                    dp[2][0] <= dp[1][0] + cost_2_0;
                    dp[2][1] <= (dp[1][1] > dp[2][0] ? dp[1][1] : dp[2][0]) + cost_2_1;
                    dp[2][2] <= (dp[1][2] > dp[2][1] ? dp[1][2] : dp[2][1]) + cost_2_2;
                    state <= DIVIDE;
                end
                DIVIDE: begin
                    // Initialize division
                    if (div_cycle == 0) begin
                        dividend <= dp[2][2] << 16; // Q16.16 format
                        quotient <= 0;
                    end
                    // Sequential division (shift-and-subtract)
                    if (div_cycle < 10) begin
                        dividend <= dividend << 1;
                        if (dividend[31:0] >= divisor) begin
                            dividend[31:0] <= dividend[31:0] - divisor;
                            quotient <= quotient << 1 | 1;
                        end else begin
                            quotient <= quotient << 1;
                        end
                        div_cycle <= div_cycle + 1;
                    end else begin
                        result <= quotient;
                        state <= DONE;
                    end
                end
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        done <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule