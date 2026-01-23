module canyon_map_solver (
  input clk,
  input rst_n,
  input start,
  input [15:0] poly_x [0:15],
  input [15:0] poly_y [0:15],
  input [3:0] num_vertices,
  input [1:0] k,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    COMPUTE_BBOX,
    DETERMINE_AXIS,
    CALCULATE_SEGMENTS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] min_x, max_x, min_y, max_y;
  reg [15:0] current_x, current_y;
  reg [3:0] vertex_counter;
  reg [1:0] segment_counter;
  reg [15:0] segment_start, segment_end;
  reg [15:0] segment_width;
  reg [15:0] local_min_x, local_max_x, local_min_y, local_max_y;
  reg [15:0] local_width, local_height;
  reg [15:0] max_side_length;
  reg dominant_axis; // 0 for X, 1 for Y

  // Fixed-point conversion constants
  localparam [15:0] ONE = 16'd16; // 1.0 in Q12.4

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 32'd0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COMPUTE_BBOX;
      end
      COMPUTE_BBOX: begin
        if (vertex_counter == num_vertices) next_state = DETERMINE_AXIS;
      end
      DETERMINE_AXIS: begin
        if (k == 1) next_state = DONE;
        else next_state = CALCULATE_SEGMENTS;
      end
      CALCULATE_SEGMENTS: begin
        if (segment_counter == k) next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all internal registers
      min_x <= 16'h7FFF; // Initialize to max value
      max_x <= 16'h8000; // Initialize to min value
      min_y <= 16'h7FFF;
      max_y <= 16'h8000;
      vertex_counter <= 4'd0;
      segment_counter <= 2'd0;
      segment_start <= 16'd0;
      segment_end <= 16'd0;
      segment_width <= 16'd0;
      local_min_x <= 16'h7FFF;
      local_max_x <= 16'h8000;
      local_min_y <= 16'h7FFF;
      local_max_y <= 16'h8000;
      local_width <= 16'd0;
      local_height <= 16'd0;
      max_side_length <= 16'd0;
      dominant_axis <= 1'b0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          result <= 32'd0;
        end
        COMPUTE_BBOX: begin
          if (vertex_counter < num_vertices) begin
            current_x = poly_x[vertex_counter];
            current_y = poly_y[vertex_counter];
            
            // Update bounding box
            if (current_x < min_x) min_x <= current_x;
            if (current_x > max_x) max_x <= current_x;
            if (current_y < min_y) min_y <= current_y;
            if (current_y > max_y) max_y <= current_y;
            
            vertex_counter <= vertex_counter + 1'b1;
          end
        end
        DETERMINE_AXIS: begin
          // Calculate spans
          reg [15:0] x_span = max_x - min_x;
          reg [15:0] y_span = max_y - min_y;
          
          // Determine dominant axis
          dominant_axis <= (y_span > x_span) ? 1'b1 : 1'b0;
          
          // For k=1, compute result directly
          if (k == 1) begin
            reg [15:0] side_length = (x_span > y_span) ? x_span : y_span;
            // Convert to Q16.16
            result <= $signed({16'd0, side_length}) << 4;
            done <= 1'b1;
          end else begin
            // Initialize segment calculation
            segment_counter <= 2'd0;
            max_side_length <= 16'd0;
            
            if (dominant_axis == 1'b0) begin
              segment_width <= (max_x - min_x) / k;
              segment_start <= min_x;
              segment_end <= min_x + segment_width;
            end else begin
              segment_width <= (max_y - min_y) / k;
              segment_start <= min_y;
              segment_end <= min_y + segment_width;
            end
          end
        end
        CALCULATE_SEGMENTS: begin
          // Reset local bounding box for this segment
          local_min_x <= 16'h7FFF;
          local_max_x <= 16'h8000;
          local_min_y <= 16'h7FFF;
          local_max_y <= 16'h8000;
          
          // Process all vertices for this segment
          for (int i = 0; i < num_vertices; i = i + 1) begin
            current_x = poly_x[i];
            current_y = poly_y[i];
            
            // Check if vertex is in current segment
            if (dominant_axis == 1'b0) begin
              if (current_x >= segment_start && current_x < segment_end) begin
                if (current_x < local_min_x) local_min_x = current_x;
                if (current_x > local_max_x) local_max_x = current_x;
                if (current_y < local_min_y) local_min_y = current_y;
                if (current_y > local_max_y) local_max_y = current_y;
              end
            end else begin
              if (current_y >= segment_start && current_y < segment_end) begin
                if (current_x < local_min_x) local_min_x = current_x;
                if (current_x > local_max_x) local_max_x = current_x;
                if (current_y < local_min_y) local_min_y = current_y;
                if (current_y > local_max_y) local_max_y = current_y;
              end
            end
          end
          
          // Calculate local dimensions
          local_width = local_max_x - local_min_x;
          local_height = local_max_y - local_min_y;
          
          // Get maximum side length for this segment
          reg [15:0] segment_side = (local_width > local_height) ? local_width : local_height;
          
          // Update global maximum
          if (segment_side > max_side_length) max_side_length <= segment_side;
          
          // Move to next segment
          segment_counter <= segment_counter + 1'b1;
          segment_start <= segment_end;
          segment_end <= segment_start + segment_width;
          
          // If this was the last segment, prepare result
          if (segment_counter == k) begin
            // Convert to Q16.16
            result <= $signed({16'd0, max_side_length}) << 4;
            done <= 1'b1;
          end
        end
        DONE: begin
          // Stay in DONE state until reset
        end
        default: ;
      endcase
    end
  end

endmodule