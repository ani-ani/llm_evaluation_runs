module maze_solver #(
    parameter MOD = 32'd1000000007,
    parameter MAX_N = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    output reg [31:0] result,
    output reg done
);

    // State machine states
    reg [1:0] state;
    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_COMPUTE = 2'd1;
    localparam [1:0] S_DONE = 2'd2;

    // Data registers
    reg [3:0] i;
    reg [31:0] dp [0:MAX_N];

    // Helper: select current p value
    wire [3:0] p_val;
    assign p_val = (i == 4'd1) ? p_0 :
                   (i == 4'd2) ? p_1 :
                   (i == 4'd3) ? p_2 :
                   (i == 4'd4) ? p_3 :
                   (i == 4'd5) ? p_4 :
                   (i == 4'd6) ? p_5 :
                   (i == 4'd7) ? p_6 : p_7;

    // State machine and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            i <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            dp[0] <= 32'd0;
            dp[1] <= 32'd0;
            dp[2] <= 32'd0;
            dp[3] <= 32'd0;
            dp[4] <= 32'd0;
            dp[5] <= 32'd0;
            dp[6] <= 32'd0;
            dp[7] <= 32'd0;
            dp[8] <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start && n != 0) begin
                        state <= S_COMPUTE;
                        i <= 4'd1;
                    end
                end

                S_COMPUTE: begin
                    dp[i] <= (2 * dp[i-1] + 2 + MOD - dp[p_val-1]) % MOD;

                    if (i == n) begin
                        state <= S_DONE;
                        result <= (2 * dp[i-1] + 2 + MOD - dp[p_val-1]) % MOD;
                        done <= 1'b1;
                    end else begin
                        i <= i + 1;
                    end
                end

                S_DONE: begin
                    if (!start) begin
                        state <= S_IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule