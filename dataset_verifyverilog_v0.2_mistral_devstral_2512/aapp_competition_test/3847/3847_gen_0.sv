module max_subrect_area (
  input clk,
  input rst_n,
  input start,
  input [7:0] a_len,
  input [7:0] b_len,
  input [15:0] x,
  input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
  input [7:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_PREFIX_A,
    CALC_PREFIX_B,
    FIND_MIN_A,
    FIND_MIN_B,
    CHECK_COMBOS,
    DONE
  } state_t;

  state_t state;

  // Internal registers
  reg [15:0] prefix_a [0:7];
  reg [15:0] prefix_b [0:7];
  reg [15:0] min_sum_a [1:8];
  reg [15:0] min_sum_b [1:8];
  reg [7:0] i, j, k, l;
  reg [15:0] current_sum;
  reg [15:0] current_min;
  reg [15:0] temp_product;
  reg [15:0] temp_area;

  // Initialize arrays
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'd0;
      done <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        prefix_a[i] <= 16'd0;
        prefix_b[i] <= 16'd0;
      end
      for (i = 1; i < 9; i = i + 1) begin
        min_sum_a[i] <= 16'd0;
        min_sum_b[i] <= 16'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_PREFIX_A;
            i <= 8'd0;
            current_sum <= 16'd0;
          end
        end

        CALC_PREFIX_A: begin
          if (i < a_len) begin
            current_sum <= current_sum + {8'd0, a_0};
            prefix_a[i] <= current_sum;
            i <= i + 1'b1;
          end else begin
            state <= CALC_PREFIX_B;
            i <= 8'd0;
            current_sum <= 16'd0;
          end
        end

        CALC_PREFIX_B: begin
          if (i < b_len) begin
            current_sum <= current_sum + {8'd0, b_0};
            prefix_b[i] <= current_sum;
            i <= i + 1'b1;
          end else begin
            state <= FIND_MIN_A;
            i <= 8'd1; // Start with length 1
            j <= 8'd0;
            current_min <= 16'd0;
          end
        end

        FIND_MIN_A: begin
          if (i <= a_len) begin
            if (j <= a_len - i) begin
              if (j == 0) begin
                current_sum <= prefix_a[i - 1];
              end else begin
                current_sum <= prefix_a[j + i - 1] - prefix_a[j - 1];
              end
              if (j == 0 || current_sum < current_min) begin
                current_min <= current_sum;
              end
              j <= j + 1'b1;
            end else begin
              min_sum_a[i] <= current_min;
              i <= i + 1'b1;
              j <= 8'd0;
              current_min <= 16'd0;
            end
          end else begin
            state <= FIND_MIN_B;
            i <= 8'd1; // Start with length 1
            j <= 8'd0;
            current_min <= 16'd0;
          end
        end

        FIND_MIN_B: begin
          if (i <= b_len) begin
            if (j <= b_len - i) begin
              if (j == 0) begin
                current_sum <= prefix_b[i - 1];
              end else begin
                current_sum <= prefix_b[j + i - 1] - prefix_b[j - 1];
              end
              if (j == 0 || current_sum < current_min) begin
                current_min <= current_sum;
              end
              j <= j + 1'b1;
            end else begin
              min_sum_b[i] <= current_min;
              i <= i + 1'b1;
              j <= 8'd0;
              current_min <= 16'd0;
            end
          end else begin
            state <= CHECK_COMBOS;
            i <= 8'd1;
            j <= 8'd1;
            result <= 16'd0;
          end
        end

        CHECK_COMBOS: begin
          if (i <= a_len && j <= b_len) begin
            temp_product <= min_sum_a[i] * min_sum_b[j];
            temp_area <= i * j;
            if (temp_product <= x && temp_area > result) begin
              result <= temp_area;
            end
            if (j < b_len) begin
              j <= j + 1'b1;
            end else begin
              j <= 8'd1;
              i <= i + 1'b1;
            end
          end else begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: begin
          state <= IDLE;
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule