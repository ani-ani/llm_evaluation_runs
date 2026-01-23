module max_sum_dp (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);
    // Parameters and registers
    localparam IDLE = 3'd0;
    localparam INIT = 3'd1;
    localparam PROCESSING = 3'd2;
    localparam DONE_STATE = 3'd3;
    reg [1:0] state;
    reg [3:0] n_val;
    reg [3:0] current_i;
    reg [1:0] cnt;
    reg [15:0] dp [0:16];
    // Outputs
    reg [15:0] result_reg;
    reg done_reg;
    assign result = result_reg;
    assign done = done_reg;

    // State machine and control
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            n_val <=0;
            current_i <=0;
            cnt <=0;
            result_reg <=0;
            done_reg <=0;
            dp[0] <=0;
            dp[1] <=1;
        end else begin
            reg [15:0] sum_part, max_val;
            case (state)
                IDLE: begin
                    if (start) begin
                        n_val <= n;
                        state <= INIT;
                    end
                end
                INIT: begin
                    if (n_val ==0) begin
                        result_reg <=0;
                        done_reg <=1;
                        state <= DONE_STATE;
                    end else if (n_val ==1) begin
                        result_reg <=1;
                        done_reg <=1;
                        state <= DONE_STATE;
                    end else begin
                        current_i <=2;
                        cnt <=2;
                        state <= PROCESSING;
                    end
                end
                PROCESSING: begin
                    if (current_i > n_val) begin
                        done_reg <=1;
                        state <= DONE_STATE;
                    end else begin
                        if (cnt ==0) begin
                            sum_part = dp[current_i>>1] + dp[current_i/3] + dp[current_i/4] + dp[current_i/5];
                            max_val = (sum_part > current_i) ? sum_part : current_i;
                            dp[current_i] <= max_val;
                            current_i <= current_i +1;
                            cnt <=2;
                        end else begin
                            cnt <= cnt -1;
                        end
                    end
                end
                DONE_STATE: begin
                    // Do nothing
                end
            endcase
        end
    end

    // Handle result in DONE state
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <=0;
        end else if (state == DONE_STATE) begin
            case (n_val)
                0: result_reg <= dp[0];
                1: result_reg <= dp[1];
                2: result_reg <= dp[2];
                3: result_reg <= dp[3];
                4: result_reg <= dp[4];
                5: result_reg <= dp[5];
                6: result_reg <= dp[6];
                7: result_reg <= dp[7];
                8: result_reg <= dp[8];
                9: result_reg <= dp[9];
                10: result_reg <= dp[10];
                11: result_reg <= dp[11];
                12: result_reg <= dp[12];
                13: result_reg <= dp[13];
                14: result_reg <= dp[14];
                15: result_reg <= dp[15];
                default: result_reg <=0;
            endcase
        end else begin
            result_reg <=0;
        end
    end
endmodule