module subset_cost_sum (
  input clk,
  input rst_n,
  input start,
  input [19:0] n,
  input [12:0] k,
  output reg [31:0] result,
  output reg done
);

  parameter M = 32'h3B9ACA07; // 10^9+7
  parameter MAX_K = 5000;

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_STIRLING,
    CALC_FACT,
    CALC_RESULT,
    DONE
  } state_t;

  state_t state = IDLE;

  // Stirling numbers storage (simulated BRAM)
  reg [31:0] stirling [0:MAX_K][0:MAX_K];

  // Factorials and inverses
  reg [31:0] fact [0:MAX_K];
  reg [31:0] inv_fact [0:MAX_K];

  // Counters
  reg [12:0] i = 0;
  reg [12:0] j = 0;
  reg [12:0] m = 0;

  // Intermediate values
  reg [31:0] temp = 0;
  reg [31:0] comb = 0;
  reg [31:0] power2 = 0;
  reg [31:0] acc = 0;

  // Modular exponentiation
  function [31:0] mod_exp;
    input [31:0] base;
    input [31:0] exp;
    input [31:0] mod;
    reg [31:0] result = 1;
    reg [31:0] b = base % mod;
    reg [31:0] e = exp;
    begin
      while (e > 0) begin
        if (e[0]) result = (result * b) % mod;
        b = (b * b) % mod;
        e = e >> 1;
      end
      mod_exp = result;
    end
  endfunction

  // Modular inverse using Fermat's little theorem
  function [31:0] mod_inv;
    input [31:0] a;
    input [31:0] mod;
    begin
      mod_inv = mod_exp(a, mod-2, mod);
    end
  endfunction

  // Modular multiplication
  function [31:0] mod_mul;
    input [31:0] a;
    input [31:0] b;
    input [31:0] mod;
    begin
      mod_mul = (a * b) % mod;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      j <= 0;
      m <= 0;
      temp <= 0;
      comb <= 0;
      power2 <= 0;
      acc <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_STIRLING;
            i <= 1;
            j <= 1;
            // Initialize Stirling numbers
            stirling[0][0] <= 1;
            for (m = 1; m <= k; m = m + 1) begin
              stirling[m][0] <= 0;
              stirling[0][m] <= 0;
            end
            stirling[1][1] <= 1;
          end
        end

        CALC_STIRLING: begin
          if (i <= k && j <= i) begin
            if (i == 1 && j == 1) begin
              stirling[i][j] <= 1;
            end else if (j == 1) begin
              stirling[i][j] <= 1;
            end else if (j == i) begin
              stirling[i][j] <= 1;
            end else begin
              stirling[i][j] <= (stirling[i-1][j-1] + mod_mul(j, stirling[i-1][j], M)) % M;
            end

            if (j == i) begin
              j <= 1;
              i <= i + 1;
            end else begin
              j <= j + 1;
            end
          end else begin
            state <= CALC_FACT;
            i <= 1;
            fact[0] <= 1;
          end
        end

        CALC_FACT: begin
          if (i <= k) begin
            fact[i] <= mod_mul(fact[i-1], i, M);
            i <= i + 1;
          end else begin
            state <= CALC_RESULT;
            i <= 1;
            acc <= 0;
            // Precompute 2^n mod M
            power2 <= mod_exp(2, n, M);
          end
        end

        CALC_RESULT: begin
          if (i <= k) begin
            // Compute C(n,i) = n*(n-1)*...*(n-i+1) / i!
            comb <= 1;
            for (m = 0; m < i; m = m + 1) begin
              comb <= mod_mul(comb, (n - m), M);
            end
            comb <= mod_mul(comb, mod_inv(fact[i], M), M);

            // Compute 2^(n-i) = 2^n * inv(2^i)
            temp <= mod_mul(power2, mod_inv(mod_exp(2, i, M), M), M);

            // Accumulate: S(k,i) * i! * C(n,i) * 2^(n-i)
            temp <= mod_mul(stirling[k][i], fact[i], M);
            temp <= mod_mul(temp, comb, M);
            temp <= mod_mul(temp, temp, M); // Wait, this is wrong
            // Correction:
            temp <= mod_mul(stirling[k][i], fact[i], M);
            temp <= mod_mul(temp, comb, M);
            temp <= mod_mul(temp, mod_mul(power2, mod_inv(mod_exp(2, i, M), M), M), M);

            acc <= (acc + temp) % M;

            i <= i + 1;
          end else begin
            state <= DONE;
            result <= acc;
            done <= 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule