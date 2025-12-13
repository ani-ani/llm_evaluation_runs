module divisible_by_11(
  input  [15:0] n,
  output       is_divisible
);

  // Extract decimal digits using combinational arithmetic
  // Thousands and above
  wire [15:0] q10000 = n / 16'd10000;
  wire [15:0] r10000 = n - q10000 * 16'd10000;

  wire [15:0] q1000  = r10000 / 16'd1000;
  wire [15:0] r1000  = r10000 - q1000 * 16'd1000;

  wire [15:0] q100   = r1000 / 16'd100;
  wire [15:0] r100   = r1000 - q100 * 16'd100;

  wire [15:0] q10    = r100 / 16'd10;
  wire [15:0] q1     = r100 - q10 * 16'd10;

  // Digits d4 d3 d2 d1 d0 correspond to ten-thousands to ones
  wire [3:0] d4 = q10000[3:0];  // ten-thousands
  wire [3:0] d3 = q1000[3:0];   // thousands
  wire [3:0] d2 = q100[3:0];    // hundreds
  wire [3:0] d1 = q10[3:0];     // tens
  wire [3:0] d0 = q1[3:0];      // ones

  // Alternating sum: (d0 - d1 + d2 - d3 + d4)
  // Use signed to keep possible negative values
  wire signed [6:0] alt_sum = $signed({3'b000, d0})
                             - $signed({3'b000, d1})
                             + $signed({3'b000, d2})
                             - $signed({3'b000, d3})
                             + $signed({3'b000, d4});

  // Absolute value of alternated sum
  wire [6:0] abs_sum = alt_sum[6] ? (~alt_sum + 7'd1) : alt_sum;

  // Check divisibility by 11: sum % 11 == 0
  // Since abs_sum is small, implement via subtraction cascade
  wire [6:0] s1 = (abs_sum >= 7'd11) ? (abs_sum - 7'd11) : abs_sum;
  wire [6:0] s2 = (s1      >= 7'd11) ? (s1      - 7'd11) : s1;
  wire [6:0] s3 = (s2      >= 7'd11) ? (s2      - 7'd11) : s2;

  assign is_divisible = (s3 == 7'd0);

endmodule