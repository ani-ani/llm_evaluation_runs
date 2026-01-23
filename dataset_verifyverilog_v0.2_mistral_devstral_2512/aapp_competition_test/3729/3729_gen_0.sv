module probability_calculator (
  input clk,
  input rst_n,
  input start,
  input [16:0] f,
  input [16:0] w,
  input [16:0] h,
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam M = 1000000007;
  localparam MAX_N = 200000;
  localparam LOG2_MAX_N = 18;

  // State machine
  typedef enum logic [5:0] {
    IDLE,
    PREPARE,
    CALCULATE,
    INVERSE,
    FINALIZE,
    DONE
  } state_t;
  state_t state, next_state;

  // Factorial LUT (28 bits per entry)
  reg [27:0] fac [0:MAX_N];

  // Internal registers
  reg [16:0] n, r;
  reg [27:0] total_count, valid_count;
  reg [27:0] inv_total_count;
  reg [16:0] k;
  reg [16:0] k_max;
  reg [16:0] cnt;
  reg [27:0] temp1, temp2, temp3;
  reg [27:0] pow_base, pow_exp, pow_result;
  reg [27:0] sum_valid;

  // Modular exponentiation state
  reg [4:0] pow_state;
  reg [27:0] pow_acc;

  // State machine transitions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PREPARE;
      end
      PREPARE: begin
        if (cnt == MAX_N) next_state = CALCULATE;
      end
      CALCULATE: begin
        if (k == k_max) next_state = INVERSE;
      end
      INVERSE: begin
        if (pow_state == 0) next_state = FINALIZE;
      end
      FINALIZE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Factorial LUT initialization
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 0;
      fac[0] <= 1;
    end else if (state == PREPARE) begin
      if (cnt == 0) begin
        fac[0] <= 1;
        cnt <= 1;
      end else if (cnt < MAX_N) begin
        fac[cnt] <= (fac[cnt-1] * cnt) % M;
        cnt <= cnt + 1;
      end
    end
  end

  // Main computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_count <= 0;
      valid_count <= 0;
      sum_valid <= 0;
      k <= 0;
      k_max <= 0;
    end else if (state == CALCULATE) begin
      if (k == 0) begin
        // Compute total_count = nCr(f + w, w)
        if (f > 0 && w > 0) begin
          n = f + w;
          r = w;
          total_count <= (fac[n] * mod_inv(fac[r]) % M) % M * mod_inv(fac[n - r]) % M;
        end else begin
          total_count <= 1;
        end

        // Compute valid_count
        if (w == 0) begin
          valid_count <= 1;
        end else begin
          k_max = (w / (h + 1)) < (f + 1) ? (w / (h + 1)) : (f + 1);
          k <= 1;
          sum_valid <= 0;
        end
      end else if (k <= k_max) begin
        // Compute term: nCr(f+1, k) * nCr(w - k*h - 1, k-1)
        temp1 = (fac[f+1] * mod_inv(fac[k]) % M) % M * mod_inv(fac[f+1 - k]) % M;
        temp2 = (w - k*h - 1) >= (k - 1) ? 
                (fac[w - k*h - 1] * mod_inv(fac[k-1]) % M) % M * mod_inv(fac[w - k*h - 1 - (k-1)]) % M : 0;
        sum_valid <= (sum_valid + temp1 * temp2 % M) % M;
        k <= k + 1;
      end else begin
        valid_count <= sum_valid;
      end
    end
  end

  // Modular inverse computation (using modular exponentiation)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pow_state <= 0;
      pow_base <= 0;
      pow_exp <= 0;
      pow_result <= 0;
      pow_acc <= 0;
    end else if (state == INVERSE) begin
      case (pow_state)
        0: begin
          pow_base <= total_count;
          pow_exp <= M - 2;
          pow_result <= 1;
          pow_acc <= pow_base;
          pow_state <= 1;
        end
        1: begin
          if (pow_exp[0]) begin
            pow_result <= (pow_result * pow_acc) % M;
          end
          pow_acc <= (pow_acc * pow_acc) % M;
          pow_exp <= pow_exp >> 1;
          if (pow_exp == 0) begin
            pow_state <= 0;
            inv_total_count <= pow_result;
          end
        end
      endcase
    end
  end

  // Final result computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (state == FINALIZE) begin
      result <= (valid_count * inv_total_count) % M;
      done <= 1;
    end else if (state == DONE) begin
      if (!start) begin
        done <= 0;
        result <= 0;
      end
    end
  end

  // Modular inverse function (using Fermat's little theorem)
  function [27:0] mod_inv;
    input [27:0] x;
    reg [27:0] res;
    reg [27:0] a;
    reg [27:0] b;
    reg [27:0] exp;
    begin
      if (x == 0) begin
        res = 0;
      end else begin
        a = x;
        exp = M - 2;
        res = 1;
        while (exp > 0) begin
          if (exp[0]) begin
            res = (res * a) % M;
          end
          a = (a * a) % M;
          exp = exp >> 1;
        end
      end
      mod_inv = res;
    end
  endfunction

endmodule