module periodic_sum (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] a,
  input [7:0] b,
  input [1:0] k,
  input [3:0] s,
  output reg [23:0] result,
  output reg done
);

  // Constants
  localparam MOD = 24'hFFFFFF; // 16777213 (2^24 - 11)
  localparam MOD_MINUS_2 = 24'hFFFFFD; // MOD-2 for Fermat's little theorem

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    COMPUTE_INV_A,
    COMPUTE_B_INV_A,
    COMPUTE_Q,
    COMPUTE_T,
    COMPUTE_SUM_PERIOD,
    CHECK_Q_EQ_1,
    COMPUTE_Q_POW_T,
    COMPUTE_DENOM_INV,
    COMPUTE_RESULT,
    DONE
  } state_t;

  state_t state;

  // Internal registers
  reg [23:0] inv_a;
  reg [23:0] b_inv_a;
  reg [23:0] q;
  reg [23:0] T;
  reg [23:0] SumPeriod;
  reg [23:0] q_pow_T;
  reg [23:0] denom_inv;
  reg [23:0] temp;
  reg [23:0] exponent;
  reg [23:0] base;
  reg [23:0] result_temp;
  reg [3:0] i;
  reg [1:0] k_reg;
  reg [3:0] s_reg;
  reg [7:0] n_reg;
  reg [7:0] a_reg;
  reg [7:0] b_reg;
  reg [23:0] a_pow_n;

  // Modular multiplication
  function [23:0] mod_mult;
    input [23:0] x, y;
    reg [47:0] prod;
    begin
      prod = x * y;
      mod_mult = prod % MOD;
    end
  endfunction

  // Modular exponentiation (square-and-multiply)
  function [23:0] mod_exp;
    input [23:0] base_in;
    input [23:0] exp_in;
    reg [23:0] result;
    reg [23:0] base_temp;
    reg [23:0] exp_temp;
    begin
      result = 1;
      base_temp = base_in;
      exp_temp = exp_in;
      while (exp_temp != 0) begin
        if (exp_temp[0]) begin
          result = mod_mult(result, base_temp);
        end
        base_temp = mod_mult(base_temp, base_temp);
        exp_temp = exp_temp >> 1;
      end
      mod_exp = result;
    end
  endfunction

  // Modular inverse using Fermat's little theorem
  function [23:0] mod_inv;
    input [23:0] x;
    begin
      mod_inv = mod_exp(x, MOD_MINUS_2);
    end
  endfunction

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Latch inputs
            n_reg <= n;
            a_reg <= a;
            b_reg <= b;
            k_reg <= k;
            s_reg <= s;
            state <= COMPUTE_INV_A;
          end
        end

        COMPUTE_INV_A: begin
          inv_a <= mod_inv(a_reg);
          state <= COMPUTE_B_INV_A;
        end

        COMPUTE_B_INV_A: begin
          b_inv_a <= mod_mult(b_reg, inv_a);
          state <= COMPUTE_Q;
        end

        COMPUTE_Q: begin
          q <= mod_exp(b_inv_a, k_reg);
          state <= COMPUTE_T;
        end

        COMPUTE_T: begin
          T <= (n_reg + 1) / k_reg;
          state <= COMPUTE_SUM_PERIOD;
          i <= 0;
          SumPeriod <= 0;
        end

        COMPUTE_SUM_PERIOD: begin
          if (i < k_reg) begin
            // Compute a^n
            a_pow_n <= mod_exp(a_reg, n_reg);
            // Compute (b_inv_a)^i
            temp <= mod_exp(b_inv_a, i);
            // Compute term = s_i * a^n * (b/a)^i
            if (s_reg[i]) begin
              temp <= mod_mult(a_pow_n, temp);
            end else begin
              temp <= mod_mult(a_pow_n, mod_mult(temp, MOD - 1));
            end
            SumPeriod <= mod_mult(SumPeriod, temp);
            i <= i + 1;
          end else begin
            state <= CHECK_Q_EQ_1;
          end
        end

        CHECK_Q_EQ_1: begin
          if (q == 1) begin
            result_temp <= mod_mult(SumPeriod, T);
            state <= DONE;
          end else begin
            state <= COMPUTE_Q_POW_T;
          end
        end

        COMPUTE_Q_POW_T: begin
          q_pow_T <= mod_exp(q, T);
          state <= COMPUTE_DENOM_INV;
        end

        COMPUTE_DENOM_INV: begin
          denom_inv <= mod_inv(mod_mult(q, MOD - 1));
          state <= COMPUTE_RESULT;
        end

        COMPUTE_RESULT: begin
          temp <= mod_mult(q_pow_T, MOD - 1);
          temp <= mod_mult(temp, denom_inv);
          result_temp <= mod_mult(SumPeriod, temp);
          state <= DONE;
        end

        DONE: begin
          result <= result_temp;
          done <= 1;
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
          done <= 0;
        end
      endcase
    end
  end

endmodule