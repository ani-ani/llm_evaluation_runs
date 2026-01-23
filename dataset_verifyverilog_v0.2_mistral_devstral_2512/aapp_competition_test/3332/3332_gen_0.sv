module max_priority_subset (
    input clk,
    input rst_n,
    input start,
    input [7:0] s_i, d_i, p_i,
    input valid_in,
    output reg [11:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        SORT,
        DP_COMPUTE,
        FINISH
    } state_t;

    state_t state;

    // Stream storage
    logic [7:0] s [0:7];
    logic [7:0] d [0:7];
    logic [7:0] p [0:7];
    logic [8:0] e [0:7];

    // DP table
    logic [11:0] dp [0:8];

    // Counters
    logic [2:0] load_cnt;
    logic [2:0] sort_i, sort_j;
    logic [2:0] dp_i, dp_k;

    // Temporary variables
    logic [11:0] max_val;
    logic [11:0] temp_dp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_cnt <= 0;
            sort_i <= 0;
            sort_j <= 0;
            dp_i <= 0;
            dp_k <= 0;
            max_val <= 0;
            temp_dp <= 0;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        load_cnt <= 0;
                    end
                end

                LOAD: begin
                    if (valid_in) begin
                        s[load_cnt] <= s_i;
                        d[load_cnt] <= d_i;
                        p[load_cnt] <= p_i;
                        e[load_cnt] <= s_i + d_i;
                        load_cnt <= load_cnt + 1;
                        if (load_cnt == 7) begin
                            state <= SORT;
                            sort_i <= 0;
                            sort_j <= 0;
                        end
                    end
                end

                SORT: begin
                    // Bubble sort
                    if (sort_i < 7) begin
                        if (sort_j < 7 - sort_i) begin
                            // Compare and swap
                            if (e[sort_j] > e[sort_j + 1]) begin
                                // Swap s
                                logic [7:0] temp_s = s[sort_j];
                                s[sort_j] <= s[sort_j + 1];
                                s[sort_j + 1] <= temp_s;
                                // Swap d
                                logic [7:0] temp_d = d[sort_j];
                                d[sort_j] <= d[sort_j + 1];
                                d[sort_j + 1] <= temp_d;
                                // Swap p
                                logic [7:0] temp_p = p[sort_j];
                                p[sort_j] <= p[sort_j + 1];
                                p[sort_j + 1] <= temp_p;
                                // Swap e
                                logic [8:0] temp_e = e[sort_j];
                                e[sort_j] <= e[sort_j + 1];
                                e[sort_j + 1] <= temp_e;
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            sort_j <= 0;
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        state <= DP_COMPUTE;
                        dp_i <= 1;
                        dp[0] <= 0;
                    end
                end

                DP_COMPUTE: begin
                    if (dp_i <= 8) begin
                        // Option 1: Exclude current stream
                        temp_dp <= dp[dp_i - 1];
                        max_val <= 0;

                        // Option 2: Include current stream
                        // Find max dp[k] where e[k] <= s[dp_i - 1]
                        for (dp_k = 0; dp_k < dp_i; dp_k = dp_k + 1) begin
                            if (e[dp_k] <= s[dp_i - 1]) begin
                                if (dp[dp_k] > max_val) begin
                                    max_val <= dp[dp_k];
                                end
                            end
                        end

                        // Add current priority
                        temp_dp <= p[dp_i - 1] + max_val;

                        // Take max of both options
                        if (temp_dp > dp[dp_i - 1]) begin
                            dp[dp_i] <= temp_dp;
                        end else begin
                            dp[dp_i] <= dp[dp_i - 1];
                        end

                        dp_i <= dp_i + 1;
                        if (dp_i == 8) begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= dp[8];
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule