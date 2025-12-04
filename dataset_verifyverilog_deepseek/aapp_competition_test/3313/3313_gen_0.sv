module gem_collector(
  input clk,
  input rst_n,
  input start,
  input [3:0] gem_count,
  input [3:0] r,
  input [7:0] w,
  input [7:0] h,
  input [7:0] gem_x [0:7],
  input [7:0] gem_y [0:7],
  output reg [3:0] max_gems,
  output reg done
);

  typedef enum {IDLE, SORTING, CALCULATING, DONE} state_t;
  state_t state, next_state;

  reg [7:0] sorted_x[0:7];
  reg [7:0] sorted_y[0:7];
  reg [3:0] dp[0:7];

  reg [3:0] sort_i, sort_j;
  reg swapped_flag;
  reg [3:0] calc_i, calc_j;
  reg [15:0] x_diff, adj_diff;
  reg [7:0] y_diff;
  reg [3:0] max_val;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 0;
          max_gems <= 0;
        end

        SORTING: begin
          if (sort_j < gem_count - sort_i - 1) begin
            if (sorted_y[sort_j] > sorted_y[sort_j+1]) begin
              // Swap entries
              sorted_x[sort_j] <= sorted_x[sort_j+1];
              sorted_x[sort_j+1] <= sorted_x[sort_j];
              sorted_y[sort_j] <= sorted_y[sort_j+1];
              sorted_y[sort_j+1] <= sorted_y[sort_j];
              swapped_flag <= 1;
            end
            sort_j <= sort_j + 1;
          end else begin
            sort_i <= sort_i + 1;
            sort_j <= 0;
            if (sort_i == gem_count - 1 || !swapped_flag) begin
              next_state <= CALCULATING;
              sort_i <= 0;
            end
          end
        end

        CALCULATING: begin
          if (calc_i < gem_count) begin
            if (calc_j < calc_i) begin
              if (calc_j == 0) dp[calc_i] <= 1;
              x_diff = (sorted_x[calc_i] > sorted_x[calc_j]) ? 
                       (sorted_x[calc_i] - sorted_x[calc_j]) : 
                       (sorted_x[calc_j] - sorted_x[calc_i]);
              y_diff = sorted_y[calc_i] - sorted_y[calc_j];
              adj_diff = x_diff * r;

              if (adj_diff <= y_diff && dp[calc_j] + 1 > dp[calc_i]) begin
                dp[calc_i] <= dp[calc_j] + 1;
              end

              calc_j <= calc_j + 1;
            end else begin
              calc_i <= calc_i + 1;
              calc_j <= 0;
              if (calc_i == gem_count - 1) next_state <= DONE;
            end
          end else begin
            next_state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          max_val = dp[0];
          for (int k=1; k<gem_count; k=k+1) begin
            if (dp[k] > max_val) max_val = dp[k];
          end
          max_gems <= (gem_count == 0) ? 0 : max_val;
        end
      endcase
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: next_state = (start) ? SORTING : IDLE;
      SORTING: begin
        if (sort_i == gem_count -1 || !swapped_flag) begin
          if (sort_j == gem_count - sort_i -1) next_state = CALCULATING;
        end
      end
      CALCULATING: if (calc_i >= gem_count) next_state = DONE;
      DONE: if (!start) next_state = IDLE;
    endcase
  end

  // Initialization
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      sort_i <= 0;
      sort_j <= 0;
      calc_i <= 0;
      calc_j <= 0;
      swapped_flag <= 1;
      for (int i=0; i<8; i=i+1) begin
        sorted_x[i] <= 0;
        sorted_y[i] <= 0;
        dp[i] <= 0;
      end
    end else if (state == IDLE && start) begin
      // Reset working arrays
      for (int i=0; i<8; i=i+1) begin
        sorted_x[i] <= gem_x[i];
        sorted_y[i] <= gem_y[i];
        dp[i] <= 0;
      end
      sort_i <= 0;
      sort_j <= 0;
      calc_i <= 0;
      calc_j <= 0;
      swapped_flag <= 0;
    end
  end

endmodule