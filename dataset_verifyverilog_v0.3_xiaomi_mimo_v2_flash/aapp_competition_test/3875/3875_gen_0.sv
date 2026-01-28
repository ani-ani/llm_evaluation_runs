module lis_expected_value #(
    parameter N = 6,
    parameter DATA_WIDTH = 32,
    parameter MOD = 1000000007
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] A [0:N-1],
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD_A     = 4'd1;
    localparam [3:0] GEN_PERM   = 4'd2;
    localparam [3:0] CALC_COUNT = 4'd3;
    localparam [3:0] CALC_LIS   = 4'd4;
    localparam [3:0] ACCUMULATE = 4'd5;
    localparam [3:0] FINISH     = 4'd6;
    
    reg [3:0] state;
    reg [DATA_WIDTH-1:0] a_reg [0:N-1];
    reg [DATA_WIDTH-1:0] total_sum;
    reg [DATA_WIDTH-1:0] product_inv;
    reg [DATA_WIDTH-1:0] count_val;
    reg [DATA_WIDTH-1:0] lis_val;
    reg [5:0] perm_index;
    reg [2:0] phase;
    reg [2:0] ranks [0:N-1];
    
    // DP table for sequence counting
    reg [DATA_WIDTH-1:0] dp [0:N][0:N];
    
    // Helper signals
    reg [DATA_WIDTH-1:0] temp_lis;
    reg [DATA_WIDTH-1:0] temp_prod;
    
    integer i, j, k;
    integer y;
    reg [DATA_WIDTH-1:0] x_reg;
    
    // Modular inverse function
    function [DATA_WIDTH-1:0] mod_inv;
        input [DATA_WIDTH-1:0] x;
        begin
            y = MOD - 2;
            mod_inv = 1;
            x_reg = x;
            while (y > 0) begin
                if (y & 1) mod_inv = (mod_inv * x_reg) % MOD;
                x_reg = (x_reg * x_reg) % MOD;
                y = y >> 1;
            end
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            total_sum <= 0;
            product_inv <= 1;
            perm_index <= 0;
            phase <= 0;
            count_val <= 0;
            lis_val <= 0;
            temp_lis <= 0;
            temp_prod <= 0;
            for (i = 0; i < N; i = i + 1) begin
                a_reg[i] <= 0;
                ranks[i] <= 0;
            end
            for (i = 0; i <= N; i = i + 1) begin
                for (j = 0; j <= N; j = j + 1) begin
                    dp[i][j] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_A;
                        done <= 0;
                        total_sum <= 0;
                        product_inv <= 1;
                        perm_index <= 0;
                        phase <= 0;
                        count_val <= 0;
                        lis_val <= 0;
                        temp_lis <= 0;
                        temp_prod <= 0;
                        for (i = 0; i < N; i = i + 1) begin
                            a_reg[i] <= 0;
                            ranks[i] <= 0;
                        end
                        for (i = 0; i <= N; i = i + 1) begin
                            for (j = 0; j <= N; j = j + 1) begin
                                dp[i][j] <= 0;
                            end
                        end
                    end
                end
                
                LOAD_A: begin
                    // Load A values and compute initial product inverse
                    for (i = 0; i < N; i = i + 1) begin
                        a_reg[i] <= A[i];
                        if (i == 0) begin
                            product_inv <= mod_inv(A[i]);
                        end else begin
                            product_inv <= (product_inv * mod_inv(A[i])) % MOD;
                        end
                    end
                    state <= GEN_PERM;
                end
                
                GEN_PERM: begin
                    // Generate next non-decreasing permutation pattern
                    if (phase == 0) begin
                        // Initialize ranks for current perm_index
                        for (i = 0; i < N; i = i + 1) begin
                            if (N == 6) begin
                                ranks[i] <= (perm_index >> (i * 2)) & 3;
                            end else begin
                                ranks[i] <= (perm_index >> i) & 1;
                            end
                        end
                        phase <= 1;
                    end else if (phase == 1) begin
                        // Bubble sort to make non-decreasing
                        for (i = 0; i < N - 1; i = i + 1) begin
                            for (j = 0; j < N - 1 - i; j = j + 1) begin
                                if (ranks[j] > ranks[j + 1]) begin
                                    ranks[j] <= ranks[j + 1];
                                    ranks[j + 1] <= ranks[j];
                                end
                            end
                        end
                        phase <= 2;
                    end else if (phase == 2) begin
                        // Check if processed all permutations
                        if (perm_index >= 256) begin
                            state <= FINISH;
                        end else begin
                            state <= CALC_COUNT;
                            phase <= 0;
                        end
                    end
                end
                
                CALC_COUNT: begin
                    // Calculate number of sequences matching rank pattern
                    // Initialize DP
                    for (i = 0; i <= N; i = i + 1) begin
                        for (j = 0; j <= N; j = j + 1) begin
                            dp[i][j] <= 0;
                        end
                    end
                    dp[0][0] <= 1;
                    
                    // Compute DP
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j <= N; j = j + 1) begin
                            if (dp[i][j] != 0) begin
                                // Only allow if rank matches
                                if (ranks[i] == j) begin
                                    dp[i + 1][j] <= (dp[i + 1][j] + dp[i][j]) % MOD;
                                end
                                // Allow skipping to next rank
                                if (j + 1 <= N && ranks[i] >= j) begin
                                    dp[i + 1][j + 1] <= (dp[i + 1][j + 1] + dp[i][j]) % MOD;
                                end
                            end
                        end
                    end
                    
                    count_val <= dp[N][N];
                    state <= CALC_LIS;
                end
                
                CALC_LIS: begin
                    // Calculate LIS length for current rank pattern
                    temp_lis <= 0;
                    temp_prod <= 1;
                    for (i = 0; i < N; i = i + 1) begin
                        if (i > 0 && ranks[i] != ranks[i - 1]) begin
                            temp_lis <= temp_lis + 1;
                        end
                    end
                    lis_val <= temp_lis + 1;
                    state <= ACCUMULATE;
                end
                
                ACCUMULATE: begin
                    // Accumulate: total_sum += count_val * lis_val
                    total_sum <= (total_sum + count_val * lis_val) % MOD;
                    perm_index <= perm_index + 1;
                    state <= GEN_PERM;
                    phase <= 0;
                end
                
                FINISH: begin
                    // Final result: total_sum * product_inv % MOD
                    result <= (total_sum * product_inv) % MOD;
                    done <= 1;
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule