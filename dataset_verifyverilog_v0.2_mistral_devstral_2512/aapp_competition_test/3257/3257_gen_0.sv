module carpet_area(
  input clk,
  input rst_n,
  input start,
  input [31:0] dist_a,
  input [31:0] dist_b,
  input [31:0] dist_c,
  output reg [31:0] area,
  output reg done
);

  // Constants
  localparam SQRT3_Q16 = 32'h0001BB67; // sqrt(3) in Q16.16
  localparam NEG_HALF_Q16 = 32'hFFFF8000; // -0.5 in Q16.16
  localparam ONE_Q16 = 32'h00010000; // 1.0 in Q16.16
  localparam MAX_ITER = 24;

  // State machine
  typedef enum logic [3:0] {
    IDLE,
    CHECK_VALIDITY,
    COMPUTE_SQUARED,
    SOLVE_QUADRATIC,
    VERIFY_INSIDE,
    COMPUTE_AREA,
    DONE
  } state_t;
  state_t state, next_state;

  // Intermediate registers
  reg [31:0] a, b, c;
  reg [31:0] a2, b2, c2;
  reg [31:0] a4, b4, c4;
  reg [31:0] ab, bc, ca;
  reg [31:0] ab_sq, bc_sq, ca_sq;
  reg [31:0] Q, R;
  reg [31:0] discriminant;
  reg [31:0] S_sq;
  reg [31:0] sqrt_val;
  reg [31:0] temp1, temp2, temp3;
  reg [31:0] iter_count;
  reg valid_triangle;
  reg inside_triangle;

  // Fixed-point multiplication and division functions
  function [31:0] fp_mul;
    input [31:0] a, b;
    reg [63:0] product;
    begin
      product = $signed(a) * $signed(b);
      fp_mul = product[47:16]; // Q32.32 -> Q16.16
    end
  endfunction

  function [31:0] fp_div;
    input [31:0] num, den;
    reg [31:0] result;
    reg [63:0] dividend;
    reg [31:0] divisor;
    reg [31:0] remainder;
    integer i;
    begin
      if (den == 0) begin
        result = 32'hFFFFFFFF;
      end else begin
        dividend = $signed(num) << 32;
        divisor = $signed(den);
        remainder = 0;
        for (i = 0; i < 32; i = i + 1) begin
          remainder = {remainder[30:0], dividend[63]};
          dividend = dividend << 1;
          if (remainder >= divisor) begin
            remainder = remainder - divisor;
            dividend[0] = 1'b1;
          end else begin
            dividend[0] = 1'b0;
          end
        end
        result = dividend[63:32];
      end
    end
  endfunction

  // Square root using Newton-Raphson
  function [31:0] fp_sqrt;
    input [31:0] val;
    reg [31:0] x;
    reg [31:0] x_next;
    integer i;
    begin
      if (val == 0) begin
        fp_sqrt = 0;
      end else begin
        x = val[31] ? 32'h00010000 : {val[31:16], 16'h0000};
        for (i = 0; i < MAX_ITER; i = i + 1) begin
          x_next = fp_div(fp_add(val, fp_div(val, x)), 2);
          if ($signed(x_next) == $signed(x) || $signed(x_next) == $signed(x) + 1 || $signed(x_next) == $signed(x) - 1) begin
            break;
          end
          x = x_next;
        end
        fp_sqrt = x_next;
      end
    end
  endfunction

  // Fixed-point addition
  function [31:0] fp_add;
    input [31:0] a, b;
    begin
      fp_add = a + b;
    end
  endfunction

  // Fixed-point subtraction
  function [31:0] fp_sub;
    input [31:0] a, b;
    begin
      fp_sub = a - b;
    end
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      area <= 0;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_VALIDITY;
        end
      end
      CHECK_VALIDITY: begin
        next_state = COMPUTE_SQUARED;
      end
      COMPUTE_SQUARED: begin
        next_state = SOLVE_QUADRATIC;
      end
      SOLVE_QUADRATIC: begin
        next_state = VERIFY_INSIDE;
      end
      VERIFY_INSIDE: begin
        if (inside_triangle) begin
          next_state = COMPUTE_AREA;
        end else begin
          next_state = DONE;
        end
      end
      COMPUTE_AREA: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= 0; b <= 0; c <= 0;
      a2 <= 0; b2 <= 0; c2 <= 0;
      a4 <= 0; b4 <= 0; c4 <= 0;
      ab <= 0; bc <= 0; ca <= 0;
      ab_sq <= 0; bc_sq <= 0; ca_sq <= 0;
      Q <= 0; R <= 0;
      discriminant <= 0;
      S_sq <= 0;
      sqrt_val <= 0;
      temp1 <= 0; temp2 <= 0; temp3 <= 0;
      iter_count <= 0;
      valid_triangle <= 0;
      inside_triangle <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            a <= dist_a;
            b <= dist_b;
            c <= dist_c;
          end
        end
        CHECK_VALIDITY: begin
          // Check triangle inequality for a, b, c
          temp1 <= fp_add(a, b);
          temp2 <= fp_add(b, c);
          temp3 <= fp_add(c, a);
          valid_triangle <= (a < temp2) && (b < temp3) && (c < temp1);
        end
        COMPUTE_SQUARED: begin
          a2 <= fp_mul(a, a);
          b2 <= fp_mul(b, b);
          c2 <= fp_mul(c, c);
          a4 <= fp_mul(a2, a2);
          b4 <= fp_mul(b2, b2);
          c4 <= fp_mul(c2, c2);
          ab <= fp_mul(a, b);
          bc <= fp_mul(b, c);
          ca <= fp_mul(c, a);
          ab_sq <= fp_mul(ab, ab);
          bc_sq <= fp_mul(bc, bc);
          ca_sq <= fp_mul(ca, ca);
          Q <= fp_add(fp_add(a2, b2), c2);
          R <= fp_add(fp_add(a4, b4), c4);
          R <= fp_sub(fp_sub(R, ab_sq), bc_sq);
          R <= fp_sub(R, ca_sq);
        end
        SOLVE_QUADRATIC: begin
          if (iter_count == 0) begin
            discriminant <= fp_sub(fp_mul(Q, Q), R);
            if (discriminant[31] || !valid_triangle) begin
              area <= 32'hFFFFFFFF;
              next_state = DONE;
            end else begin
              sqrt_val <= fp_sqrt(discriminant);
              S_sq <= fp_add(Q, sqrt_val);
            end
          end
        end
        VERIFY_INSIDE: begin
          if (iter_count == 0) begin
            // Check S^2 < a^2 + b^2 + a*b
            temp1 <= fp_add(fp_add(a2, b2), ab);
            temp2 <= fp_add(fp_add(b2, c2), bc);
            temp3 <= fp_add(fp_add(c2, a2), ca);
            inside_triangle <= (S_sq < temp1) && (S_sq < temp2) && (S_sq < temp3);
            if (!inside_triangle) begin
              area <= 32'hFFFFFFFF;
            end
          end
        end
        COMPUTE_AREA: begin
          if (iter_count == 0) begin
            area <= fp_mul(SQRT3_Q16, S_sq);
            area <= fp_div(area, 4);
          end
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

  // Iteration counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      iter_count <= 0;
    end else begin
      case (state)
        IDLE: iter_count <= 0;
        CHECK_VALIDITY: iter_count <= 0;
        COMPUTE_SQUARED: iter_count <= 0;
        SOLVE_QUADRATIC: iter_count <= iter_count + 1;
        VERIFY_INSIDE: iter_count <= iter_count + 1;
        COMPUTE_AREA: iter_count <= iter_count + 1;
        DONE: iter_count <= 0;
      endcase
    end
  end

endmodule