module figurine_4pack (
  input clk,
  input rst_n,
  input start,
  input [7:0] w0, w1, w2, w3,
  output reg [13:0] max_weight,
  output reg [13:0] min_weight,
  output reg [13:0] distinct_weights_count,
  output reg [31:0] expected_weight,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CALC_MAX_MIN,
    ENUMERATE,
    COMPUTE_EXPECTED,
    DONE
  } state_t;
  state_t state;

  // Internal registers
  reg [13:0] max_w, min_w;
  reg [13:0] sum_reg;
  reg [9:0] sum_count;
  reg [9:0] seen_sums [0:1023]; // 1024-bit array for tracking seen sums
  reg [9:0] i, j, k, l; // Counters for enumeration
  reg [13:0] current_sum;
  reg [31:0] expected_reg;
  reg [13:0] distinct_count;

  // Compute max and min weights
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_weight <= 14'b0;
      min_weight <= 14'b0;
      distinct_weights_count <= 14'b0;
      expected_weight <= 32'b0;
      done <= 1'b0;
      max_w <= 14'b0;
      min_w <= 14'b0;
      sum_reg <= 14'b0;
      sum_count <= 10'b0;
      expected_reg <= 32'b0;
      distinct_count <= 14'b0;
      i <= 10'b0;
      j <= 10'b0;
      k <= 10'b0;
      l <= 10'b0;
      current_sum <= 14'b0;
      for (int idx = 0; idx < 1024; idx++) begin
        seen_sums[idx] <= 10'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_MAX_MIN;
          end
        end
        CALC_MAX_MIN: begin
          // Compute max and min weights
          max_w = {w0, w1, w2, w3};
          max_w = (w0 > w1) ? w0 : w1;
          max_w = (max_w > w2) ? max_w : w2;
          max_w = (max_w > w3) ? max_w : w3;
          min_w = (w0 < w1) ? w0 : w1;
          min_w = (min_w < w2) ? min_w : w2;
          min_w = (min_w < w3) ? min_w : w3;
          max_weight <= max_w * 4;
          min_weight <= min_w * 4;
          state <= ENUMERATE;
        end
        ENUMERATE: begin
          // Enumerate all 256 combinations
          if (i == 4'd0 && j == 4'd0 && k == 4'd0 && l == 4'd0) begin
            // Reset seen_sums array
            for (int idx = 0; idx < 1024; idx++) begin
              seen_sums[idx] <= 10'b0;
            end
            distinct_count <= 14'b0;
          end
          // Compute current combination sum
          case (i)
            4'd0: current_sum = w0;
            4'd1: current_sum = w1;
            4'd2: current_sum = w2;
            4'd3: current_sum = w3;
          endcase
          case (j)
            4'd0: current_sum = current_sum + w0;
            4'd1: current_sum = current_sum + w1;
            4'd2: current_sum = current_sum + w2;
            4'd3: current_sum = current_sum + w3;
          endcase
          case (k)
            4'd0: current_sum = current_sum + w0;
            4'd1: current_sum = current_sum + w1;
            4'd2: current_sum = current_sum + w2;
            4'd3: current_sum = current_sum + w3;
          endcase
          case (l)
            4'd0: current_sum = current_sum + w0;
            4'd1: current_sum = current_sum + w1;
            4'd2: current_sum = current_sum + w2;
            4'd3: current_sum = current_sum + w3;
          endcase
          // Mark sum as seen
          if (!seen_sums[current_sum]) begin
            seen_sums[current_sum] <= 1'b1;
            distinct_count <= distinct_count + 1;
          end
          // Increment counters
          l <= l + 1;
          if (l == 4'd4) begin
            l <= 4'd0;
            k <= k + 1;
            if (k == 4'd4) begin
              k <= 4'd0;
              j <= j + 1;
              if (j == 4'd4) begin
                j <= 4'd0;
                i <= i + 1;
                if (i == 4'd4) begin
                  i <= 4'd0;
                  state <= COMPUTE_EXPECTED;
                end
              end
            end
          end
        end
        COMPUTE_EXPECTED: begin
          // Compute expected weight in Q16.16 format
          expected_reg = (w0 + w1 + w2 + w3) * 16384;
          expected_weight <= expected_reg;
          distinct_weights_count <= distinct_count;
          state <= DONE;
        end
        DONE: begin
          done <= 1'b1;
          if (!start) begin
            done <= 1'b0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule