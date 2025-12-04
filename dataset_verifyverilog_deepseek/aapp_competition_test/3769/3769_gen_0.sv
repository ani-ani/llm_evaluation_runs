module function_counter(
  input clk,
  input rst_n,
  input start,
  input [4:0] p,
  input [4:0] k,
  output reg [29:0] result,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    COMPUTE_ORDER,
    PREP_EXPONENT,
    COMPUTE_EXPONENTIATION,
    DONE
  } state_t;

  state_t state;
  reg [4:0] t_reg;
  reg [4:0] temp_modp;
  reg [4:0] exponent_reg;
  reg [29:0] power;
  reg [4:0] exp_counter;
  localparam MOD = 30'd1000000007;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      temp_modp <= 0;
      t_reg <= 0;
      exponent_reg <= 0;
      power <= 0;
      exp_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            if (k == 5'd0 || k == 5'd1) begin
              state <= PREP_EXPONENT;
            end else begin
              state <= COMPUTE_ORDER;
              temp_modp <= 5'd1;
              t_reg <= 5'd0;
            end
          end
        end

        COMPUTE_ORDER: begin
          temp_modp <= (temp_modp * k) % p;
          t_reg <= t_reg + 1;
          if (((temp_modp * k) % p == 1) || (t_reg >= p - 1)) begin
            state <= PREP_EXPONENT;
          end else begin
            state <= COMPUTE_ORDER;
          end
        end

        PREP_EXPONENT: begin
          case (k)
            5'd0: exponent_reg <= p - 1;
            5'd1: exponent_reg <= p;
            default: exponent_reg <= (p - 1) / t_reg;
          endcase
          power <= 1;
          exp_counter <= 0;
          state <= COMPUTE_EXPONENTIATION;
        end

        COMPUTE_EXPONENTIATION: begin
          power <= (power * p) % MOD;
          exp_counter <= exp_counter + 1;
          if (exp_counter == exponent_reg - 1) begin
            state <= DONE;
          end
        end

        DONE: begin
          result <= power;
          done <= 1;
          if (!start) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule