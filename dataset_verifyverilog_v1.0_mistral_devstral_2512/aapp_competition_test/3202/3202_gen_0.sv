module min_insertions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] N,
    input wire [3:0] K,
    output reg [7:0] result,
    output reg done
);

    reg [7:0] dp [0:7][0:7][0:4];
    reg [3:0] state;
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] LOOP_LEN = 4'd2;
    localparam [3:0] LOOP_L = 4'd3;
    localparam [3:0] COMPUTE_STATE = 4'd4;
    localparam [3:0] LOOP_I = 4'd5;
    localparam [3:0] NEXT_I = 4'd6;
    localparam [3:0] UPDATE_DP = 4'd7;
    localparam [3:0] NEXT_K = 4'd8;
    localparam [3:0] NEXT_L = 4'd9;
    localparam [3:0] DONE = 4'd10;

    reg [3:0] len, l, k, i;
    reg [7:0] cost1, cost2, temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            len <= 4'd1;
            l <= 4'd0;
            k <= 4'd0;
            i <= 4'd0;
            cost1 <= 8'd0;
            cost2 <= 8'd0;
            temp <= 8'd0;
            for (integer a = 0; a < 8; a = a + 1) begin
                for (integer b = 0; b < 8; b = b + 1) begin
                    for (integer c = 0; c < 5; c = c + 1) begin
                        dp[a][b][c] <= 8'd0;
                    end
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        len <= 4'd1;
                        l <= 4'd0;
                        k <= 4'd0;
                    end
                end

                INIT: begin
                    if (l < N) begin
                        for (k = 0; k < K; k = k + 1) begin
                            if (k + 1 >= K) begin
                                dp[l][l][k] <= 8'd0;
                            end else begin
                                dp[l][l][k] <= K - (k + 1);
                            end
                        end
                        l <= l + 1;
                    end else begin
                        l <= 4'd0;
                        k <= 4'd0;
                        len <= 4'd2;
                        state <= LOOP_LEN;
                    end
                end

                LOOP_LEN: begin
                    if (len > N) begin
                        state <= DONE;
                    end else begin
                        l <= 4'd0;
                        state <= LOOP_L;
                    end
                end

                LOOP_L: begin
                    if (l >= N - len + 1) begin
                        len <= len + 1;
                        state <= LOOP_LEN;
                    end else begin
                        k <= 4'd0;
                        state <= COMPUTE_STATE;
                    end
                end

                COMPUTE_STATE: begin
                    if (k + 1 >= K) begin
                        cost1 <= dp[l+1][l+len-1][0];
                    end else begin
                        cost1 <= (K - (k + 1)) + dp[l+1][l+len-1][0];
                    end
                    i <= l + 1;
                    cost2 <= 8'd255;
                    state <= LOOP_I;
                end

                LOOP_I: begin
                    if (i > l + len - 1) begin
                        state <= UPDATE_DP;
                    end else begin
                        if (arr[l] == arr[i]) begin
                            if (k + 1 >= K) begin
                                temp <= dp[l+1][i-1][0] + dp[i+1][l+len-1][0];
                            end else begin
                                temp <= dp[l+1][i-1][0] + dp[i][l+len-1][k+1];
                            end
                        end
                        state <= NEXT_I;
                    end
                end

                NEXT_I: begin
                    if (arr[l] == arr[i] && temp < cost2) begin
                        cost2 <= temp;
                    end
                    i <= i + 1;
                    state <= LOOP_I;
                end

                UPDATE_DP: begin
                    dp[l][l+len-1][k] <= (cost1 < cost2) ? cost1 : cost2;
                    state <= NEXT_K;
                end

                NEXT_K: begin
                    k <= k + 1;
                    if (k + 1 < K) begin
                        state <= COMPUTE_STATE;
                    end else begin
                        l <= l + 1;
                        state <= NEXT_L;
                    end
                end

                NEXT_L: begin
                    if (l < N - len + 1) begin
                        k <= 4'd0;
                        state <= COMPUTE_STATE;
                    end else begin
                        len <= len + 1;
                        state <= LOOP_LEN;
                    end
                end

                DONE: begin
                    result <= dp[0][N-1][0];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule