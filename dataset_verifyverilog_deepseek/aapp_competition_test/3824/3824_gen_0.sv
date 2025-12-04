module quadcopter_path_length(
  input signed [7:0] x1,
  input signed [7:0] y1,
  input signed [7:0] x2,
  input signed [7:0] y2,
  output reg [10:0] path_length
);
  wire signed [8:0] diff_x = x1 - x2;
  wire signed [8:0] diff_y = y1 - y2;
  wire [8:0] abs_diff_x = diff_x[8] ? -diff_x : diff_x;
  wire [8:0] abs_diff_y = diff_y[8] ? -diff_y : diff_y;
  wire [8:0] dx_inc = abs_diff_x + 1;
  wire [8:0] dy_inc = abs_diff_y + 1;
  wire [8:0] dx_final = (dx_inc < 9'd2) ? 9'd2 : dx_inc;
  wire [8:0] dy_final = (dy_inc < 9'd2) ? 9'd2 : dy_inc;
  wire [9:0] sum = dx_final + dy_final;
  always @* path_length = sum * 2;
endmodule