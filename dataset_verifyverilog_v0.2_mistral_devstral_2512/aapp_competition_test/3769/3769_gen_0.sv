module func_count (
  input clk,
  input rst_n,
  input start,
  input [15:0] p_in,
  input [15:0] k_in,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_K,
    CALC_ORDER,
    MOD_EXP,
    POWER_LOOP,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [31:0] p, k; // Q16.16 format
  reg [31:0] current, base, exponent, temp, order, exp_val;
  reg [31:0] count, loop_count;
  reg [31:0] result_reg;
  reg [31:0] mod_result;

  // Initialize state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      p <= 0;
      k <= 0;
      current <= 0;
      base <= 0;
      exponent <= 0;
      temp <= 0;
      order <= 0;
      exp_val <= 0;
      count <= 0;
      loop_count <= 0;
      mod_result <= 0;
    end else begin
      state <= next_state;
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            next_state <= CHECK_K;
            p <= p_in << 16;
            k <= k_in << 16;
          end else begin
            next_state <= IDLE;
          end
        end

        CHECK_K: begin
          if (k == 0) begin
            exponent <= (p >> 16) - 1;
            next_state <= POWER_LOOP;
          end else if (k == (1 << 16)) begin
            exponent <= p >> 16;
            next_state <= POWER_LOOP;
          end else begin
            current <= (1 << 16);
            count <= 0;
            next_state <= CALC_ORDER;
          end
        end

        CALC_ORDER: begin
          if (current == (1 << 16)) begin
            order <= count;
            exp_val <= ((p >> 16) - 1) / (order >> 16);
            exponent <= exp_val;
            next_state <= MOD_EXP;
          end else begin
            current <= mod_mult(current, k, p);
            count <= count + (1 << 16);
          end
        end

        MOD_EXP: begin
          base <= p;
          result_reg <= (1 << 16);
          loop_count <= 0;
          next_state <= POWER_LOOP;
        end

        POWER_LOOP: begin
          if (loop_count == exponent) begin
            result <= result_reg;
            next_state <= DONE;
          end else begin
            if (exponent[loop_count]) begin
              result_reg <= mod_mult(result_reg, base, p);
            end
            base <= mod_mult(base, base, p);
            loop_count <= loop_count + 1;
          end
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            done <= 0;
            next_state <= IDLE;
          end
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // Modular multiplication function
  function [31:0] mod_mult;
    input [31:0] a, b, mod;
    reg [31:0] a_int, b_int, mod_int, product;
    begin
      a_int = a >> 16;
      b_int = b >> 16;
      mod_int = mod >> 16;
      product = (a_int * b_int) % mod_int;
      mod_mult = product << 16;
    end
  endfunction

endmodule