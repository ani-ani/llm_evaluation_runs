module bulkhead_planner (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_vertices,
  input [31:0] min_area,
  input [31:0] vertices_x [0:7],
  input [31:0] vertices_y [0:7],
  output reg [2:0] M,
  output reg [31:0] bulkhead_x [0:6],
  output reg [2:0] bulkhead_count,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_TOTAL_AREA,
    FIND_M,
    CALC_TARGET,
    PLACE_BULKHEADS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [31:0] total_area;
  reg [31:0] target_area;
  reg [31:0] current_x;
  reg [31:0] min_x, max_x;
  reg [31:0] current_area;
  reg [31:0] step_size;
  reg [7:0] step_counter;
  reg [2:0] current_bulkhead;
  reg [31:0] cumulative_area;
  reg [31:0] prev_y0, prev_y1;

  // Compute shoelace area (combinational)
  function [31:0] compute_shoelace_area;
    input [2:0] n;
    input [31:0] x [0:7];
    input [31:0] y [0:7];
    integer i;
    reg [31:0] sum;
    begin
      sum = 0;
      for (i = 0; i < n; i = i + 1) begin
        sum = sum + (x[i] * y[(i+1) % n] - x[(i+1) % n] * y[i]);
      end
      compute_shoelace_area = (sum[31] ? -sum : sum) >> 1; // Absolute value and divide by 2
    end
  endfunction

  // Find Y coordinates at given X (combinational)
  function [31:0] find_y_at_x;
    input [31:0] x_val;
    input [2:0] n;
    input [31:0] x [0:7];
    input [31:0] y [0:7];
    integer i;
    reg [31:0] y0, y1;
    begin
      y0 = 0;
      y1 = 0;
      for (i = 0; i < n; i = i + 1) begin
        if (x[i] <= x_val && x_val < x[(i+1) % n]) begin
          // Linear interpolation
          y0 = y[i] + ((y[(i+1) % n] - y[i]) * (x_val - x[i])) / (x[(i+1) % n] - x[i]);
          y1 = y0;
        end
      end
      find_y_at_x = y0;
    end
  endfunction

  // Find min and max X coordinates
  function [31:0] find_min_x;
    input [2:0] n;
    input [31:0] x [0:7];
    integer i;
    reg [31:0] min_val;
    begin
      min_val = x[0];
      for (i = 1; i < n; i = i + 1) begin
        if (x[i] < min_val) min_val = x[i];
      end
      find_min_x = min_val;
    end
  endfunction

  function [31:0] find_max_x;
    input [2:0] n;
    input [31:0] x [0:7];
    integer i;
    reg [31:0] max_val;
    begin
      max_val = x[0];
      for (i = 1; i < n; i = i + 1) begin
        if (x[i] > max_val) max_val = x[i];
      end
      find_max_x = max_val;
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      M <= 0;
      bulkhead_count <= 0;
      done <= 0;
      total_area <= 0;
      target_area <= 0;
      current_x <= 0;
      min_x <= 0;
      max_x <= 0;
      current_area <= 0;
      step_size <= 0;
      step_counter <= 0;
      current_bulkhead <= 0;
      cumulative_area <= 0;
      prev_y0 <= 0;
      prev_y1 <= 0;
      for (int i = 0; i < 7; i = i + 1) begin
        bulkhead_x[i] <= 0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CALC_TOTAL_AREA;
      end
      CALC_TOTAL_AREA: begin
        next_state = FIND_M;
      end
      FIND_M: begin
        next_state = CALC_TARGET;
      end
      CALC_TARGET: begin
        if (M > 1) next_state = PLACE_BULKHEADS;
        else next_state = DONE;
      end
      PLACE_BULKHEADS: begin
        if (current_bulkhead == M - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Already handled in state machine reset
    end else begin
      case (current_state)
        CALC_TOTAL_AREA: begin
          total_area <= compute_shoelace_area(num_vertices, vertices_x, vertices_y);
          min_x <= find_min_x(num_vertices, vertices_x);
          max_x <= find_max_x(num_vertices, vertices_x);
        end
        FIND_M: begin
          if (min_area == 0) M <= 8;
          else M <= (total_area / min_area) > 8 ? 8 : (total_area / min_area);
          if (M == 0) M <= 1;
        end
        CALC_TARGET: begin
          target_area <= total_area / M;
          bulkhead_count <= M - 1;
          current_bulkhead <= 0;
          cumulative_area <= 0;
          step_size <= (max_x - min_x) / 256;
          current_x <= min_x;
          step_counter <= 0;
        end
        PLACE_BULKHEADS: begin
          if (step_counter == 0) begin
            prev_y0 <= find_y_at_x(current_x, num_vertices, vertices_x, vertices_y);
            prev_y1 <= prev_y0;
          end
          if (step_counter < 256) begin
            current_x <= current_x + step_size;
            step_counter <= step_counter + 1;
            current_area <= (prev_y0 + find_y_at_x(current_x, num_vertices, vertices_x, vertices_y)) * step_size / 2;
            cumulative_area <= cumulative_area + current_area;
            if (cumulative_area >= target_area * (current_bulkhead + 1)) begin
              bulkhead_x[current_bulkhead] <= current_x;
              current_bulkhead <= current_bulkhead + 1;
              cumulative_area <= 0;
              current_x <= min_x;
              step_counter <= 0;
            end
          end
        end
        DONE: begin
          done <= 1;
        end
        default: ;
      endcase
    end
  end

  // Reset done when leaving DONE state
  always @(posedge clk) begin
    if (current_state == DONE && next_state != DONE) begin
      done <= 0;
    end
  end

endmodule