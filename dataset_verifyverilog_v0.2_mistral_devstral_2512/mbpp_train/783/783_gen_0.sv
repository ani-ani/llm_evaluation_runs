module rgb_to_hsv (
  input [31:0] r,
  input [31:0] g,
  input [31:0] b,
  output [31:0] h,
  output [31:0] s,
  output [31:0] v
);

  wire [31:0] mx, mn, df;
  wire [31:0] r_eq_mx, g_eq_mx, b_eq_mx;
  wire [31:0] h_temp, s_temp, v_temp;
  wire [31:0] sixty = 32'h3C0000; // 60 in Q16.16
  wire [31:0] hundred = 32'h640000; // 100 in Q16.16
  wire [31:0] three_sixty = 32'h1680000; // 360 in Q16.16

  // Determine max and min
  assign mx = (r > g) ? ((r > b) ? r : b) : ((g > b) ? g : b);
  assign mn = (r < g) ? ((r < b) ? r : b) : ((g < b) ? g : b);
  assign df = mx - mn;

  // Check which component is max
  assign r_eq_mx = (r == mx) ? 32'h1 : 32'h0;
  assign g_eq_mx = (g == mx) ? 32'h1 : 32'h0;
  assign b_eq_mx = (b == mx) ? 32'h1 : 32'h0;

  // Hue calculation
  wire [31:0] h_case1, h_case2, h_case3;
  wire [31:0] h_case1_temp, h_case2_temp, h_case3_temp;

  // Case 1: mx == r
  assign h_case1_temp = (g - b) * sixty;
  assign h_case1 = (df == 0) ? 0 : (h_case1_temp / df) + three_sixty;

  // Case 2: mx == g
  assign h_case2_temp = (b - r) * sixty;
  assign h_case2 = (df == 0) ? 0 : (h_case2_temp / df) + 32'hC80000; // 120 in Q16.16

  // Case 3: mx == b
  assign h_case3_temp = (r - g) * sixty;
  assign h_case3 = (df == 0) ? 0 : (h_case3_temp / df) + 32'hF00000; // 240 in Q16.16

  assign h_temp = (r_eq_mx) ? h_case1 : ((g_eq_mx) ? h_case2 : h_case3);
  assign h = (h_temp >= three_sixty) ? h_temp - three_sixty : h_temp;

  // Saturation calculation
  assign s_temp = (mx == 0) ? 0 : (df * hundred) / mx;
  assign s = s_temp;

  // Value calculation
  assign v_temp = (mx * hundred) >> 16; // Scale to Q16.16
  assign v = v_temp;

endmodule