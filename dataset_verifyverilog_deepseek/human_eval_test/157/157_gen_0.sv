module right_angle_triangle(input [7:0] a, b, c, output is_right);
  wire [15:0] a_sq = a * a;
  wire [15:0] b_sq = b * b;
  wire [15:0] c_sq = c * c;
  
  wire [16:0] sum_ab = a_sq + b_sq;
  wire [16:0] sum_ac = a_sq + c_sq;
  wire [16:0] sum_bc = b_sq + c_sq;
  
  assign is_right = (sum_ab == {1'b0, c_sq}) ||
                    (sum_ac == {1'b0, b_sq}) ||
                    (sum_bc == {1'b0, a_sq});
endmodule