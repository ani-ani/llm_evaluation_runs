module laser_reflection_calculator (
  input [31:0] x1, y1, x2, y2, px, py,
  output reg valid_hit, inf_low, inf_high,
  output reg [31:0] y_low, y_high
);
  // Calculate mirror direction and normal
  wire [31:0] dx = x2 - x1;
  wire [31:0] dy = y2 - y1;
  
  // Normal vector (perpendicular to mirror line)
  wire [31:0] nx = dy;
  wire [31:0] ny = ~dx + 1; // -dx
  
  // Norm squared for reflection calculations
  wire [63:0] norm_sq = $signed(nx) * $signed(nx) + $signed(ny) * $signed(ny);
  
  // For each mirror endpoint, calculate reflected ray intersection with wall
  function [31:0] calculate_hit_y;
    input [31:0] mx, my; // mirror point coordinates
    reg [31:0] inc_x, inc_y;
    reg [31:0] dot_prod;
    reg [31:0] ref_x, ref_y;
    reg [63:0] temp_num, temp_den;
    reg [63:0] t_32_32;
    reg [31:0] hit_y;
    begin
      // Incident vector from shooter to mirror point
      inc_x = mx - px;
      inc_y = my - py;
      
      // Dot product with normal
      dot_prod = $signed(inc_x) * $signed(nx) + $signed(inc_y) * $signed(ny);
      
      // Reflection vector components
      // Using formula: R = I - 2*(I·N)/|N|² * N
      temp_num = $signed(2) * $signed(dot_prod) * $signed(nx);
      ref_x = inc_x - (temp_num / norm_sq);
      
      temp_num = $signed(2) * $signed(dot_prod) * $signed(ny);
      ref_y = inc_y - (temp_num / norm_sq);
      
      // Calculate intersection with wall at x=0
      // Parametric form: x = mx + t*ref_x = 0
      // t = -mx / ref_x
      if (ref_x != 0) begin
        // 32.32 intermediate precision for division
        temp_num = $signed(64'h8000000000000000) | $unsigned(32'h100000000) * $unsigned(mx);
        temp_den = $unsigned(ref_x) * $unsigned(32'h10000);
        t_32_32 = temp_num / temp_den;
        
        // y = my + t*ref_y
        hit_y = my + (t_32_32 * $unsigned(ref_y) >> 32);
      end else begin
        hit_y = 32'h7fffffff; // infinity placeholder
      end
    end
  endfunction
  
  // Calculate hit points for both mirror endpoints
  wire [31:0] hit_y1 = calculate_hit_y(x1, y1);
  wire [31:0] hit_y2 = calculate_hit_y(x2, y2);
  
  // Determine valid range
  always @(*) begin
    // Check if at least one hit is valid (not infinity)
    valid_hit = (hit_y1 != 32'h7fffffff) || (hit_y2 != 32'h7fffffff);
    
    if (valid_hit) begin
      // Determine bounds
      if (hit_y1 == 32'h7fffffff) begin
        // Only hit_y2 is valid
        y_low = hit_y2;
        y_high = hit_y2;
        inf_low = 1'b0;
        inf_high = 1'b0;
      end else if (hit_y2 == 32'h7fffffff) begin
        // Only hit_y1 is valid
        y_low = hit_y1;
        y_high = hit_y1;
        inf_low = 1'b0;
        inf_high = 1'b0;
      end else begin
        // Both are valid - set bounds
        if (hit_y1 < hit_y2) begin
          y_low = hit_y1;
          y_high = hit_y2;
        end else begin
          y_low = hit_y2;
          y_high = hit_y1;
        end
        inf_low = 1'b0;
        inf_high = 1'b0;
      end
    end else begin
      // No valid hits
      y_low = 32'h0;
      y_high = 32'h0;
      inf_low = 1'b0;
      inf_high = 1'b0;
    end
  end
endmodule