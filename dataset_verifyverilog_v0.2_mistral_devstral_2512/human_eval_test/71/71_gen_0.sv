module triangle_area(
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  input [7:0] c,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  localparam [5:0] IDLE = 6'd0;
  localparam [5:0] VALIDATE = 6'd1;
  localparam [5:0] COMPUTE_S = 6'd2;
  localparam [5:0] COMPUTE_PRODUCT = 6'd3;
  localparam [5:0] SQRT = 6'd4;
  localparam [5:0] DONE = 6'd5;

  reg [5:0] state = IDLE;
  reg [31:0] a_q16, b_q16, c_q16;
  reg [31:0] s, s_a, s_b, s_c;
  reg [31:0] product;
  reg [31:0] sqrt_result;
  reg [31:0] low, high, mid, mid_sq;
  reg [3:0] sqrt_cycle = 0;
  reg [1:0] validate_cycle = 0;
  reg [1:0] compute_s_cycle = 0;
  reg [1:0] compute_product_cycle = 0;
  reg valid_triangle;

  // Convert inputs to Q16.16
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_q16 <= 0;
      b_q16 <= 0;
      c_q16 <= 0;
    end else if (state == IDLE && start) begin
      a_q16 <= {a, 16'h0000};
      b_q16 <= {b, 16'h0000};
      c_q16 <= {c, 16'h0000};
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      valid_triangle <= 0;
      validate_cycle <= 0;
      compute_s_cycle <= 0;
      compute_product_cycle <= 0;
      sqrt_cycle <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= VALIDATE;
            validate_cycle <= 0;
          end
        end
        VALIDATE: begin
          if (validate_cycle == 0) begin
            // Check a + b > c
            if ({a, 1'b0} + {b, 1'b0} > {c, 1'b0}) begin
              valid_triangle <= 1;
            end else begin
              valid_triangle <= 0;
            end
            validate_cycle <= validate_cycle + 1;
          end else if (validate_cycle == 1) begin
            // Check a + c > b
            if (valid_triangle && ({a, 1'b0} + {c, 1'b0} > {b, 1'b0})) begin
              valid_triangle <= 1;
            end else begin
              valid_triangle <= 0;
            end
            validate_cycle <= validate_cycle + 1;
          end else if (validate_cycle == 2) begin
            // Check b + c > a
            if (valid_triangle && ({b, 1'b0} + {c, 1'b0} > {a, 1'b0})) begin
              valid_triangle <= 1;
            end else begin
              valid_triangle <= 0;
            end
            state <= COMPUTE_S;
            compute_s_cycle <= 0;
          end
        end
        COMPUTE_S: begin
          if (compute_s_cycle == 0) begin
            // s = (a + b + c) / 2
            s <= (a_q16 + b_q16 + c_q16) >> 1;
            compute_s_cycle <= compute_s_cycle + 1;
          end else if (compute_s_cycle == 1) begin
            // Compute s - a, s - b, s - c
            s_a <= s - a_q16;
            s_b <= s - b_q16;
            s_c <= s - c_q16;
            state <= COMPUTE_PRODUCT;
            compute_product_cycle <= 0;
          end
        end
        COMPUTE_PRODUCT: begin
          if (compute_product_cycle == 0) begin
            // Multiply s * (s - a)
            product <= s * s_a;
            compute_product_cycle <= compute_product_cycle + 1;
          end else if (compute_product_cycle == 1) begin
            // Multiply by (s - b)
            product <= product * s_b;
            compute_product_cycle <= compute_product_cycle + 1;
          end else if (compute_product_cycle == 2) begin
            // Multiply by (s - c)
            product <= product * s_c;
            compute_product_cycle <= compute_product_cycle + 1;
          end else if (compute_product_cycle == 3) begin
            state <= SQRT;
            sqrt_cycle <= 0;
            low <= 0;
            high <= product;
          end
        end
        SQRT: begin
          if (sqrt_cycle < 16) begin
            if (sqrt_cycle == 0) begin
              mid <= (low + high) >> 1;
              mid_sq <= mid * mid;
            end else if (sqrt_cycle == 1) begin
              if (mid_sq > product) begin
                high <= mid - 1;
              end else begin
                low <= mid + 1;
              end
              mid <= (low + high) >> 1;
              mid_sq <= mid * mid;
            end else begin
              if (mid_sq > product) begin
                high <= mid - 1;
              end else begin
                low <= mid + 1;
              end
              mid <= (low + high) >> 1;
              mid_sq <= mid * mid;
            end
            sqrt_cycle <= sqrt_cycle + 1;
          end else begin
            sqrt_result <= mid;
            state <= DONE;
          end
        end
        DONE: begin
          if (valid_triangle) begin
            result <= sqrt_result;
          end else begin
            result <= 32'hFFFFFFFF;
          end
          done <= 1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule