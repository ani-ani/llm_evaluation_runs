module find_common_point (
  input clk,
  input rst_n,
  input start,
  input [7:0] x1_in, y1_in, x2_in, y2_in,
  input [2:0] n,
  output reg [7:0] result_x,
  output reg [7:0] result_y,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_RECTS,
    COMPUTE_PREFIX,
    COMPUTE_SUFFIX,
    CHECK_EXCLUSION,
    DONE
  } state_t;

  state_t state, next_state;

  // Rectangle buffer (8 entries, each with x1, y1, x2, y2)
  logic [7:0] rect_buffer [0:7][0:3];
  logic [2:0] rect_count;

  // Prefix and suffix arrays (each entry: max_x1, max_y1, min_x2, min_y2)
  logic [7:0] prefix [0:7][0:3];
  logic [7:0] suffix [0:7][0:3];

  // Current rectangle index for prefix/suffix computation
  logic [2:0] prefix_idx, suffix_idx;

  // Current exclusion index
  logic [2:0] excl_idx;

  // Temporary intersection result
  logic [7:0] temp_max_x1, temp_max_y1, temp_min_x2, temp_min_y2;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      rect_count <= 0;
      prefix_idx <= 0;
      suffix_idx <= 0;
      excl_idx <= 0;
      done <= 0;
      valid <= 0;
      result_x <= 0;
      result_y <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD_RECTS;
      end
      LOAD_RECTS: begin
        if (rect_count == n - 1) next_state = COMPUTE_PREFIX;
      end
      COMPUTE_PREFIX: begin
        if (prefix_idx == n - 1) next_state = COMPUTE_SUFFIX;
      end
      COMPUTE_SUFFIX: begin
        if (suffix_idx == n - 1) next_state = CHECK_EXCLUSION;
      end
      CHECK_EXCLUSION: begin
        if (excl_idx == n - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Load rectangles
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rect_count <= 0;
    end else if (state == LOAD_RECTS && start) begin
      rect_buffer[rect_count][0] <= x1_in;
      rect_buffer[rect_count][1] <= y1_in;
      rect_buffer[rect_count][2] <= x2_in;
      rect_buffer[rect_count][3] <= y2_in;
      rect_count <= rect_count + 1;
    end
  end

  // Compute prefix intersections
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prefix_idx <= 0;
    end else if (state == COMPUTE_PREFIX) begin
      if (prefix_idx == 0) begin
        // First rectangle
        prefix[0][0] <= rect_buffer[0][0]; // max_x1
        prefix[0][1] <= rect_buffer[0][1]; // max_y1
        prefix[0][2] <= rect_buffer[0][2]; // min_x2
        prefix[0][3] <= rect_buffer[0][3]; // min_y2
      end else begin
        // Intersect with previous prefix
        prefix[prefix_idx][0] <= (rect_buffer[prefix_idx][0] > prefix[prefix_idx-1][0]) ? rect_buffer[prefix_idx][0] : prefix[prefix_idx-1][0];
        prefix[prefix_idx][1] <= (rect_buffer[prefix_idx][1] > prefix[prefix_idx-1][1]) ? rect_buffer[prefix_idx][1] : prefix[prefix_idx-1][1];
        prefix[prefix_idx][2] <= (rect_buffer[prefix_idx][2] < prefix[prefix_idx-1][2]) ? rect_buffer[prefix_idx][2] : prefix[prefix_idx-1][2];
        prefix[prefix_idx][3] <= (rect_buffer[prefix_idx][3] < prefix[prefix_idx-1][3]) ? rect_buffer[prefix_idx][3] : prefix[prefix_idx-1][3];
      end
      prefix_idx <= prefix_idx + 1;
    end
  end

  // Compute suffix intersections
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      suffix_idx <= 0;
    end else if (state == COMPUTE_SUFFIX) begin
      if (suffix_idx == 0) begin
        // Last rectangle
        suffix[n-1][0] <= rect_buffer[n-1][0]; // max_x1
        suffix[n-1][1] <= rect_buffer[n-1][1]; // max_y1
        suffix[n-1][2] <= rect_buffer[n-1][2]; // min_x2
        suffix[n-1][3] <= rect_buffer[n-1][3]; // min_y2
      end else begin
        // Intersect with next suffix
        suffix[n-1-suffix_idx][0] <= (rect_buffer[n-1-suffix_idx][0] > suffix[n-suffix_idx][0]) ? rect_buffer[n-1-suffix_idx][0] : suffix[n-suffix_idx][0];
        suffix[n-1-suffix_idx][1] <= (rect_buffer[n-1-suffix_idx][1] > suffix[n-suffix_idx][1]) ? rect_buffer[n-1-suffix_idx][1] : suffix[n-suffix_idx][1];
        suffix[n-1-suffix_idx][2] <= (rect_buffer[n-1-suffix_idx][2] < suffix[n-suffix_idx][2]) ? rect_buffer[n-1-suffix_idx][2] : suffix[n-suffix_idx][2];
        suffix[n-1-suffix_idx][3] <= (rect_buffer[n-1-suffix_idx][3] < suffix[n-suffix_idx][3]) ? rect_buffer[n-1-suffix_idx][3] : suffix[n-suffix_idx][3];
      end
      suffix_idx <= suffix_idx + 1;
    end
  end

  // Check exclusion
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      excl_idx <= 0;
      valid <= 0;
    end else if (state == CHECK_EXCLUSION) begin
      // Compute intersection of prefix[excl_idx-1] and suffix[excl_idx+1]
      if (excl_idx == 0) begin
        // Exclude first rectangle
        temp_max_x1 = suffix[1][0];
        temp_max_y1 = suffix[1][1];
        temp_min_x2 = suffix[1][2];
        temp_min_y2 = suffix[1][3];
      end else if (excl_idx == n-1) begin
        // Exclude last rectangle
        temp_max_x1 = prefix[n-2][0];
        temp_max_y1 = prefix[n-2][1];
        temp_min_x2 = prefix[n-2][2];
        temp_min_y2 = prefix[n-2][3];
      end else begin
        // Exclude middle rectangle
        temp_max_x1 = (prefix[excl_idx-1][0] > suffix[excl_idx+1][0]) ? prefix[excl_idx-1][0] : suffix[excl_idx+1][0];
        temp_max_y1 = (prefix[excl_idx-1][1] > suffix[excl_idx+1][1]) ? prefix[excl_idx-1][1] : suffix[excl_idx+1][1];
        temp_min_x2 = (prefix[excl_idx-1][2] < suffix[excl_idx+1][2]) ? prefix[excl_idx-1][2] : suffix[excl_idx+1][2];
        temp_min_y2 = (prefix[excl_idx-1][3] < suffix[excl_idx+1][3]) ? prefix[excl_idx-1][3] : suffix[excl_idx+1][3];
      end

      // Check if intersection is valid
      if (temp_max_x1 <= temp_min_x2 && temp_max_y1 <= temp_min_y2) begin
        result_x <= temp_max_x1;
        result_y <= temp_max_y1;
        valid <= 1;
      end

      excl_idx <= excl_idx + 1;
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule