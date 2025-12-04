module luggage_speed_calculator (
  input clk,
  input rst_n,
  input start,
  input [31:0] L_fixed,
  input [31:0] positions [0:7],
  input [2:0] num_items,
  output reg [31:0] speed_fixed,
  output reg done,
  output reg valid
);

  typedef enum logic [3:0] {
    IDLE,
    SORT,
    CHECK_GAPS,
    COMPUTE_SPEEDS,
    FIND_MIN,
    CHECK_RANGE,
    DONE,
    INVALID
  } state_e;

  reg [3:0] state, next_state;
  reg [31:0] sorted_pos [0:7];
  reg [2:0] num_items_reg;
  reg [2:0] sort_i, sort_j;
  reg swap_flag;
  reg [2:0] gap_idx;
  reg [31:0] gap_minus_1 [0:7];
  reg gap_invalid;
  reg [2:0] speed_idx;
  reg [31:0] speeds [0:7];
  reg [31:0] min_speed_temp;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      speed_fixed <= 0;
      foreach (sorted_pos[i]) sorted_pos[i] <= 0;
      sort_i <= 0;
      sort_j <= 0;
      swap_flag <= 0;
      gap_idx <= 0;
      gap_invalid <= 0;
      speed_idx <= 0;
      min_speed_temp <= 0;
      foreach (speeds[i]) speeds[i] <= 0;
      foreach (gap_minus_1[i]) gap_minus_1[i] <= 0;
    end else begin
      case (state)
        IDLE : begin
          done <= 0;
          valid <= 0;
          speed_fixed <= 0;
          if (start) begin
            num_items_reg <= num_items;
            foreach (sorted_pos[i]) sorted_pos[i] <= positions[i];
            state <= SORT;
            sort_i <= 0;
            sort_j <= 0;
            swap_flag <= 0;
          end
        end

        SORT : begin
          if (sort_i < (num_items_reg - 1)) begin
            if (sort_j < (num_items_reg - sort_i - 1)) begin
              if (sorted_pos[sort_j] > sorted_pos[sort_j + 1]) begin
                // Swap
                sorted_pos[sort_j] <= sorted_pos[sort_j + 1];
                sorted_pos[sort_j + 1] <= sorted_pos[sort_j];
                swap_flag <= 1;
              end
              sort_j <= sort_j + 1;
            end else begin
              if (!swap_flag || ((num_items_reg - sort_i - 1) == 0)) begin
                state <= CHECK_GAPS;
                gap_idx <= 0;
                gap_invalid <= 0;
              end else begin
                sort_i <= sort_i + 1;
                sort_j <= 0;
                swap_flag <= 0;
              end
            end
          end else begin
            state <= CHECK_GAPS;
            gap_idx <= 0;
            gap_invalid <= 0;
          end
        end

        CHECK_GAPS : begin
          if (gap_idx < num_items_reg) begin
            reg [31:0] current_gap;
            // Calculate gap (current and next, wrap-around for last)
            if (gap_idx == (num_items_reg - 1)) begin
              current_gap = (L_fixed - sorted_pos[gap_idx]) + sorted_pos[0];
            end else begin
              current_gap = sorted_pos[gap_idx + 1] - sorted_pos[gap_idx];
            end
            
            // Subtract safety margin (1.0) and check validity
            if (current_gap <= 32'h00010000) begin
              gap_invalid <= 1;
              state <= INVALID;
            end else begin
              gap_minus_1[gap_idx] <= current_gap - 32'h00010000;
              gap_idx <= gap_idx + 1;
            end
          end else begin
            state <= COMPUTE_SPEEDS;
            speed_idx <= 0;
          end
        end

        COMPUTE_SPEEDS : begin
          if (speed_idx < num_items_reg) begin
            // Compute L_fixed / (gap_minus_1[speed_idx]) in Q16.16
            reg [63:0] numerator;
            reg [31:0] denominator;

            numerator = {32'h0, L_fixed} << 16;
            denominator = gap_minus_1[speed_idx];
            speeds[speed_idx] <= numerator / denominator;
            speed_idx <= speed_idx + 1;
          end else begin
            state <= FIND_MIN;
            min_speed_temp <= 32'hFFFFFFFF;
            speed_idx <= 0;
          end
        end

        FIND_MIN : begin
          if (speed_idx < num_items_reg) begin
            if (speeds[speed_idx] < min_speed_temp) begin
              min_speed_temp <= speeds[speed_idx];
            end
            speed_idx <= speed_idx + 1;
          end else begin
            state <= CHECK_RANGE;
          end
        end

        CHECK_RANGE : begin
          if (min_speed_temp >= 32'h00001999 && min_speed_temp <= 32'h000A0000) begin
            valid <= 1;
            speed_fixed <= min_speed_temp;
          end else begin
            valid <= 0;
            speed_fixed <= 32'hFFFFFFFF;
          end
          state <= DONE;
          done <= 1;
        end

        INVALID : begin
          valid <= 0;
          speed_fixed <= 32'hFFFFFFFF;
          state <= DONE;
          done <= 1;
        end

        DONE : begin
          if (~start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule