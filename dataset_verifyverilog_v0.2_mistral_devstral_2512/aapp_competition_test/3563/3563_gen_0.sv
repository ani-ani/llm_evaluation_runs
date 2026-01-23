module min_lines_convex (
  input clk,
  input rst_n,
  input start,
  input [5:0] n,
  input [7:0][15:0] x_coords,
  input [7:0][15:0] y_coords,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    CHECK_COLLINEAR,
    EXTEND_LINE,
    NEW_LINE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [5:0] current_point;
  reg [5:0] line_start;
  reg [3:0] line_count;
  reg [5:0] counter;

  // Collinearity check variables
  reg [15:0] x1, y1, x2, y2, x3, y3;
  reg [31:0] cross_product;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_point <= 0;
      line_start <= 0;
      line_count <= 0;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          if (start) begin
            next_state <= INIT;
          end
        end
        
        INIT: begin
          current_point <= 0;
          line_start <= 0;
          line_count <= 0;
          counter <= 0;
          next_state <= CHECK_COLLINEAR;
        end
        
        CHECK_COLLINEAR: begin
          if (counter < 200) begin
            counter <= counter + 1;
            next_state <= CHECK_COLLINEAR;
          end else begin
            counter <= 0;
            next_state <= EXTEND_LINE;
          end
        end
        
        EXTEND_LINE: begin
          // Check if next point is collinear
          x1 = x_coords[line_start];
          y1 = y_coords[line_start];
          x2 = x_coords[current_point];
          y2 = y_coords[current_point];
          
          // Handle wrap-around for cyclic polygon
          if (current_point == n-1) begin
            x3 = x_coords[0];
            y3 = y_coords[0];
          end else begin
            x3 = x_coords[current_point + 1];
            y3 = y_coords[current_point + 1];
          end
          
          // Compute cross product
          cross_product = ($signed(x2) - $signed(x1)) * ($signed(y3) - $signed(y1)) - 
                         ($signed(y2) - $signed(y1)) * ($signed(x3) - $signed(x1));
          
          if (cross_product == 0) begin
            // Points are collinear, extend line
            if (current_point == n-1) begin
              current_point <= 0;
            end else begin
              current_point <= current_point + 1;
            end
            next_state <= CHECK_COLLINEAR;
          end else begin
            // Not collinear, need new line
            next_state <= NEW_LINE;
          end
        end
        
        NEW_LINE: begin
          line_count <= line_count + 1;
          
          // Move to next ungrouped point
          if (current_point == n-1) begin
            current_point <= 0;
          end else begin
            current_point <= current_point + 1;
          end
          
          line_start <= current_point;
          
          // Check if all points are covered
          if (line_count == n) begin
            next_state <= DONE;
          end else begin
            next_state <= CHECK_COLLINEAR;
          end
        end
        
        DONE: begin
          result <= line_count;
          done <= 1;
          next_state <= IDLE;
        end
        
        default: next_state <= IDLE;
      endcase
    end
  end

  // Default state transition
  always @(*) begin
    next_state = state;
  end

endmodule