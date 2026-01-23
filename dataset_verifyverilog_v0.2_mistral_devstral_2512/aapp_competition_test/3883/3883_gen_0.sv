module polyline_solver (
  input clk,
  input rst_n,
  input start,
  input [15:0] a_scaled,
  input [15:0] b_scaled,
  output reg [31:0] result_x,
  output reg done,
  output reg no_solution
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_A_LT_B,
    CALCULATE_CASE1,
    CALCULATE_CASE2,
    FIND_MIN,
    DONE
  } state_t;

  state_t state;
  reg [31:0] a, b; // Q16.16 format
  reg [31:0] x_case1, x_case2;
  reg [31:0] min_x;
  reg [31:0] k_case1, k_case2;
  reg [31:0] temp1, temp2;
  reg [31:0] two_b;
  reg [31:0] a_minus_b, a_plus_b;
  reg [31:0] denominator_case1, denominator_case2;
  reg valid_case1, valid_case2;
  reg [31:0] zero = 32'h00000000;
  reg [31:0] one = 32'h00010000;
  reg [31:0] two = 32'h00020000;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      no_solution <= 0;
      result_x <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_A_LT_B;
            done <= 0;
            no_solution <= 0;
            // Scale inputs to Q16.16
            a <= {a_scaled, 8'h00};
            b <= {b_scaled, 8'h00};
          end
        end

        CHECK_A_LT_B: begin
          state <= CALCULATE_CASE1;
          a_minus_b <= a - b;
          a_plus_b <= a + b;
          two_b <= b << 1;
        end

        CALCULATE_CASE1: begin
          // Case 1: x = (a-b)/(2k), k = floor((a-b)/(2b))
          if (a_minus_b[31] || two_b == 0) begin
            valid_case1 <= 0;
            x_case1 <= 0;
          end else begin
            // k = floor((a-b)/(2b))
            k_case1 <= a_minus_b / two_b;
            if (k_case1 == 0) begin
              valid_case1 <= 0;
              x_case1 <= 0;
            end else begin
              denominator_case1 <= k_case1 << 1;
              if (denominator_case1 == 0) begin
                valid_case1 <= 0;
                x_case1 <= 0;
              end else begin
                x_case1 <= a_minus_b / denominator_case1;
                // Check if 2kx <= a <= (2k+1)x
                temp1 <= k_case1 << 1;
                temp1 <= temp1 * x_case1;
                temp2 <= (k_case1 << 1) + 1;
                temp2 <= temp2 * x_case1;
                if (temp1 <= a && a <= temp2) begin
                  valid_case1 <= 1;
                end else begin
                  valid_case1 <= 0;
                end
              end
            end
          end
          state <= CALCULATE_CASE2;
        end

        CALCULATE_CASE2: begin
          // Case 2: x = (a+b)/(2k+2), k = floor((a+b)/(2b)) - 1
          if (a_plus_b[31] || two_b == 0) begin
            valid_case2 <= 0;
            x_case2 <= 0;
          end else begin
            // k = floor((a+b)/(2b)) - 1
            k_case2 <= (a_plus_b / two_b) - 1;
            if (k_case2[31]) begin
              valid_case2 <= 0;
              x_case2 <= 0;
            end else begin
              denominator_case2 <= (k_case2 << 1) + 2;
              if (denominator_case2 == 0) begin
                valid_case2 <= 0;
                x_case2 <= 0;
              end else begin
                x_case2 <= a_plus_b / denominator_case2;
                // Check if (2k+1)x <= a <= (2k+2)x
                temp1 <= (k_case2 << 1) + 1;
                temp1 <= temp1 * x_case2;
                temp2 <= (k_case2 << 1) + 2;
                temp2 <= temp2 * x_case2;
                if (temp1 <= a && a <= temp2) begin
                  valid_case2 <= 1;
                end else begin
                  valid_case2 <= 0;
                end
              end
            end
          end
          state <= FIND_MIN;
        end

        FIND_MIN: begin
          min_x <= 0;
          no_solution <= 1;
          if (valid_case1 && x_case1 > 0) begin
            min_x <= x_case1;
            no_solution <= 0;
          end
          if (valid_case2 && x_case2 > 0) begin
            if (no_solution || x_case2 < min_x) begin
              min_x <= x_case2;
              no_solution <= 0;
            end
          end
          if (min_x == 0) begin
            no_solution <= 1;
          end
          result_x <= min_x;
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule