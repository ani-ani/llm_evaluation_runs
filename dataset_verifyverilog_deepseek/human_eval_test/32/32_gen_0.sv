module polynomial_root_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0][31:0] coeffs,
  input [2:0] degree,
  output reg [31:0] x_out,
  output reg done
);

  // State machine states
  typedef enum {
    STATE_IDLE,
    STATE_START,
    STATE_EVAL_POLY,
    STATE_EVAL_DERIV,
    STATE_DIV_START,
    STATE_DIV_ITER,
    STATE_UPDATE_X,
    STATE_CHECK_CONV,
    STATE_DONE
  } state_t;
  state_t state;

  // Polynomial coefficients registers
  reg [7:0][31:0] coeffs_reg;
  reg [2:0] degree_reg;

  // Derivative coefficients
  reg [6:0][31:0] deriv_coeffs_reg;

  // Iteration variables
  reg [31:0] x;
  reg [3:0] iter_count;
  reg [31:0] poly_val;
  reg [31:0] deriv_val;

  // Reciprocal calculation
  reg [31:0] recip_est;
  reg [1:0] recip_iter_count;

  // Constants
  localparam [31:0] THRESHOLD = 32'h0000_0200;
  localparam [3:0] MAX_ITER = 10;
  localparam [1:0] DIV_ITER_MAX = 3;

  // Q16.16 multiplication helper function
  function automatic [31:0] multiply_q16_16(input [31:0] a, input [31:0] b);
    reg [63:0] product;
    begin
      product = a * b;
      // Truncate to Q16.16: take bits 47:16
      multiply_q16_16 = product[47:16];
    end
  endfunction

  // Polynomial evaluation using Horner's method (combinational)
  always_comb begin
    poly_val = 0;
    for (int i = 0; i <= 7; i++) begin
      if (i <= degree_reg) poly_val = multiply_q16_16(poly_val, x) + coeffs_reg[i];
    end
  end

  // Derivative evaluation using Horner's method (combinational)
  always_comb begin
    deriv_val = 0;
    for (int j = 0; j <= 6; j++) begin
      if (j <= (degree_reg - 1)) deriv_val = multiply_q16_16(deriv_val, x) + deriv_coeffs_reg[j];
    end
  end

  // State machine and control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      done <= 0;
      x_out <= 0;
      coeffs_reg <= '0;
      degree_reg <= '0;
      deriv_coeffs_reg <= '0;
      x <= 0;
      iter_count <= 0;
      poly_val <= 0;
      deriv_val <= 0;
      recip_est <= 0;
      recip_iter_count <= 0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (start) begin
            coeffs_reg <= coeffs;
            degree_reg <= degree;
            done <= 0;
            x_out <= 0;
            state <= STATE_START;
          end
        end

        STATE_START: begin
          for (int k = 0; k < 7; k++) begin
            if (k < degree_reg) deriv_coeffs_reg[k] <= multiply_q16_16(coeffs_reg[k+1], (k+1) << 16);
            else deriv_coeffs_reg[k] <= 0;
          end
          x <= 0;
          iter_count <= 0;
          state <= STATE_EVAL_POLY;
        end

        STATE_EVAL_POLY: state <= STATE_EVAL_DERIV;
        STATE_EVAL_DERIV: state <= STATE_DIV_START;

        STATE_DIV_START: begin
          recip_est <= deriv_val[31] ? 32'hFFFF_0000 : 32'h0001_0000;
          recip_iter_count <= 0;
          state <= STATE_DIV_ITER;
        end

        STATE_DIV_ITER: begin
          if (recip_iter_count < DIV_ITER_MAX) begin
            reg [31:0] temp1 = multiply_q16_16(deriv_val, recip_est);
            reg [31:0] temp2 = 32'h0002_0000 - temp1;
            recip_est <= multiply_q16_16(recip_est, temp2);
            recip_iter_count <= recip_iter_count + 1;
          end else state <= STATE_UPDATE_X;
        end

        STATE_UPDATE_X: begin
          reg [31:0] div_result = multiply_q16_16(poly_val, recip_est);
          x <= x - div_result;
          state <= STATE_CHECK_CONV;
        end

        STATE_CHECK_CONV: begin
          reg [31:0] abs_poly = poly_val[31] ? -poly_val : poly_val;
          if (abs_poly < THRESHOLD || iter_count >= MAX_ITER-1) begin
            x_out <= x;
            done <= 1;
            state <= STATE_DONE;
          end else begin
            iter_count <= iter_count + 1;
            state <= STATE_EVAL_POLY;
          end
        end

        STATE_DONE: begin
          if (start) begin
            state <= STATE_START;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule