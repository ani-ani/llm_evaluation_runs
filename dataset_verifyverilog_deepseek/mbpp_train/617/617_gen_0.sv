module min_jumps(input [7:0] a, b, d, output [15:0] jumps);
  wire [7:0] min_ab = (a < b) ? a : b;
  wire [7:0] max_ab = (a < b) ? b : a;
  wire d_zero = (d == 8'd0);
  wire d_eq_a = (d == min_ab);
  wire d_lt_b = (d < max_ab) && (d != 8'd0) && (d != min_ab);
  wire [16:0] numerator = (d + max_ab - 8'd1) << 8;
  wire [15:0] div_result = (max_ab == 8'd0) ? 16'd0 : numerator / max_ab;
  assign jumps = d_zero ? 16'd0 :
                 d_eq_a ? 16'h0100 :
                 d_lt_b ? 16'h0200 :
                 div_result;
endmodule