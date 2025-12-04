module min_hetero_list(
  input  [5:0] elem_0,
  input  [5:0] elem_1,
  input  [5:0] elem_2,
  input  [5:0] elem_3,
  input  [5:0] elem_4,
  input  [5:0] elem_5,
  input  [5:0] elem_6,
  input  [5:0] elem_7,
  input  [7:0] validity_mask,
  output [5:0] min_val
);

  wire [5:0] v0 = validity_mask[0] ? elem_0 : 6'h3F;
  wire [5:0] v1 = validity_mask[1] ? elem_1 : 6'h3F;
  wire [5:0] v2 = validity_mask[2] ? elem_2 : 6'h3F;
  wire [5:0] v3 = validity_mask[3] ? elem_3 : 6'h3F;
  wire [5:0] v4 = validity_mask[4] ? elem_4 : 6'h3F;
  wire [5:0] v5 = validity_mask[5] ? elem_5 : 6'h3F;
  wire [5:0] v6 = validity_mask[6] ? elem_6 : 6'h3F;
  wire [5:0] v7 = validity_mask[7] ? elem_7 : 6'h3F;

  wire any_valid = |validity_mask;

  wire [5:0] m0 = (v0 < v1) ? v0 : v1;
  wire [5:0] m1 = (v2 < v3) ? v2 : v3;
  wire [5:0] m2 = (v4 < v5) ? v4 : v5;
  wire [5:0] m3 = (v6 < v7) ? v6 : v7;

  wire [5:0] m4 = (m0 < m1) ? m0 : m1;
  wire [5:0] m5 = (m2 < m3) ? m2 : m3;

  wire [5:0] m6 = (m4 < m5) ? m4 : m5;

  assign min_val = any_valid ? m6 : 6'd0;

endmodule