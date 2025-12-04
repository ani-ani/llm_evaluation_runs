module max_rectangle_finder (
  input [7:0] n,
  input [7:0] m,
  input [7:0] x,
  input [7:0] y,
  input [7:0] a,
  input [7:0] b,
  output [7:0] x1,
  output [7:0] y1,
  output [7:0] x2,
  output [7:0] y2
);
  logic [7:0] scale_n, scale_m, scale;
  logic [7:0] rect_width, rect_height;
  logic [7:0] x_center, y_center;
  logic [7:0] x1_temp, y1_temp;

  always_comb begin
    // Step 1: Compute scale
    scale_n = n / a;
    scale_m = m / b;
    scale = (scale_n < scale_m) ? scale_n : scale_m;

    // Step 2: Calculate dimensions
    rect_width = a * scale;
    rect_height = b * scale;

    // Step 3: Set center
    x_center = x;
    y_center = y;

    // Step 4: Compute x1 with clamping
    x1_temp = (x_center >= (rect_width / 2)) ? (x_center - (rect_width / 2)) : 0;
    if (x1_temp + rect_width > n) x1_temp = n - rect_width;

    // Step 5: Compute y1 with clamping
    y1_temp = (y_center >= (rect_height / 2)) ? (y_center - (rect_height / 2)) : 0;
    if (y1_temp + rect_height > m) y1_temp = m - rect_height;

    // Drive outputs (Step 6)
    x1 = x1_temp;
    y1 = y1_temp;
    x2 = x1 + rect_width;
    y2 = y1 + rect_height;
  end
endmodule