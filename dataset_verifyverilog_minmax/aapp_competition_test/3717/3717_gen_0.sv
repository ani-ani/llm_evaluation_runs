module rectangle_overlap_point(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input reg signed [31:0] rect_x1 [0:7],
  input reg signed [31:0] rect_y1 [0:7],
  input reg signed [31:0] rect_x2 [0:7],
  input reg signed [31:0] rect_y2 [0:7],
  output reg signed [31:0] point_x,
  output reg signed [31:0] point_y,
  output reg done
);
  // State encoding
  localparam IDLE       = 3'b000;
  localparam SETUP_MAX  = 3'b001;
  localparam SETUP_MIN  = 3'b010;
  localparam PROCESS    = 3'b011;
  localparam DONE       = 3'b100;

  // Registers
  reg [2:0] state, next_state;
  reg [2:0] idx, next_idx;
  reg signed [31:0] point_x_next, point_y_next;
  reg done_next;

  // Tracking of global extrema
  reg signed [31:0] max_x1,       next_max_x1;
  reg signed [31:0] second_max_x1, next_second_max_x1;
  reg [2:0] max_x1_idx, next_max_x1_idx;
  reg signed [31:0] max_y1,       next_max_y1;
  reg signed [31:0] second_max_y1, next_second_max_y1;
  reg [2:0] max_y1_idx, next_max_y1_idx;
  reg signed [31:0] min_x2,       next_min_x2;
  reg signed [31:0] second_min_x2, next_second_min_x2;
  reg [2:0] min_x2_idx, next_min_x2_idx;
  reg signed [31:0] min_y2,       next_min_y2;
  reg signed [31:0] second_min_y2, next_second_min_y2;
  reg [2:0] min_y2_idx, next_min_y2_idx;

  // Sentinel values for initialization
  localparam signed [31:0] SENTINEL_LOW  = 32'h8000_0000; // smallest signed 32-bit
  localparam signed [31:0] SENTINEL_HIGH = 32'h7fffffff; // largest signed 32-bit

  // Next-state logic and data computation
  always_comb begin
    // Default: keep current values
    next_state = state;
    next_idx   = idx;
    next_point_x = point_x;
    next_point_y = point_y;
    next_done   = done;
    next_max_x1 = max_x1;
    next_second_max_x1 = second_max_x1;
    next_max_x1_idx = max_x1_idx;
    next_max_y1 = max_y1;
    next_second_max_y1 = second_max_y1;
    next_max_y1_idx = max_y1_idx;
    next_min_x2 = min_x2;
    next_second_min_x2 = second_min_x2;
    next_min_x2_idx = min_x2_idx;
    next_min_y2 = min_y2;
    next_second_min_y2 = second_min_y2;
    next_min_y2_idx = min_y2_idx;

    if (state == IDLE) begin
      if (start) begin
        if (n == 3'd0) begin
          // No rectangles: any point is valid
          next_state = DONE;
          next_done = 1'b1;
          next_point_x = 0;
          next_point_y = 0;
        end else if (n == 3'd1) begin
          // Single rectangle: any point is also valid (at least 0 rectangles)
          next_state = DONE;
          next_done = 1'b1;
          next_point_x = 0;
          next_point_y = 0;
        end else begin
          // Prepare to compute global extrema
          next_state = SETUP_MAX;
          next_idx = 3'b0;
        end
      end
    end else if (state == SETUP_MAX) begin
      // Compute the largest and second‑largest x1 and y1 among the n rectangles
      logic signed [31:0] tmp_max_x1 = SENTINEL_LOW;
      logic signed [31:0] tmp_sec_x1 = SENTINEL_LOW;
      logic [2:0] tmp_max_x1_idx = 0;
      logic signed [31:0] tmp_max_y1 = SENTINEL_LOW;
      logic signed [31:0] tmp_sec_y1 = SENTINEL_LOW;
      logic [2:0] tmp_max_y1_idx = 0;

      for (int i = 0; i < 8; i++) begin
        if (i < n) begin
          // x1
          if (rect_x1[i] > tmp_max_x1) begin
            tmp_sec_x1 = tmp_max_x1;
            tmp_max_x1 = rect_x1[i];
            tmp_max_x1_idx = i[2:0];
          end else if (rect_x1[i] > tmp_sec_x1) begin
            tmp_sec_x1 = rect_x1[i];
          end
          // y1
          if (rect_y1[i] > tmp_max_y1) begin
            tmp_sec_y1 = tmp_max_y1;
            tmp_max_y1 = rect_y1[i];
            tmp_max_y1_idx = i[2:0];
          end else if (rect_y1[i] > tmp_sec_y1) begin
            tmp_sec_y1 = rect_y1[i];
          end
        end
      end

      // Store the results
      next_max_x1 = tmp_max_x1;
      next_second_max_x1 = tmp_sec_x1;
      next_max_x1_idx = tmp_max_x1_idx;
      next_max_y1 = tmp_max_y1;
      next_second_max_y1 = tmp_sec_y1;
      next_max_y1_idx = tmp_max_y1_idx;

      // Proceed to compute the minima
      next_state = SETUP_MIN;
    end else if (state == SETUP_MIN) begin
      // Compute the smallest and second‑smallest x2 and y2 among the n rectangles
      logic signed [31:0] tmp_min_x2 = SENTINEL_HIGH;
      logic signed [31:0] tmp_sec_x2 = SENTINEL_HIGH;
      logic [2:0] tmp_min_x2_idx = 0;
      logic signed [31:0] tmp_min_y2 = SENTINEL_HIGH;
      logic signed [31:0] tmp_sec_y2 = SENTINEL_HIGH;
      logic [2:0] tmp_min_y2_idx = 0;

      for (int i = 0; i < 8; i++) begin
        if (i < n) begin
          // x2
          if (rect_x2[i] < tmp_min_x2) begin
            tmp_sec_x2 = tmp_min_x2;
            tmp_min_x2 = rect_x2[i];
            tmp_min_x2_idx = i[2:0];
          end else if (rect_x2[i] < tmp_sec_x2) begin
            tmp_sec_x2 = rect_x2[i];
          end
          // y2
          if (rect_y2[i] < tmp_min_y2) begin
            tmp_sec_y2 = tmp_min_y2;
            tmp_min_y2 = rect_y2[i];
            tmp_min_y2_idx = i[2:0];
          end else if (rect_y2[i] < tmp_sec_y2) begin
            tmp_sec_y2 = rect_y2[i];
          end
        end
      end

      // Store the results
      next_min_x2 = tmp_min_x2;
      next_second_min_x2 = tmp_sec_x2;
      next_min_x2_idx = tmp_min_x2_idx;
      next_min_y2 = tmp_min_y2;
      next_second_min_y2 = tmp_sec_y2;
      next_min_y2_idx = tmp_min_y2_idx;

      // Begin per‑rectangle processing
      next_state = PROCESS;
      next_idx = 3'b0;
    end else if (state == PROCESS) begin
      if (idx < n) begin
        // Determine the point that is the max‑x1 and max‑y1 when rectangle idx is excluded
        logic signed [31:0] excl_max_x1 = (idx == max_x1_idx) ? second_max_x1 : max_x1;
        logic signed [31:0] excl_max_y1 = (idx == max_y1_idx) ? second_max_y1 : max_y1;
        logic signed [31:0] excl_min_x2 = (idx == min_x2_idx) ? second_min_x2 : min_x2;
        logic signed [31:0] excl_min_y2 = (idx == min_y2_idx) ? second_min_y2 : min_y2;

        if (excl_max_x1 <= excl_min_x2 && excl_max_y1 <= excl_min_y2) begin
          // Found a valid point
          next_state = DONE;
          next_done = 1'b1;
          next_point_x = excl_max_x1;
          next_point_y = excl_max_y1;
        end else begin
          // Not found for this rectangle; move to the next one
          if (idx + 1 < n) begin
            next_state = PROCESS;
            next_idx = idx + 1;
          end else begin
            // All rectangles processed, no point found
            next_state = DONE;
            next_done = 1'b1;
          end
        end
      end else begin
        // idx should never be >= n in PROCESS; treat as finished
        next_state = DONE;
        next_done = 1'b1;
      end
    end else if (state == DONE) begin
      // Stay in DONE, keep done high
      next_state = DONE;
      next_done = 1'b1;
    end
  end

  // Sequential update of registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx <= 0;
      point_x <= 0;
      point_y <= 0;
      done <= 0;
      max_x1 <= 0;
      second_max_x1 <= 0;
      max_x1_idx <= 0;
      max_y1 <= 0;
      second_max_y1 <= 0;
      max_y1_idx <= 0;
      min_x2 <= 0;
      second_min_x2 <= 0;
      min_x2_idx <= 0;
      min_y2 <= 0;
      second_min_y2 <= 0;
      min_y2_idx <= 0;
    end else begin
      state <= next_state;
      idx <= next_idx;
      point_x <= next_point_x;
      point_y <= next_point_y;
      done <= next_done;
      max_x1 <= next_max_x1;
      second_max_x1 <= next_second_max_x1;
      max_x1_idx <= next_max_x1_idx;
      max_y1 <= next_max_y1;
      second_max_y1 <= next_second_max_y1;
      max_y1_idx <= next_max_y1_idx;
      min_x2 <= next_min_x2;
      second_min_x2 <= next_second_min_x2;
      min_x2_idx <= next_min_x2_idx;
      min_y2 <= next_min_y2;
      second_min_y2 <= next_second_min_y2;
      min_y2_idx <= next_min_y2_idx;
    end
  end

endmodule