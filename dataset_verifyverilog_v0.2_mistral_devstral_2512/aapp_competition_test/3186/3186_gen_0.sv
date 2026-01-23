module ways_calculator (
    input clk,
    input rst_n,
    input start,
    input [6:0] N_in,
    input [6:0] M_in,
    input [6:0] K_in,
    output reg [19:0] result,
    output reg done
);

    // Constants
    localparam MOD = 20'd1000007;
    localparam MAX_SIZE = 128;

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        ITERATE_N,
        ITERATE_K,
        UPDATE_RESULT,
        DONE
    } state_t;

    // State registers
    state_t state, next_state;
    reg [6:0] n_count, k_count;
    reg [19:0] dp [0:MAX_SIZE-1];
    reg [19:0] prev_dp [0:MAX_SIZE-1];
    reg [19:0] temp_val;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_count <= 0;
            k_count <= 0;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
            if (state == ITERATE_K && k_count == K_in) begin
                n_count <= n_count + 1;
                k_count <= 0;
            end else if (state == ITERATE_K) begin
                k_count <= k_count + 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = ITERATE_N;
            end
            ITERATE_N: begin
                if (n_count < N_in) next_state = ITERATE_K;
                else next_state = UPDATE_RESULT;
            end
            ITERATE_K: begin
                if (k_count < K_in) next_state = ITERATE_K;
                else if (n_count < N_in) next_state = ITERATE_N;
                else next_state = UPDATE_RESULT;
            end
            UPDATE_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset arrays
            for (int i = 0; i < MAX_SIZE; i++) begin
                dp[i] <= 0;
                prev_dp[i] <= 0;
            end
        end else begin
            case (state)
                INIT: begin
                    // Initialize dp[0] = 1
                    dp[0] <= 1;
                    for (int i = 1; i < MAX_SIZE; i++) begin
                        dp[i] <= 0;
                        prev_dp[i] <= 0;
                    end
                end
                ITERATE_K: begin
                    // Compute new value
                    temp_val = dp[k_count - 1] + prev_dp[k_count];
                    if (k_count >= M_in + 1) begin
                        temp_val = temp_val - prev_dp[k_count - M_in - 1];
                    end
                    // Handle negative results
                    if (temp_val < 0) begin
                        temp_val = temp_val + MOD;
                    end
                    // Store result modulo MOD
                    dp[k_count] <= temp_val % MOD;
                end
                ITERATE_N: begin
                    // Copy current dp to prev_dp for next iteration
                    for (int i = 0; i < MAX_SIZE; i++) begin
                        prev_dp[i] <= dp[i];
                    end
                end
                UPDATE_RESULT: begin
                    result <= dp[K_in];
                    done <= 1;
                end
                DONE: begin
                    if (!start) begin
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule