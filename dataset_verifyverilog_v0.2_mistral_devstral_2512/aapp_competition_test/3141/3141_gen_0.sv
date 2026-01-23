module drill_min_diameter (
  input clk,
  input rst_n,
  input start,
  input [31:0] flaw_x [0:7],
  input [31:0] flaw_y [0:7],
  output reg [31:0] diameter,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CALCULATE_BBOX,
    CALCULATE_CENTER,
    CHECK_SUPPORT,
    REFINE_RADIUS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Intermediate registers
  reg [31:0] center_x, center_y;
  reg [31:0] radius;
  reg [3:0] iteration_count;
  reg [31:0] min_x, max_x, min_y, max_y;
  reg [31:0] farthest_x, farthest_y;
  reg [31:0] max_dist_sq;
  reg [31:0] temp_x, temp_y, temp_dist_sq;

  // Fixed-point constants
  localparam [31:0] HALF = 16'h8000;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      diameter <= 0;
      iteration_count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CALCULATE_BBOX;
      end
      CALCULATE_BBOX: next_state = CALCULATE_CENTER;
      CALCULATE_CENTER: next_state = CHECK_SUPPORT;
      CHECK_SUPPORT: begin
        if (iteration_count < 16) next_state = REFINE_RADIUS;
        else next_state = DONE;
      end
      REFINE_RADIUS: next_state = CHECK_SUPPORT;
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_x <= 0; max_x <= 0; min_y <= 0; max_y <= 0;
      center_x <= 0; center_y <= 0;
      radius <= 0;
      farthest_x <= 0; farthest_y <= 0;
      max_dist_sq <= 0;
    end else begin
      case (current_state)
        CALCULATE_BBOX: begin
          // Initialize with first point
          min_x <= flaw_x[0];
          max_x <= flaw_x[0];
          min_y <= flaw_y[0];
          max_y <= flaw_y[0];
          
          // Find min/max for all points
          for (int i = 1; i < 8; i++) begin
            if (flaw_x[i] < min_x) min_x <= flaw_x[i];
            if (flaw_x[i] > max_x) max_x <= flaw_x[i];
            if (flaw_y[i] < min_y) min_y <= flaw_y[i];
            if (flaw_y[i] > max_y) max_y <= flaw_y[i];
          end
        end
        
        CALCULATE_CENTER: begin
          // Calculate center as midpoint of bounding box
          center_x <= (min_x + max_x) >> 1;
          center_y <= (min_y + max_y) >> 1;
          
          // Initialize radius to half diagonal
          temp_x = (max_x - min_x) >> 1;
          temp_y = (max_y - min_y) >> 1;
          radius <= sqrt_approx((temp_x * temp_x) >> 16, (temp_y * temp_y) >> 16);
          iteration_count <= 0;
        end
        
        CHECK_SUPPORT: begin
          // Find farthest point from current center
          max_dist_sq <= 0;
          farthest_x <= flaw_x[0];
          farthest_y <= flaw_y[0];
          
          for (int i = 0; i < 8; i++) begin
            temp_x = flaw_x[i] - center_x;
            temp_y = flaw_y[i] - center_y;
            temp_dist_sq = ((temp_x * temp_x) >> 16) + ((temp_y * temp_y) >> 16);
            
            if (temp_dist_sq > max_dist_sq) begin
              max_dist_sq <= temp_dist_sq;
              farthest_x <= flaw_x[i];
              farthest_y <= flaw_y[i];
            end
          end
        end
        
        REFINE_RADIUS: begin
          // Update center toward farthest point
          center_x <= (center_x + farthest_x) >> 1;
          center_y <= (center_y + farthest_y) >> 1;
          
          // Update radius
          temp_x = farthest_x - center_x;
          temp_y = farthest_y - center_y;
          radius <= sqrt_approx((temp_x * temp_x) >> 16, (temp_y * temp_y) >> 16);
          
          iteration_count <= iteration_count + 1;
        end
        
        DONE: begin
          diameter <= radius << 1;  // diameter = 2 * radius
          done <= 1;
        end
        
        default: begin
          done <= 0;
        end
      endcase
    end
  end

  // Fixed-point square root approximation (Q16.16)
  function [31:0] sqrt_approx(input [31:0] x_sq, input [31:0] y_sq);
    reg [31:0] dist_sq = x_sq + y_sq;
    reg [31:0] result = 0;
    reg [31:0] bit = 1 << 30;
    
    if (dist_sq == 0) return 0;
    
    while (bit > dist_sq) bit = bit >> 2;
    
    while (bit != 0) begin
      if (dist_sq >= result + bit) begin
        dist_sq = dist_sq - (result + bit);
        result = (result >> 1) + bit;
      end else begin
        result = result >> 1;
      end
      bit = bit >> 2;
    end
    
    return result;
  endfunction

endmodule