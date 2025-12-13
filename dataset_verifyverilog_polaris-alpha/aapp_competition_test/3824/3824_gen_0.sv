module quadcopter_path_length(
  input  signed [7:0] x1, // 8-bit signed start x
  input  signed [7:0] y1, // 8-bit signed start y
  input  signed [7:0] x2, // 8-bit signed flag x
  input  signed [7:0] y2, // 8-bit signed flag y
  output [10:0]       path_length // 11-bit unsigned path length
);

  // Step 1: Absolute differences (result fits in 8 bits for given range)
  wire [7:0] dx = (x1 >= x2) ? (x1 - x2) : (x2 - x1);
  wire [7:0] dy = (y1 >= y2) ? (y1 - y2) : (y2 - y1);

  // Step 2: Increment differences by 1
  wire [8:0] dx_inc = dx + 9'd1;
  wire [8:0] dy_inc = dy + 9'd1;

  // Step 3: Apply minimum value constraint (at least 2)
  wire [8:0] dx_final = (dx_inc < 9'd2) ? 9'd2 : dx_inc;
  wire [8:0] dy_final = (dy_inc < 9'd2) ? 9'd2 : dy_inc;

  // Step 4: Total path length = 2 * (dx_final + dy_final)
  wire [9:0] sum_final = dx_final + dy_final; // max 512
  assign path_length = {sum_final, 1'b0};     // multiply by 2

endmodule