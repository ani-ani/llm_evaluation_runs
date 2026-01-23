module subset_coins_dp (
    input clk,
    input rst_n,
    input start,
    input [7:0] coin_in,
    input load_coin,
    output reg [7:0] result_index,
    output reg result_valid,
    output reg done
);

    parameter K = 128;
    parameter N = 12;

    typedef logic [K:0] mask_t;

    // State machine
    typedef enum logic [1:0] {
        IDLE,
        LOAD_COINS,
        PROCESS_COINS,
        OUTPUT
    } state_t;

    state_t state;

    // Coin buffer
    logic [7:0] coins [0:N-1];
    logic [$clog2(N):0] coin_count;

    // DP table (BRAM-like structure)
    mask_t dp [0:K];
    logic [$clog2(K+1):0] s_reg;
    logic [$clog2(N):0] c_reg;

    // Output streaming
    logic [$clog2(K+1):0] x_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            coin_count <= 0;
            s_reg <= 0;
            c_reg <= 0;
            x_reg <= 0;
            result_valid <= 0;
            done <= 0;
            result_index <= 0;

            // Initialize DP table
            for (int i = 0; i <= K; i++) begin
                dp[i] <= 0;
            end
            dp[0] <= 1; // Base case: sum 0 is always possible
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_COINS;
                        coin_count <= 0;
                    end
                end

                LOAD_COINS: begin
                    if (load_coin && coin_count < N) begin
                        coins[coin_count] <= coin_in;
                        coin_count <= coin_count + 1;
                    end
                    if (coin_count == N || (load_coin && coin_count == N-1)) begin
                        state <= PROCESS_COINS;
                        c_reg <= 0;
                        s_reg <= K;
                    end
                end

                PROCESS_COINS: begin
                    if (c_reg < coin_count) begin
                        logic [7:0] current_coin = coins[c_reg];
                        if (s_reg >= current_coin) begin
                            // Read dp[s - c]
                            mask_t prev_mask = dp[s_reg - current_coin];
                            // Compute new mask
                            mask_t new_mask = prev_mask | (prev_mask << current_coin);
                            // Update dp[s]
                            dp[s_reg] <= dp[s_reg] | new_mask;
                            s_reg <= s_reg - 1;
                        end else begin
                            s_reg <= s_reg - 1;
                            if (s_reg == 0) begin
                                s_reg <= K;
                                c_reg <= c_reg + 1;
                            end
                        end
                    end else begin
                        state <= OUTPUT;
                        x_reg <= 0;
                    end
                end

                OUTPUT: begin
                    if (x_reg <= K) begin
                        result_index <= x_reg;
                        result_valid <= dp[K][x_reg];
                        x_reg <= x_reg + 1;
                        if (x_reg == K+1) begin
                            done <= 1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule