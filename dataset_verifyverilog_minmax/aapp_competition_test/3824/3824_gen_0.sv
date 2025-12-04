module quadcopter_path_length(
  input signed [7:0] x1,
  input signed [7:0] y1,
  input signed [7:0] x2,
  input signed [7:0] y2,
  output logic [10:0] path_length
);
  // Local signals
  logic signed [7:0] dxs, dys;     // raw signed differences
  logic [7:0] dx, dy;              // absolute differences
  logic [7:0] dx_inc, dy_inc;      // dx+1, dy+1
  logic [7:0] dx_final, dy_final;  // after minimum constraint (>=2)
  logic [9:0] sum_xy;              // dx_final + dy_final

  // 1) Compute absolute differences
  assign dxs = x2 - x1;
  assign dys = y2 - y1;
  assign dx = (dxs >= 0) ? dxs : -dxs;
  assign dy = (dys >= 0) ? dys : -dys;

  // 2) Add 1 to each difference
  assign dx_inc = dx + 1;
  assign dy_inc = dy + 1;

  // 3) Apply minimum value constraint: if < 2, use 2; otherwise keep incremented value
  assign dx_final = (dx_inc < 2) ? 8'd2 : dx_inc;
  assign dy_final = (dy_inc < 2) ? 8'd2 : dy_inc;

  // 4) Calculate total path length: 2 * (dx_final + dy_final)
  assign sum_xy     = dx_final + dy_final;
  assign path_length = {1'b0, sum_xy} << 1;  // multiply by 2 (safe in 11 bits)

endmodule