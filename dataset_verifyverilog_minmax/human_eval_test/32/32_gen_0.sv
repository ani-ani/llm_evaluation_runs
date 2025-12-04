module polynomial_root_finder (
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0][31:0] coeffs,
  input  [2:0] degree,
  output reg [31:0] x_out,
  output reg done
);

  // Internal state
  typedef logic [31:0] s32;
  typedef logic [47:0] s48;
  typedef logic [63:0] s64;

  typedef enum logic [2:0] {
    S_IDLE = 3'd0,
    S_EVAL = 3'd1,
    S_NEXT = 3'd2
  } state_t;

  state_t state;
  reg [3:0] iter_cnt;        // 0..10
  reg [31:0] x_curr;         // Q16.16
  reg [31:0] y_reg;          // f(x) in Q16.16 (staged before division)
  reg [31:0] dy_reg;         // f'(x) in Q16.16 (staged before division)

  // Q16.16 fixed-point helpers
  function [31:0] q16_16_mul (input s32 a, input s32 b);
    s64 prod;
    prod = $signed(a) * $signed(b); // 64-bit signed product
    // Round to nearest (ties away from zero)
    // Keep high 32 bits, add 1 to high when low 17 bits >= 2^16 (i.e., a 0.5 or more)
    if (prod[63]) begin
      // Negative: round toward zero (i.e., away from -inf)
      // Equivalent to add 0.5 and floor
      if (prod[15]) q16_16_mul = prod[47:16] + 1;
      else          q16_16_mul = prod[47:16];
    end else begin
      // Positive: add 0.5 and floor
      if (prod[15]) q16_16_mul = prod[47:16] + 1;
      else          q16_16_mul = prod[47:16];
    end
  endfunction

  function [31:0] q16_16_div (input s32 a, input s32 b);
    // Guard: if |b| < 2^(-16), saturate quotient to prevent extreme values
    if (b == 0) begin
      q16_16_div = (a[31] ? 32'h80000000 : 32'h7FFFFFFF);
    end else if ((b & 32'h0000FFFF) == 0 && ((b >>> 16) == 0)) begin
      // |b| < 1.0 in Q16.16, saturate to +/- 2^31-1
      q16_16_div = (a[31] ? 32'h80000000 : 32'h7FFFFFFF);
    end else begin
      // 32.16 / 16.16 = 16.16 (with rounding)
      s64 num;
      s64 den;
      s48 frac;
      num = $signed(a) << 16;  // shift into 48.16
      den = $signed(b);
      frac = num / den;        // 48.16 result
      // Extract integer 16.16 and round on the 0.5 threshold
      if (frac[15]) q16_16_div = frac[31:16] + 1;
      else          q16_16_div = frac[31:16];
    end
  endfunction

  // Horner's method: P(x) for coefficients a_degree..a_0
  function [31:0] eval_poly (input [7:0][31:0] c, input [2:0] deg, input s32 x);
    s48 acc = 48'sd0;
    logic [63:0] prod64;
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
      // Only contribute terms for actual degree
      if (i <= deg) begin
        // acc = acc * x + c[deg-i]
        prod64 = $signed(acc) * $signed(x);
        acc = prod64[63:16]; // keep high part, effectively Q32.16 -> Q16.16 after trunc
        acc = acc + s48'(s32'(c[deg - i]));
      end
    end
    eval_poly = acc[31:0];
  endfunction

  // Horner's method: derivative of P(x) with respect to x
  function [31:0] eval_deriv (input [7:0][31:0] c, input [2:0] deg, input s32 x);
    s48 acc = 48'sd0;
    logic [63:0] prod64;
    integer i;
    // Use coefficients a_degree..a_0, derivative uses degree * a_degree as initial factor
    for (i = 0; i < 7; i = i + 1) begin
      if (i == 0) begin
        // Initial acc = deg * a_degree
        acc = s48'(s32'(deg)) * s48'(s32'(c[deg]));
      end else if (i <= deg) begin
        // acc = acc * x + (deg-(i-1)) * a_{deg-(i-1)}
        prod64 = $signed(acc) * $signed(x);
        acc = prod64[63:16];
        acc = acc + s48'(s32'(s32'(deg - (i-1)) * s32'(c[deg - (i-1)])));
      end
    end
    eval_deriv = acc[31:0];
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x_out  <= 32'sd0;
      done   <= 1'b0;
      state  <= S_IDLE;
      iter_cnt <= 4'd0;
      x_curr <= 32'sd0;
      y_reg  <= 32'sd0;
      dy_reg <= 32'sd0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            x_curr  <= 32'sd0;     // initial guess: x0 = 0 (Q16.16)
            iter_cnt <= 4'd0;
            state   <= S_EVAL;     // Evaluate f(x_curr) and f'(x_curr) next cycle
          end else begin
            state <= S_IDLE;
          end
        end

        S_EVAL: begin
          // One evaluation stage computes both f(x) and f'(x)
          y_reg  <= eval_poly (coeffs, degree, x_curr);
          dy_reg <= eval_deriv(coeffs, degree, x_curr);
          state  <= S_NEXT;        // Compute update next cycle
        end

        S_NEXT: begin
          // Stopping condition: |f(x)| < 0x200 (≈0.0078125 in Q16.16)
          if ((y_reg[31] ? ~y_reg + 1 : y_reg) < 32'h200) begin
            x_out  <= x_curr;
            done   <= 1'b1;
            state  <= S_IDLE;
          end else begin
            // Newton-Raphson: x_{n+1} = x_n - f(x)/f'(x)
            // Guard against zero or tiny derivative
            if (dy_reg == 0) begin
              // Tiny or zero derivative: saturate step magnitude to prevent divergence
              // Subtract a small signed quantity in direction of y
              x_curr <= x_curr - (y_reg[31] ? 32'h00004000 : 32'h0000C000); // small move away from current sign
            end else begin
              x_curr <= x_curr - q16_16_div(y_reg, dy_reg);
            end
            iter_cnt <= iter_cnt + 1;
            if (iter_cnt >= 4'd9) begin
              // Reached max iterations; output result and finish
              x_out <= x_curr;
              done  <= 1'b1;
              state <= S_IDLE;
            end else begin
              state <= S_EVAL;     // Continue iterating
            end
          end
        end
      endcase
    end
  end

endmodule
