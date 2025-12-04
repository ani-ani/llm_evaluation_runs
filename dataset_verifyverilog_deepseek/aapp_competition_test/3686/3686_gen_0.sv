module laser_target_checker (
  input clk, rst_n, start,
  input [4:0] x_coords [0:5],
  input [4:0] y_coords [0:5],
  output reg done, success
);
  
  typedef enum {IDLE, CHECK_SINGLE, DUAL_INIT, DUAL_COMBO, DUAL_EVAL, COMPLETE} state_t;
  
  logic signed [4:0] p0x, p0y, p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y, p5x, p5y;
  state_t state, next_state;
  logic [1:0] combo_idx;
  logic [5:0] online_mask;
  logic [2:0] off_cnt;
  logic [4:0] rem_x[0:2], rem_y[0:2];
  logic set_success;
  
  // Cast input coordinates to signed
  always_comb begin
    {p0x,p0y} = {x_coords[0], y_coords[0]};
    {p1x,p1y} = {x_coords[1], y_coords[1]};
    {p2x,p2y} = {x_coords[2], y_coords[2]};
    {p3x,p3y} = {x_coords[3], y_coords[3]};
    {p4x,p4y} = {x_coords[4], y_coords[4]};
    {p5x,p5y} = {x_coords[5], y_coords[5]};
  end
  
  // Colinearity check function
  function automatic logic is_colinear(
    input signed [4:0] x0,y0,x1,y1,x2,y2);
    logic signed [10:0] lhs, rhs;
    lhs = (y1 - y0) * (x2 - x0);
    rhs = (y2 - y0) * (x1 - x0);
    return (lhs == rhs);
  endfunction
  
  // Single line colinear check
  function automatic logic single_line_ok();
    return (is_colinear(p0x,p0y,p1x,p1y,p2x,p2y) &&
            is_colinear(p0x,p0y,p1x,p1y,p3x,p3y) &&
            is_colinear(p0x,p0y,p1x,p1y,p4x,p4y) &&
            is_colinear(p0x,p0y,p1x,p1y,p5x,p5y));
  endfunction
  
  // Generate online_mask for current line
  function logic [5:0] get_online_mask(input signed [4:0] x0,y0,x1,y1);
    logic [5:0] mask;
    mask[0] = is_colinear(x0,y0,x1,y1,p0x,p0y);
    mask[1] = is_colinear(x0,y0,x1,y1,p1x,p1y);
    mask[2] = is_colinear(x0,y0,x1,y1,p2x,p2y);
    mask[3] = is_colinear(x0,y0,x1,y1,p3x,p3y);
    mask[4] = is_colinear(x0,y0,x1,y1,p4x,p4y);
    mask[5] = is_colinear(x0,y0,x1,y1,p5x,p5y);
    return mask;
  endfunction
  
  // Collect offline points
  function logic [2:0] get_offline_cnt(input [5:0] mask);
    return 6 - (mask[0]+mask[1]+mask[2]+mask[3]+mask[4]+mask[5]);
  endfunction
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      success <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          success <= 0;
          if (start) state <= CHECK_SINGLE;
        end
        
        CHECK_SINGLE: begin
          if (single_line_ok()) begin
            success <= 1;
            state <= COMPLETE;
          end else state <= DUAL_INIT;
        end
        
        DUAL_INIT: begin
          combo_idx <= 0;
          state <= DUAL_COMBO;
        end
        
        DUAL_COMBO: begin
          case (combo_idx)
            0: online_mask <= get_online_mask(p0x,p0y,p1x,p1y);
            1: online_mask <= get_online_mask(p0x,p0y,p3x,p3y);
            2: online_mask <= get_online_mask(p1x,p1y,p2x,p2y);
          endcase
          state <= DUAL_EVAL;
        end
        
        DUAL_EVAL: begin
          off_cnt <= get_offline_cnt(online_mask);
          
          if (($countones(online_mask) >=3) && (off_cnt <=1)) set_success <= 1;
          else if (off_cnt ==2) set_success <= 1;
          else if (off_cnt ==3) begin
            // Load rem_x/rem_y with offline points
            integer j=0;
            for (int i=0; i<6; i++) begin
              if (!online_mask[i]) begin
                {rem_x[j], rem_y[j]} = {x_coords[i], y_coords[i]};
                j++;
              end
            end
            set_success <= is_colinear(rem_x[0],rem_y[0],rem_x[1],rem_y[1],
                                      rem_x[2],rem_y[2]);
          end
          else set_success <= 0;
          
          state <= COMPLETE;
        end
        
        COMPLETE: begin
          done <= 1;
          if (state != COMPLETE && set_success)
            success <= 1;
          // Remain in COMPLETE until reset or start
        end
      endcase
    end
  end
  
  // Next state logic (minimum cycle count)
  always_comb begin
    next_state = state;
    case (state)
      DUAL_EVAL: 
        if (combo_idx != 2 && !set_success) begin
          combo_idx += 1;
          next_state = DUAL_COMBO;
        end
      default: ;
    endcase
  end
endmodule