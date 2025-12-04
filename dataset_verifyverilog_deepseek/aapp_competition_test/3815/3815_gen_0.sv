module alternating_sum_mod(
  input clk,           
  input rst_n,         
  input start,         
  input [14:0] n,      
  input [15:0] a,      
  input [15:0] b,      
  input [3:0] k,       
  input [15:0] s,      
  output reg [9:0] result, 
  output reg done      
);

typedef enum logic [2:0] { IDLE, PRE_COMPUTE, PROCESS_BLOCK, MULT_TERMS, ACCUMULATE, DONE_ST } state_e;
reg [9:0] mod = 10'd997;

// Exponentiator signals
reg [15:0] exp_base;
reg [14:0] exp_exponent;
wire [9:0] exp_result;
wire exp_done;
reg exp_start;

// Precompute storage
reg [0:15][9:0] D_powers;
reg [0:15] s_array;
reg [9:0] a_inv, D, a_inv_k, b_k;

// Computation registers
reg [14:0] i, j, max_i;
reg [14:0] block_j;
reg [10:0] block_count;
reg [9:0] C, term_sum;
reg [9:0] current_sum;
reg [9:0] tmp_mult;

// Exponentiator module
mod_exp exponentiate (
  .clk(clk),
  .rst_n(rst_n),
  .start(exp_start),
  .base(exp_base),
  .exponent(exp_exponent),
  .modulus(mod),
  .result(exp_result),
  .done(exp_done)
);

state_e state;

// Modular inverse (combinational for mod 997)
function automatic [9:0] mod_inv(input [15:0] val);
  integer x;
  begin
    mod_inv = 0;
    for (x = 1; x < 997; x = x + 1) begin
      if (((val % 997) * x) % 997 == 1) begin
        mod_inv = x;
        break;
      end
    end
  end
endfunction

// Modular multiplication (combinational)
function automatic [9:0] mod_mult(input [9:0] a, b);
  mod_mult = (a * b) % mod;
endfunction

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    result <= 0;
    exp_start <= 0;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        current_sum <= 0;
        if (start) begin
          // Initialize variables
          a_inv <= mod_inv(a % mod);
          D <= (a_inv * (b % mod)) % mod;
          for (int t = 0; t < 16; t = t + 1) begin
            s_array[t] <= (t < k) ? s[t] : 0;
          end
          state <= PRE_COMPUTE;
          i <= 0;
          D_powers[0] <= 1;
        end
      end

      PRE_COMPUTE: begin
        if (i < k-1) begin
          D_powers[i+1] <= mod_mult(D_powers[i], D);
          i <= i + 1;
        end else begin
          // Start exponentiation for a_inv_k and b_k
          state <= PROCESS_BLOCK;
          block_count <= (n + k) / k;
          block_j <= 0;
          exp_base <= a % mod;
          exp_exponent <= n;
          exp_start <= 1;
        end
      end

      PROCESS_BLOCK: begin
        exp_start <= 0;
        if (exp_done) begin
          C <= exp_result;
          exp_exponent <= k;
          exp_base <= b % mod;
          exp_start <= 1;
          state <= MULT_TERMS;
        end
      end

      MULT_TERMS: begin
        exp_start <= 0;
        if (exp_done) begin
          b_k <= exp_result;
          exp_base <= a_inv;
          exp_exponent <= k;
          exp_start <= 1;
          term_sum <= 0;
          i <= 0;
        end
      end

      ACCUMULATE: begin
        exp_start <= 0;
        if (i < k && j < n) begin
          if (i == 0) tmp_mult <= mod_mult(C, D_powers[i]);
          else tmp_mult <= mod_mult(tmp_mult, D_powers[i]);
          
          if (s_array[i]) begin
            term_sum <= (term_sum + mod_mult(tmp_mult, b_k)) % mod;
          end else begin
            term_sum <= (term_sum + mod - mod_mult(tmp_mult, b_k)) % mod;
          end
          
          i <= i + 1;
          j <= j + 1;
        end else begin
          current_sum <= (current_sum + term_sum) % mod;
          exp_base <= a_inv;
          exp_exponent <= k;
          exp_start <= 1;
          block_j <= block_j + 1;
          if (block_j < block_count) begin
            state <= PROCESS_BLOCK;
          end else begin
            state <= DONE_ST;
          end
        end
      end

      DONE_ST: begin
        result <= current_sum;
        done <= 1;
        state <= IDLE;
      end
    endcase
  end
end

endmodule

module mod_exp (
  input clk,
  input rst_n,
  input start,
  input [15:0] base,
  input [14:0] exponent,
  input [9:0] modulus,
  output reg [9:0] result,
  output reg done
);

reg [14:0] exp_reg;
reg [9:0] base_reg, res_reg;
typedef enum logic [1:0] {EXP_IDLE, EXP_CALC } exp_state_e;
exp_state_e state;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= EXP_IDLE;
    done <= 0;
  end else begin
    case (state)
      EXP_IDLE: begin
        if (start) begin
          base_reg <= base % modulus;
          exp_reg <= exponent;
          res_reg <= 1;
          done <= 0;
          state <= EXP_CALC;
        end
      end

      EXP_CALC: begin
        if (exp_reg == 0) begin
          result <= res_reg;
          done <= 1;
          state <= EXP_IDLE;
        end else begin
          if (exp_reg[0]) begin
            res_reg <= (res_reg * base_reg) % modulus;
          end
          base_reg <= (base_reg * base_reg) % modulus;
          exp_reg <= exp_reg >> 1;
        end
      end
    endcase
  end
end

endmodule