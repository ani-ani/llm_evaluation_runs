module SubsetCostSum(
    input         clk,
    input         rst_n,
    input         start,
    input  [31:0] N,
    input  [7:0]  k,
    output [31:0] result,
    output        done
);

    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MAX_K = 8;
    localparam [31:0] inv2 = 32'd500000004;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STIRLING = 3'd1;
    localparam [2:0] FACTORIAL = 3'd2;
    localparam [2:0] BINOMIAL = 3'd3;
    localparam [2:0] EXPONENT = 3'd4;
    localparam [2:0] SUM = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    reg [31:0] dp [0:MAX_K];
    reg [31:0] fact [0:MAX_K];
    reg [31:0] comb [0:MAX_K];
    reg [31:0] pow2_N;
    reg [31:0] pow2_N_i;
    reg [31:0] current_result;
    reg [31:0] temp;
    reg [31:0] i_reg, j_reg;
    reg [31:0] n_reg, m_reg;
    reg [31:0] base, exp;
    reg [31:0] result_reg;
    reg [31:0] done_reg;
    reg [31:0] cycle_count;
    reg [31:0] max_cycles;

    // Precomputed modular inverses for 1..8
    localparam [31:0] inv [1:8] = '{32'd1, 32'd500000004, 32'd166666668, 32'd83333334, 32'd41666667, 32'd13888889, 32'd115740741, 32'd97222222};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
            cycle_count <= 32'd0;
            i_reg <= 32'd0;
            j_reg <= 32'd0;
            n_reg <= 32'd0;
            m_reg <= 32'd0;
            base <= 32'd0;
            exp <= 32'd0;
            temp <= 32'd0;
            current_result <= 32'd0;
            pow2_N <= 32'd0;
            pow2_N_i <= 32'd0;
            for (integer i = 0; i <= MAX_K; i = i + 1) begin
                dp[i] <= 32'd0;
                fact[i] <= 32'd0;
                comb[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done_reg = 1'b0;
                if (start) begin
                    next_state = STIRLING;
                    i_reg = 32'd0;
                    j_reg = 32'd0;
                    dp[0] = 32'd1;
                    for (integer i = 1; i <= MAX_K; i = i + 1) begin
                        dp[i] = 32'd0;
                    end
                end
            end

            STIRLING: begin
                if (i_reg < k) begin
                    if (j_reg > i_reg) begin
                        j_reg = j_reg - 32'd1;
                        dp[j_reg] = (j_reg * dp[j_reg] + dp[j_reg - 1]) % MOD;
                    end else if (j_reg == i_reg) begin
                        dp[j_reg] = (j_reg * dp[j_reg] + dp[j_reg - 1]) % MOD;
                        i_reg = i_reg + 32'd1;
                        j_reg = i_reg;
                    end
                end else begin
                    next_state = FACTORIAL;
                    i_reg = 32'd0;
                    fact[0] = 32'd1;
                end
            end

            FACTORIAL: begin
                if (i_reg < k) begin
                    i_reg = i_reg + 32'd1;
                    fact[i_reg] = (fact[i_reg - 1] * i_reg) % MOD;
                end else begin
                    next_state = BINOMIAL;
                    i_reg = 32'd0;
                    comb[0] = 32'd1;
                end
            end

            BINOMIAL: begin
                if (i_reg < k) begin
                    i_reg = i_reg + 32'd1;
                    comb[i_reg] = (comb[i_reg - 1] * (N - i_reg + 1)) % MOD;
                    comb[i_reg] = (comb[i_reg] * inv[i_reg]) % MOD;
                end else begin
                    next_state = EXPONENT;
                    base = 32'd2;
                    exp = N;
                    pow2_N = 32'd1;
                end
            end

            EXPONENT: begin
                if (exp > 0) begin
                    if (exp[0]) begin
                        pow2_N = (pow2_N * base) % MOD;
                    end
                    base = (base * base) % MOD;
                    exp = exp >> 1;
                end else begin
                    next_state = SUM;
                    i_reg = 32'd0;
                    current_result = 32'd0;
                    pow2_N_i = pow2_N;
                end
            end

            SUM: begin
                if (i_reg <= k) begin
                    temp = (dp[i_reg] * fact[i_reg]) % MOD;
                    temp = (temp * comb[i_reg]) % MOD;
                    temp = (temp * pow2_N_i) % MOD;
                    current_result = (current_result + temp) % MOD;
                    pow2_N_i = (pow2_N_i * inv2) % MOD;
                    i_reg = i_reg + 32'd1;
                end else begin
                    next_state = DONE_STATE;
                    result_reg = current_result;
                end
            end

            DONE_STATE: begin
                done_reg = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    assign result = result_reg;
    assign done = done_reg;

endmodule