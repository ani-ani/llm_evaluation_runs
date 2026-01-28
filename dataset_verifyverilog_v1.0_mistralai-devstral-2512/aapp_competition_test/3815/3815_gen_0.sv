module AlternatingSumMod(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n,
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [7:0] k,
    input wire [7:0] seq,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] M = 32'd1000000009;
    localparam [31:0] M_MINUS_2 = 32'd1000000007;

    // States
    localparam [4:0] IDLE = 5'd0;
    localparam [4:0] INV_A = 5'd1;
    localparam [4:0] EXP_B_K = 5'd2;
    localparam [4:0] EXP_A_K = 5'd3;
    localparam [4:0] CALC_Q = 5'd4;
    localparam [4:0] CALC_T = 5'd5;
    localparam [4:0] EXP_Q_T = 5'd6;
    localparam [4:0] CALC_D = 5'd7;
    localparam [4:0] PERIOD_SUM = 5'd8;
    localparam [4:0] FINAL_MULT = 5'd9;

    // State and control
    reg [4:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Intermediate results
    reg [31:0] inv_a;
    reg [31:0] exp_b_k;
    reg [31:0] exp_a_k;
    reg [31:0] Q;
    reg [31:0] T;
    reg [31:0] exp_q_t;
    reg [31:0] D;
    reg [31:0] period_sum;
    reg [31:0] base_term;
    reg [31:0] c_ratio;

    // Exponentiation state
    reg [31:0] exp_base;
    reg [31:0] exp_result;
    reg [31:0] exp_exponent;
    reg [4:0] exp_state;
    localparam [4:0] EXP_IDLE = 5'd0;
    localparam [4:0] EXP_COMPUTE = 5'd1;

    // Period sum iteration
    reg [7:0] i;

    // Modular multiplication function
    function [31:0] mod_mult;
        input [31:0] x, y;
        reg [63:0] product;
        begin
            product = x * y;
            mod_mult = product % M;
        end
    endfunction

    // Modular exponentiation function
    function [31:0] mod_exp;
        input [31:0] base, exponent;
        reg [31:0] result;
        reg [31:0] current_base;
        reg [31:0] current_exponent;
        integer j;
        begin
            result = 1;
            current_base = base % M;
            current_exponent = exponent;
            for (j = 0; j < 32; j = j + 1) begin
                if (current_exponent[0]) begin
                    result = mod_mult(result, current_base);
                end
                current_base = mod_mult(current_base, current_base);
                current_exponent = current_exponent >> 1;
            end
            mod_exp = result;
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 32'd0;
            inv_a <= 32'd0;
            exp_b_k <= 32'd0;
            exp_a_k <= 32'd0;
            Q <= 32'd0;
            T <= 32'd0;
            exp_q_t <= 32'd0;
            D <= 32'd0;
            period_sum <= 32'd0;
            base_term <= 32'd0;
            c_ratio <= 32'd0;
            exp_state <= EXP_IDLE;
            i <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INV_A;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INV_A: begin
                    inv_a <= mod_exp(a, M_MINUS_2);
                    next_state <= EXP_B_K;
                end

                EXP_B_K: begin
                    exp_b_k <= mod_exp(b, k);
                    next_state <= EXP_A_K;
                end

                EXP_A_K: begin
                    exp_a_k <= mod_exp(inv_a, k);
                    next_state <= CALC_Q;
                end

                CALC_Q: begin
                    Q <= mod_mult(exp_b_k, exp_a_k);
                    next_state <= CALC_T;
                end

                CALC_T: begin
                    T <= (n + 32'd1) / k;
                    next_state <= EXP_Q_T;
                end

                EXP_Q_T: begin
                    exp_q_t <= mod_exp(Q, T);
                    next_state <= CALC_D;
                end

                CALC_D: begin
                    if (Q == 1) begin
                        D <= T;
                    end else begin
                        D <= mod_mult((exp_q_t - 1 + M) % M, mod_exp((Q - 1 + M) % M, M_MINUS_2));
                    end
                    next_state <= PERIOD_SUM;
                    i <= 8'd0;
                    base_term <= mod_exp(a, n);
                    c_ratio <= mod_mult(b, inv_a);
                    period_sum <= 32'd0;
                end

                PERIOD_SUM: begin
                    if (i < k) begin
                        if (seq[i]) begin
                            period_sum <= (period_sum + base_term) % M;
                        end else begin
                            period_sum <= (period_sum - base_term + M) % M;
                        end
                        base_term <= mod_mult(base_term, c_ratio);
                        i <= i + 8'd1;
                        next_state <= PERIOD_SUM;
                    end else begin
                        next_state <= FINAL_MULT;
                    end
                end

                FINAL_MULT: begin
                    result <= mod_mult(mod_mult(base_term, period_sum), D);
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule