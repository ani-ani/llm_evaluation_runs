module circumsphere_center(
  input signed [7:0] p1_x, p1_y, p1_z,
  input signed [7:0] p2_x, p2_y, p2_z,
  input signed [7:0] p3_x, p3_y, p3_z,
  input signed [7:0] p4_x, p4_y, p4_z,
  output [31:0] center_x,
  output [31:0] center_y,
  output [31:0] center_z
);

  // Convert inputs to Q16.16 format
  wire signed [31:0] p1_x_q = $signed({16'd0, p1_x}) << 16;
  wire signed [31:0] p1_y_q = $signed({16'd0, p1_y}) << 16;
  wire signed [31:0] p1_z_q = $signed({16'd0, p1_z}) << 16;
  wire signed [31:0] p2_x_q = $signed({16'd0, p2_x}) << 16;
  wire signed [31:0] p2_y_q = $signed({16'd0, p2_y}) << 16;
  wire signed [31:0] p2_z_q = $signed({16'd0, p2_z}) << 16;
  wire signed [31:0] p3_x_q = $signed({16'd0, p3_x}) << 16;
  wire signed [31:0] p3_y_q = $signed({16'd0, p3_y}) << 16;
  wire signed [31:0] p3_z_q = $signed({16'd0, p3_z}) << 16;
  wire signed [31:0] p4_x_q = $signed({16'd0, p4_x}) << 16;
  wire signed [31:0] p4_y_q = $signed({16'd0, p4_y}) << 16;
  wire signed [31:0] p4_z_q = $signed({16'd0, p4_z}) << 16;

  // Compute differences (Q16.16)
  wire signed [31:0] dx21 = p2_x_q - p1_x_q;
  wire signed [31:0] dy21 = p2_y_q - p1_y_q;
  wire signed [31:0] dz21 = p2_z_q - p1_z_q;
  wire signed [31:0] dx31 = p3_x_q - p1_x_q;
  wire signed [31:0] dy31 = p3_y_q - p1_y_q;
  wire signed [31:0] dz31 = p3_z_q - p1_z_q;
  wire signed [31:0] dx41 = p4_x_q - p1_x_q;
  wire signed [31:0] dy41 = p4_y_q - p1_y_q;
  wire signed [31:0] dz41 = p4_z_q - p1_z_q;

  // Compute right-hand side terms (Q16.16)
  wire signed [31:0] rhs2 = (p2_x_q * p2_x_q - p1_x_q * p1_x_q + p2_y_q * p2_y_q - p1_y_q * p1_y_q + p2_z_q * p2_z_q - p1_z_q * p1_z_q) >> 16;
  wire signed [31:0] rhs3 = (p3_x_q * p3_x_q - p1_x_q * p1_x_q + p3_y_q * p3_y_q - p1_y_q * p1_y_q + p3_z_q * p3_z_q - p1_z_q * p1_z_q) >> 16;
  wire signed [31:0] rhs4 = (p4_x_q * p4_x_q - p1_x_q * p1_x_q + p4_y_q * p4_y_q - p1_y_q * p1_y_q + p4_z_q * p4_z_q - p1_z_q * p1_z_q) >> 16;

  // Matrix A (3x3) elements
  wire signed [31:0] a11 = dx21;
  wire signed [31:0] a12 = dy21;
  wire signed [31:0] a13 = dz21;
  wire signed [31:0] a21 = dx31;
  wire signed [31:0] a22 = dy31;
  wire signed [31:0] a23 = dz31;
  wire signed [31:0] a31 = dx41;
  wire signed [31:0] a32 = dy41;
  wire signed [31:0] a33 = dz41;

  // Compute determinant of A (using 64-bit intermediates)
  wire signed [63:0] det_a = 
    $signed(a11) * ($signed(a22) * $signed(a33) - $signed(a23) * $signed(a32)) -
    $signed(a12) * ($signed(a21) * $signed(a33) - $signed(a23) * $signed(a31)) +
    $signed(a13) * ($signed(a21) * $signed(a32) - $signed(a22) * $signed(a31));

  // Compute determinants for Cramer's rule
  // Matrix A1 (replace first column with rhs)
  wire signed [63:0] det_a1 = 
    $signed(rhs2) * ($signed(a22) * $signed(a33) - $signed(a23) * $signed(a32)) -
    $signed(a12) * ($signed(rhs3) * $signed(a33) - $signed(a23) * $signed(rhs4)) +
    $signed(a13) * ($signed(rhs3) * $signed(a32) - $signed(a22) * $signed(rhs4));

  // Matrix A2 (replace second column with rhs)
  wire signed [63:0] det_a2 = 
    $signed(a11) * ($signed(rhs3) * $signed(a33) - $signed(a23) * $signed(rhs4)) -
    $signed(rhs2) * ($signed(a21) * $signed(a33) - $signed(a23) * $signed(a31)) +
    $signed(a13) * ($signed(a21) * $signed(rhs4) - $signed(rhs3) * $signed(a31));

  // Matrix A3 (replace third column with rhs)
  wire signed [63:0] det_a3 = 
    $signed(a11) * ($signed(a22) * $signed(rhs4) - $signed(rhs3) * $signed(a32)) -
    $signed(a12) * ($signed(a21) * $signed(rhs4) - $signed(rhs3) * $signed(a31)) +
    $signed(rhs2) * ($signed(a21) * $signed(a32) - $signed(a22) * $signed(a31));

  // Compute center coordinates using Cramer's rule
  // Handle division by scaling (Q16.16 / Q16.16 = Q16.16)
  wire signed [31:0] x_num = det_a1[63:32];
  wire signed [31:0] y_num = det_a2[63:32];
  wire signed [31:0] z_num = det_a3[63:32];
  wire signed [31:0] det_denom = det_a[63:32];

  // Fixed-point division (Q16.16 / Q16.16)
  // Using simple division (synthesis tools will handle this)
  assign center_x = (det_denom != 0) ? (x_num << 16) / det_denom : 32'd0;
  assign center_y = (det_denom != 0) ? (y_num << 16) / det_denom : 32'd0;
  assign center_z = (det_denom != 0) ? (z_num << 16) / det_denom : 32'd0;

endmodule