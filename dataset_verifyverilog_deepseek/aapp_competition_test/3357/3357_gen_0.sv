module sunlight_calculator(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_buildings,
  input [15:0] x_pos [7:0],
  input [15:0] height [7:0],
  output reg [31:0] sunlight [7:0],
  output reg done
);

  parameter DELAY_CYCLES = 60;
  parameter ANGLE_180 = 16'hB400; // Q8.8: 180.0 degrees
  parameter MULT_CONST = 32'hCCCC; // 12/15 in Q16.16 format (0.79998779296875)
  
  typedef enum logic [2:0] {IDLE, CALC_LEFT, CALC_RIGHT, COMPUTE_SUN, WAIT, DONE_ST} state_t;
  
  state_t current_state, next_state;
  reg [15:0] max_left [7:0];
  reg [15:0] max_right [7:0];
  reg [5:0] cycle_count;
  reg [2:0] bldg_idx;
  reg [2:0] inner_idx;
  reg calc_dir; // 0:left, 1:right

  // Angle calculation function (placeholder - implement CORDIC/LUT here)
  function automatic [15:0] calc_atan2(input [15:0] dy, dx);
    // Actual implementation required here
    // Returns Q8.8 angle (0-180Â°)
    return (dx == 0) ? 16'h7FFF : 16'h0000; // Default value
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      sunlight <= '{default:0};
      cycle_count <= 0;
    end else begin
      current_state <= next_state;
      cycle_count <= (current_state == IDLE || start) ? 0 : cycle_count + 1;
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = CALC_LEFT;
      
      CALC_LEFT, CALC_RIGHT: begin
        if (inner_idx == (calc_dir ? 7 - bldg_idx : bldg_idx)) begin
          next_state = (bldg_idx == num_buildings-1) ? COMPUTE_SUN : CALC_LEFT;
          if (current_state == CALC_LEFT && bldg_idx != num_buildings-1)
            next_state = CALC_LEFT;
        end
      end
      
      COMPUTE_SUN: next_state = WAIT;
      
      WAIT: begin
        if (cycle_count == DELAY_CYCLES - 1)
          next_state = DONE_ST;
      end
      
      DONE_ST: if (start) next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      bldg_idx <= 0;
      inner_idx <= 0;
      calc_dir <= 0;
      max_left <= '{default:0};
      max_right <= '{default:0};
    end else begin
      case (current_state)
        IDLE: begin
          bldg_idx <= 0;
          inner_idx <= 0;
          done <= 0;
          if (start) begin
            max_left <= '{default:0};
            max_right <= '{default:0};
          end
        end
        
        CALC_LEFT: begin
          calc_dir <= 0;
          if (bldg_idx > 0 && inner_idx < bldg_idx) begin
            automatic logic [15:0] dx = x_pos[bldg_idx] - x_pos[inner_idx];
            automatic logic [15:0] dy = height[inner_idx] - height[bldg_idx];
            automatic logic [15:0] angle = calc_atan2(dy, dx);
            
            if (angle > max_left[bldg_idx])
              max_left[bldg_idx] <= angle;
            
            inner_idx <= inner_idx + 1;
          end else if (inner_idx == bldg_idx) begin
            bldg_idx <= bldg_idx + 1;
            inner_idx <= 0;
          end
        end
        
        CALC_RIGHT: begin
          calc_dir <= 1;
          if (bldg_idx < num_buildings-1 && inner_idx < 7 - bldg_idx) begin
            automatic logic [2:0] k = bldg_idx + 1 + inner_idx;
            automatic logic [15:0] dx = x_pos[k] - x_pos[bldg_idx];
            automatic logic [15:0] dy = height[k] - height[bldg_idx];
            automatic logic [15:0] angle = calc_atan2(dy, dx);

            if (angle > max_right[bldg_idx])
              max_right[bldg_idx] <= angle;
            
            inner_idx <= inner_idx + 1;
          end else if (inner_idx == 7 - bldg_idx) begin
            bldg_idx <= bldg_idx + 1;
            inner_idx <= 0;
          end
        end
        
        COMPUTE_SUN: begin
          automatic logic [15:0] angle_sum = max_left[bldg_idx] + max_right[bldg_idx];
          automatic logic [15:0] angle_diff = ANGLE_180 - angle_sum;
          automatic logic [47:0] temp = (angle_diff * MULT_CONST);
          automatic logic [31:0] result = temp[47:16]; // Convert to Q16.16
          
          sunlight[bldg_idx] <= (result > 32'hC0000000) ? 32'hC0000000 : result;
          
          if (bldg_idx == num_buildings-1)
            bldg_idx <= 0;
          else
            bldg_idx <= bldg_idx + 1;
        end
        
        DONE_ST: done <= 1;
        
        WAIT: if (cycle_count == DELAY_CYCLES-1)
          done <= 1;
      endcase
    end
  end
endmodule