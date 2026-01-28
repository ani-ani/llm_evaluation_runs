module WeightUpdateSimulator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [11:0] m,
    input wire [19:0] a,
    input wire [31:0] w [0:19],
    output reg [31:0] result [0:19],
    output reg done
);

    // Constants
    localparam MOD = 32'd998244353;
    localparam MAX_N = 20;
    localparam MAX_M = 3000;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_SUM = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_UPDATE = 3'd3;
    localparam [2:0] COMPUTE_RESULT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [31:0] total_liked_sum;
    reg [31:0] total_disliked_sum;
    reg [31:0] total_weight;
    reg [31:0] dp [0:MAX_M];
    reg [31:0] dp_next [0:MAX_M];
    reg [11:0] step;
    reg [11:0] k;
    reg [31:0] temp;
    reg [31:0] inv_total;
    reg [31:0] prob_liked;
    reg [31:0] prob_disliked;
    reg [31:0] expected_additions;
    reg [31:0] expected_subtractions;
    reg [31:0] sum_liked_weights;
    reg [31:0] sum_disliked_weights;
    reg [31:0] sum_liked_weights_scaled;
    reg [31:0] sum_disliked_weights_scaled;
    reg [31:0] inv_mod;
    reg [31:0] inv_mod_scaled;

    // Modular inverse of MOD (precomputed for 998244353)
    localparam INV_MOD = 32'd1; // Since MOD is prime, but we'll compute it

    // Modular exponentiation for inverse
    function [31:0] mod_inverse;
        input [31:0] a;
        reg [31:0] result;
        reg [31:0] base;
        reg [31:0] exp;
        reg [31:0] mod;
        begin
            base = a;
            exp = MOD - 2;
            mod = MOD;
            result = 1;
            while (exp > 0) begin
                if (exp[0]) begin
                    result = (result * base) % mod;
                end
                base = (base * base) % mod;
                exp = exp >> 1;
            end
            mod_inverse = result;
        end
    endfunction

    // Modular multiplication
    function [31:0] mod_mult;
        input [31:0] a, b;
        reg [63:0] temp;
        begin
            temp = a * b;
            mod_mult = temp % MOD;
        end
    endfunction

    // Modular addition
    function [31:0] mod_add;
        input [31:0] a, b;
        begin
            mod_add = (a + b) % MOD;
        end
    endfunction

    // Modular subtraction
    function [31:0] mod_sub;
        input [31:0] a, b;
        begin
            mod_sub = (a - b + MOD) % MOD;
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            total_liked_sum <= 32'd0;
            total_disliked_sum <= 32'd0;
            total_weight <= 32'd0;
            done <= 1'b0;
            step <= 12'd0;
            k <= 12'd0;
            expected_additions <= 32'd0;
            expected_subtractions <= 32'd0;
            sum_liked_weights <= 32'd0;
            sum_disliked_weights <= 32'd0;
            sum_liked_weights_scaled <= 32'd0;
            sum_disliked_weights_scaled <= 32'd0;
            inv_mod <= 32'd0;
            inv_mod_scaled <= 32'd0;
            for (integer i = 0; i < MAX_M + 1; i = i + 1) begin
                dp[i] <= 32'd0;
                dp_next[i] <= 32'd0;
            end
            for (integer i = 0; i < MAX_N; i = i + 1) begin
                result[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_SUM;
                    end
                end

                COMPUTE_SUM: begin
                    total_liked_sum <= 32'd0;
                    total_disliked_sum <= 32'd0;
                    sum_liked_weights <= 32'd0;
                    sum_disliked_weights <= 32'd0;
                    for (integer i = 0; i < n; i = i + 1) begin
                        if (a[i]) begin
                            total_liked_sum <= mod_add(total_liked_sum, w[i]);
                            sum_liked_weights <= mod_add(sum_liked_weights, w[i]);
                        end else begin
                            total_disliked_sum <= mod_add(total_disliked_sum, w[i]);
                            sum_disliked_weights <= mod_add(sum_disliked_weights, w[i]);
                        end
                    end
                    total_weight <= mod_add(total_liked_sum, total_disliked_sum);
                    inv_total <= mod_inverse(total_weight);
                    prob_liked <= mod_mult(total_liked_sum, inv_total);
                    prob_disliked <= mod_mult(total_disliked_sum, inv_total);
                    state <= DP_INIT;
                end

                DP_INIT: begin
                    dp[0] <= 32'd1;
                    for (integer i = 1; i < MAX_M + 1; i = i + 1) begin
                        dp[i] <= 32'd0;
                    end
                    step <= 12'd0;
                    state <= DP_UPDATE;
                end

                DP_UPDATE: begin
                    if (step < m) begin
                        for (integer i = 0; i < MAX_M + 1; i = i + 1) begin
                            dp_next[i] <= 32'd0;
                        end
                        for (integer i = 0; i <= step; i = i + 1) begin
                            if (dp[i] != 32'd0) begin
                                // Transition to i+1 (liked)
                                if (i + 1 <= MAX_M) begin
                                    dp_next[i + 1] <= mod_add(dp_next[i + 1], mod_mult(dp[i], prob_liked));
                                end
                                // Transition to i (disliked)
                                dp_next[i] <= mod_add(dp_next[i], mod_mult(dp[i], prob_disliked));
                            end
                        end
                        for (integer i = 0; i < MAX_M + 1; i = i + 1) begin
                            dp[i] <= dp_next[i];
                        end
                        step <= step + 12'd1;
                    end else begin
                        state <= COMPUTE_RESULT;
                    end
                end

                COMPUTE_RESULT: begin
                    expected_additions <= 32'd0;
                    expected_subtractions <= 32'd0;
                    for (integer k = 0; k < MAX_M + 1; k = k + 1) begin
                        expected_additions <= mod_add(expected_additions, mod_mult(dp[k], k));
                        expected_subtractions <= mod_add(expected_subtractions, mod_mult(dp[k], mod_sub(m, k)));
                    end
                    for (integer i = 0; i < n; i = i + 1) begin
                        if (a[i]) begin
                            result[i] <= mod_add(w[i], mod_mult(expected_additions, inv_total));
                        end else begin
                            result[i] <= mod_sub(w[i], mod_mult(expected_subtractions, inv_total));
                        end
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule