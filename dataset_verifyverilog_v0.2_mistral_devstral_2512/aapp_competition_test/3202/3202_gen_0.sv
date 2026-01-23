module marble_insertion_dp (
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input [2:0] K,
    input [7:0] marble_colors [0:15],
    output reg [7:0] min_insertions,
    output reg done
);

    parameter MAX_N = 16;
    parameter MAX_K = 5;

    // DP table: 16x16 entries, each 8 bits
    reg [7:0] dp [0:MAX_N-1][0:MAX_N-1];

    // State machine
    typedef enum logic [3:0] {
        IDLE,
        INIT_DP,
        COMPUTE_DP,
        FIND_RESULT,
        DONE
    } state_t;
    state_t state, next_state;

    // Counters
    reg [7:0] length;
    reg [7:0] i, j, k;
    reg [7:0] cycle_count;

    // Initialize DP table for length=1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            length <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            cycle_count <= 0;
            min_insertions <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            if (state == INIT_DP && start) begin
                // Initialize length=1
                if (i < N) begin
                    dp[i][i] <= (marble_colors[i] == marble_colors[i]) ? (K - 1) : 1;
                    i <= i + 1;
                end else begin
                    i <= 0;
                    length <= 2;
                end
            end else if (state == COMPUTE_DP) begin
                // Compute DP for current length
                if (i < N - length + 1) begin
                    j <= i + length - 1;
                    if (k < j) begin
                        // Try split point k
                        if (dp[i][k] + dp[k+1][j] < dp[i][j]) begin
                            dp[i][j] <= dp[i][k] + dp[k+1][j];
                        end
                        k <= k + 1;
                    end else begin
                        k <= i;
                        // Check special case: arr[i]==arr[j]
                        if (marble_colors[i] == marble_colors[j]) begin
                            if (length >= K) begin
                                dp[i][j] <= 0;
                            end else begin
                                dp[i][j] <= K - length;
                            end
                        end
                        i <= i + 1;
                    end
                end else begin
                    i <= 0;
                    k <= 0;
                    if (length < N) begin
                        length <= length + 1;
                    end else begin
                        length <= 0;
                    end
                end
            end else if (state == FIND_RESULT) begin
                min_insertions <= dp[0][N-1];
                done <= 1;
            end else if (state == DONE) begin
                done <= 0;
            end
        end
    end

    // State transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= INIT_DP;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                INIT_DP: begin
                    if (i == N) begin
                        next_state <= COMPUTE_DP;
                    end else begin
                        next_state <= INIT_DP;
                    end
                end
                COMPUTE_DP: begin
                    if (length == N && i == N - length + 1) begin
                        next_state <= FIND_RESULT;
                    end else begin
                        next_state <= COMPUTE_DP;
                    end
                end
                FIND_RESULT: begin
                    next_state <= DONE;
                end
                DONE: begin
                    if (!start) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE;
                    end
                end
                default: next_state <= IDLE;
            endcase
        end
    end

    // Cycle counter for latency
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            if (state == COMPUTE_DP) begin
                cycle_count <= cycle_count + 1;
            end else begin
                cycle_count <= 0;
            end
        end
    end

endmodule