module wire_bending (
  input clk,
  input rst_n,
  input start,
  input [3:0] bend_point,
  input bend_dir,
  input bend_valid,
  output reg ghost,
  output reg done
);

  // Direction encoding: 00=RIGHT, 01=UP, 10=LEFT, 11=DOWN
  parameter RIGHT = 2'b00;
  parameter UP = 2'b01;
  parameter LEFT = 2'b10;
  parameter DOWN = 2'b11;

  // State encoding
  typedef enum logic [3:0] {
    IDLE,
    READ_BEND,
    FIND_BEND_POINT,
    ADD_NEW_SEGMENT,
    CHECK_INTERSECTION,
    DONE,
    GHOST_DETECTED
  } state_t;

  state_t state, next_state;
  logic [3:0] bend_count;
  logic [3:0] current_x, current_y;
  logic [1:0] current_dir;
  logic [3:0] segment_start_x [0:7], segment_start_y [0:7], segment_end_x [0:7], segment_end_y [0:7];
  logic [3:0] num_segments;
  logic [3:0] bend_x, bend_y;
  logic [3:0] new_end_x, new_end_y;
  logic [3:0] cycle_count;

  // Initialize segments to straight line from (0,0) to (8,0)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      bend_count <= 0;
      current_x <= 0;
      current_y <= 0;
      current_dir <= RIGHT;
      num_segments <= 1;
      segment_start_x[0] <= 0;
      segment_start_y[0] <= 0;
      segment_end_x[0] <= 8;
      segment_end_y[0] <= 0;
      ghost <= 0;
      done <= 0;
      cycle_count <= 0;
    end else begin
      state <= next_state;
      if (state == READ_BEND && bend_valid) begin
        bend_count <= bend_count + 1;
      end
      if (state == FIND_BEND_POINT) begin
        // Traverse segments to find bend point coordinate
        if (cycle_count == 0) begin
          bend_x <= segment_start_x[0];
          bend_y <= segment_start_y[0];
        end else begin
          for (int i = 0; i < num_segments; i++) begin
            if (segment_start_x[i] <= bend_point && segment_end_x[i] >= bend_point && 
                segment_start_y[i] == segment_end_y[i]) begin
              bend_x <= segment_start_x[i] + bend_point;
              bend_y <= segment_start_y[i];
            end else if (segment_start_y[i] <= bend_point && segment_end_y[i] >= bend_point && 
                         segment_start_x[i] == segment_end_x[i]) begin
              bend_x <= segment_start_x[i];
              bend_y <= segment_start_y[i] + bend_point;
            end
          end
        end
      end
      if (state == ADD_NEW_SEGMENT) begin
        // Calculate new segment endpoint
        case (current_dir)
          RIGHT: new_end_x <= bend_x + (8 - bend_point);
          UP: new_end_y <= bend_y + (8 - bend_point);
          LEFT: new_end_x <= bend_x - (8 - bend_point);
          DOWN: new_end_y <= bend_y - (8 - bend_point);
        endcase
        // Update current position and direction
        current_x <= new_end_x;
        current_y <= new_end_y;
        if (bend_dir) begin
          // Counter-clockwise
          case (current_dir)
            RIGHT: current_dir <= UP;
            UP: current_dir <= LEFT;
            LEFT: current_dir <= DOWN;
            DOWN: current_dir <= RIGHT;
          endcase
        end else begin
          // Clockwise
          case (current_dir)
            RIGHT: current_dir <= DOWN;
            DOWN: current_dir <= LEFT;
            LEFT: current_dir <= UP;
            UP: current_dir <= RIGHT;
          endcase
        end
      end
      if (state == CHECK_INTERSECTION) begin
        // Check if new segment intersects any existing segment
        logic intersection_detected = 0;
        for (int i = 0; i < num_segments; i++) begin
          if (check_intersection(bend_x, bend_y, new_end_x, new_end_y,
                                segment_start_x[i], segment_start_y[i],
                                segment_end_x[i], segment_end_y[i])) begin
            intersection_detected = 1;
          end
        end
        if (intersection_detected) begin
          ghost <= 1;
          next_state <= GHOST_DETECTED;
        end
      end
      cycle_count <= cycle_count + 1;
    end
  end

  // State transition logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = READ_BEND;
          cycle_count = 0;
        end
      end
      READ_BEND: begin
        if (bend_valid && bend_count < 8) begin
          next_state = FIND_BEND_POINT;
          cycle_count = 0;
        end else if (bend_count >= 8) begin
          next_state = DONE;
        end
      end
      FIND_BEND_POINT: begin
        if (cycle_count >= 10) begin
          next_state = ADD_NEW_SEGMENT;
          cycle_count = 0;
        end
      end
      ADD_NEW_SEGMENT: begin
        if (cycle_count >= 10) begin
          next_state = CHECK_INTERSECTION;
          cycle_count = 0;
        end
      end
      CHECK_INTERSECTION: begin
        if (cycle_count >= 10) begin
          if (ghost) begin
            next_state = GHOST_DETECTED;
          end else if (bend_count >= 8) begin
            next_state = DONE;
          end else begin
            next_state = READ_BEND;
          end
          cycle_count = 0;
        end
      end
      DONE: begin
        done = 1;
      end
      GHOST_DETECTED: begin
        ghost = 1;
      end
    endcase
  end

  // Function to check if two segments intersect
  function logic check_intersection(
    input [3:0] a1x, input [3:0] a1y,
    input [3:0] a2x, input [3:0] a2y,
    input [3:0] b1x, input [3:0] b1y,
    input [3:0] b2x, input [3:0] b2y
  );
    // Check if segments are collinear and overlapping
    if ((a1x == a2x && b1x == b2x && a1x == b1x) ||
        (a1y == a2y && b1y == b2y && a1y == b1y)) begin
      // Check if segments overlap
      if (a1x <= b2x && a2x >= b1x && a1y <= b2y && a2y >= b1y) begin
        return 1;
      end
    end
    // Check if endpoints coincide
    if ((a1x == b1x && a1y == b1y) ||
        (a1x == b2x && a1y == b2y) ||
        (a2x == b1x && a2y == b1y) ||
        (a2x == b2x && a2y == b2y)) begin
      return 1;
    end
    // Check for proper intersection
    if ((a1x <= b1x && a2x >= b1x && a1y >= b1y && a2y <= b1y) ||
        (a1x >= b1x && a2x <= b1x && a1y <= b1y && a2y >= b1y)) begin
      return 1;
    end
    return 0;
  endfunction

  // Update segments when adding new segment
  always @(posedge clk) begin
    if (state == ADD_NEW_SEGMENT && cycle_count == 0) begin
      // Truncate existing segment at bend point
      for (int i = 0; i < num_segments; i++) begin
        if (segment_start_x[i] <= bend_point && segment_end_x[i] >= bend_point && 
            segment_start_y[i] == segment_end_y[i]) begin
          segment_end_x[i] <= bend_x;
        end else if (segment_start_y[i] <= bend_point && segment_end_y[i] >= bend_point && 
                     segment_start_x[i] == segment_end_x[i]) begin
          segment_end_y[i] <= bend_y;
        end
      end
      // Add new segment
      segment_start_x[num_segments] <= bend_x;
      segment_start_y[num_segments] <= bend_y;
      segment_end_x[num_segments] <= new_end_x;
      segment_end_y[num_segments] <= new_end_y;
      num_segments <= num_segments + 1;
    end
  end

endmodule