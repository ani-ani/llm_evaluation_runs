module task_counter(
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    input [4:0] A_addr,
    input [31:0] A_data,
    input [4:0] B_addr,
    input [31:0] B_data,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_N = 5'd32;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FETCH = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [4:0] counter_i;
    reg [31:0] dp_prev_0, dp_prev_1;
    reg [31:0] A_current, B_current;
    reg [63:0] temp_64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter_i <= 5'd0;
            dp_prev_0 <= 32'd1;
            dp_prev_1 <= 32'd0;
            A_current <= 32'd0;
            B_current <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        counter_i <= 5'd1;
                        next_state <= FETCH;
                        busy <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FETCH: begin
                    // Assume A_data and B_data are provided for current counter_i
                    A_current <= A_data;
                    if (counter_i < N) begin
                        B_current <= B_data;
                    end else begin
                        B_current <= 32'd0;
                    end
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    // Compute dp[i][0] = (dp[i-1][0] * (A[i] + B[i])) + (dp[i-1][1] * A[i])
                    temp_64 = dp_prev_0 * (A_current + B_current);
                    dp_prev_0 <= (temp_64[63:32] ? (temp_64 % MOD) : temp_64) % MOD;

                    temp_64 = dp_prev_1 * A_current;
                    dp_prev_0 <= (dp_prev_0 + (temp_64[63:32] ? (temp_64 % MOD) : temp_64)) % MOD;

                    // Compute dp[i][1] = dp[i-1][0] * B[i]
                    temp_64 = dp_prev_0 * B_current;
                    dp_prev_1 <= (temp_64[63:32] ? (temp_64 % MOD) : temp_64) % MOD;

                    if (counter_i == N) begin
                        next_state <= DONE_STATE;
                    end else begin
                        counter_i <= counter_i + 5'd1;
                        next_state <= FETCH;
                    end
                end

                DONE_STATE: begin
                    result <= dp_prev_0;
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule