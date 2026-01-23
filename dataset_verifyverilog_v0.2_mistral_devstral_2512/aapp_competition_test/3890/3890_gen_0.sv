module penguin_walkways (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [3:0] k,
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam M = 30'h3B9ACA07; // 1000000007
  localparam IDLE = 3'b000;
  localparam SETUP_A = 3'b001;
  localparam CALC_A = 3'b010;
  localparam SETUP_B = 3'b011;
  localparam CALC_B = 3'b100;
  localparam MULTIPLY = 3'b101;
  localparam DONE = 3'b110;

  // State machine
  reg [2:0] state = IDLE;

  // Internal registers
  reg [31:0] factor_a = 0;
  reg [31:0] factor_b = 0;
  reg [31:0] base = 0;
  reg [31:0] exp = 0;
  reg [31:0] temp = 0;
  reg [31:0] product = 0;
  reg [31:0] result_reg = 0;
  reg [31:0] exponent_counter = 0;

  // Modular multiplication function
  function [31:0] mod_mult;
    input [31:0] a, b;
    begin
      mod_mult = (a * b) % M;
    end
  endfunction

  // Modular exponentiation function
  function [31:0] mod_exp;
    input [31:0] base_in;
    input [31:0] exp_in;
    reg [31:0] result_exp = 1;
    reg [31:0] base_exp = base_in;
    reg [31:0] exp_reg = exp_in;
    integer i;
    begin
      for (i = 0; i < 32; i = i + 1) begin
        if (exp_reg[0]) begin
          result_exp = mod_mult(result_exp, base_exp);
        end
        base_exp = mod_mult(base_exp, base_exp);
        exp_reg = exp_reg >> 1;
      end
      mod_exp = result_exp;
    end
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      factor_a <= 0;
      factor_b <= 0;
      base <= 0;
      exp <= 0;
      temp <= 0;
      product <= 0;
      result_reg <= 0;
      exponent_counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP_A;
          end
        end

        SETUP_A: begin
          base <= k;
          exp <= k - 1;
          state <= CALC_A;
        end

        CALC_A: begin
          if (exponent_counter < 32) begin
            if (exp[0]) begin
              temp <= mod_mult(temp, base);
            end
            base <= mod_mult(base, base);
            exp <= exp >> 1;
            exponent_counter <= exponent_counter + 1;
          end else begin
            factor_a <= temp;
            temp <= 1;
            exponent_counter <= 0;
            state <= SETUP_B;
          end
        end

        SETUP_B: begin
          base <= n - k;
          exp <= n - k;
          state <= CALC_B;
        end

        CALC_B: begin
          if (exponent_counter < 32) begin
            if (exp[0]) begin
              temp <= mod_mult(temp, base);
            end
            base <= mod_mult(base, base);
            exp <= exp >> 1;
            exponent_counter <= exponent_counter + 1;
          end else begin
            factor_b <= temp;
            temp <= 1;
            exponent_counter <= 0;
            state <= MULTIPLY;
          end
        end

        MULTIPLY: begin
          product <= mod_mult(factor_a, factor_b);
          state <= DONE;
        end

        DONE: begin
          result <= product;
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule