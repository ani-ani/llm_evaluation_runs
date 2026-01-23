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
    parameter MOD = 20'hF4243; // 1000007
    
    // State definitions
    localparam S_IDLE = 3'b000;
    localparam S_INIT = 3'b001;
    localparam S_ITERATE_N = 3'b010;
    localparam S_COMPUTE_K = 3'b011;
    localparam S_COPY_K = 3'b100;
    localparam S_DONE = 3'b101;

    // Input registers
    reg [6:0] N_reg, M_reg, K_reg;

    // DP Storage: Array of size 128 as requested
    reg [19:0] dp [127:0];

    // Buffer for new row values (Size K_max+1 = 65)
    reg [19:0] new_vals [64:0];

    // State and Counters
    reg [2:0] state;
    reg [6:0] n_cnt; // Outer loop counter (1 to N)
    reg [6:0] k_cnt; // Inner loop counter (1 to K)

    // Combinational calculation logic for the recurrence
    // C(n,k) = C(n,k-1) + C(n-1,k) - C(n-1,k-m)
    wire [19:0] dp_read_A; // C(n-1, k-1) or C(n, k-1) depending on stage, but here used for prev row
    wire [19:0] dp_read_B; // C(n-1, k)
    wire [19:0] dp_read_C; // C(n-1, k-m)
    wire signed [21:0] sum_raw;
    wire signed [21:0] sum_positive;
    wire [19:0] next_val;

    assign dp_read_A = dp[k_cnt - 1];
    assign dp_read_B = dp[k_cnt];
    assign dp_read_C = (k_cnt > M_reg) ? dp[k_cnt - M_reg] : 20'd0;

    assign sum_raw = {1'b0, dp_read_A} + {1'b0, dp_read_B} - {1'b0, dp_read_C};
    // Handle negative result
    assign sum_positive = (sum_raw < 0) ? (sum_raw + MOD) : sum_raw;
    // Handle modulo (if sum >= MOD)
    assign next_val = (sum_positive >= MOD) ? (sum_positive - MOD) : sum_positive;

    // Synchronous Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_INIT;
                        N_reg <= N_in;
                        M_reg <= M_in;
                        K_reg <= K_in;
                        k_cnt <= 0; // Used for clearing loop
                    end
                end

                S_INIT: begin
                    // Initialize DP array: dp[0] = 1, dp[1..127] = 0
                    if (k_cnt <= 127) begin
                        if (k_cnt == 0)
                            dp[0] <= 1;
                        else
                            dp[k_cnt] <= 0;
                        k_cnt <= k_cnt + 1;
                    end else begin
                        // Finished initialization
                        state <= S_ITERATE_N;
                        n_cnt <= 1; // Start from type 1
                    end
                end

                S_ITERATE_N: begin
                    // Check if we have processed N types
                    if (n_cnt > N_reg) begin
                        state <= S_DONE;
                    end else begin
                        // Start K loop for computation
                        k_cnt <= 1;
                        state <= S_COMPUTE_K;
                    end
                end

                S_COMPUTE_K: begin
                    // Calculate new value using the combinational logic
                    new_vals[k_cnt] <= next_val;
                    
                    if (k_cnt < K_reg) begin
                        k_cnt <= k_cnt + 1;
                        // Stay in this state
                    end else begin
                        // Finished computing all K values for current N
                        k_cnt <= 1; // Reset for copy loop
                        state <= S_COPY_K;
                    end
                end

                S_COPY_K: begin
                    // Copy calculated values back to DP array
                    dp[k_cnt] <= new_vals[k_cnt];

                    if (k_cnt < K_reg) begin
                        k_cnt <= k_cnt + 1;
                    end else begin
                        // Finished copying
                        n_cnt <= n_cnt + 1; // Next type
                        state <= S_ITERATE_N;
                    end
                end

                S_DONE: begin
                    // Output result: dp[K_reg]
                    result <= dp[K_reg];
                    done <= 1;
                end
            endcase
        end
    end

endmodule