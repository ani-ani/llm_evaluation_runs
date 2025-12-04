module tuple_concat(
  input  [23:0] elem1,
  input  [23:0] elem2,
  input  [23:0] elem3,
  input  [23:0] elem4,
  output [119:0] result
);

  // Extract bytes for each element (big-endian order)
  wire [7:0] e1_b0 = elem1[23:16];
  wire [7:0] e1_b1 = elem1[15:8];
  wire [7:0] e1_b2 = elem1[7:0];

  wire [7:0] e2_b0 = elem2[23:16];
  wire [7:0] e2_b1 = elem2[15:8];
  wire [7:0] e2_b2 = elem2[7:0];

  wire [7:0] e3_b0 = elem3[23:16];
  wire [7:0] e3_b1 = elem3[15:8];
  wire [7:0] e3_b2 = elem3[7:0];

  wire [7:0] e4_b0 = elem4[23:16];
  wire [7:0] e4_b1 = elem4[15:8];
  wire [7:0] e4_b2 = elem4[7:0];

  // Delimiter '-'
  localparam [7:0] DASH = 8'h2D;

  // Concatenate into final 15-byte (120-bit) result
  assign result = {
    e1_b0, e1_b1, e1_b2,
    DASH,
    e2_b0, e2_b1, e2_b2,
    DASH,
    e3_b0, e3_b1, e3_b2,
    DASH,
    e4_b0, e4_b1, e4_b2
  };

endmodule