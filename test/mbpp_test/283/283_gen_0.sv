module digit_frequency_check(
  input  [15:0] num,
  output       valid
);

  // Extract digits (each 4-bit BCD)
  wire [3:0] d0 = num[3:0];
  wire [3:0] d1 = num[7:4];
  wire [3:0] d2 = num[11:8];
  wire [3:0] d3 = num[15:12];

  // Count occurrences of digits 0-4
  wire [2:0] cnt0 = (d0 == 4'd0) + (d1 == 4'd0) + (d2 == 4'd0) + (d3 == 4'd0);
  wire [2:0] cnt1 = (d0 == 4'd1) + (d1 == 4'd1) + (d2 == 4'd1) + (d3 == 4'd1);
  wire [2:0] cnt2 = (d0 == 4'd2) + (d1 == 4'd2) + (d2 == 4'd2) + (d3 == 4'd2);
  wire [2:0] cnt3 = (d0 == 4'd3) + (d1 == 4'd3) + (d2 == 4'd3) + (d3 == 4'd3);
  wire [2:0] cnt4 = (d0 == 4'd4) + (d1 == 4'd4) + (d2 == 4'd4) + (d3 == 4'd4);

  // Check constraints for digits 0-4
  wire ok0 = (cnt0 <= 3'd0);
  wire ok1 = (cnt1 <= 3'd1);
  wire ok2 = (cnt2 <= 3'd2);
  wire ok3 = (cnt3 <= 3'd3);
  wire ok4 = (cnt4 <= 3'd4);

  // Combine all checks
  assign valid = ok0 & ok1 & ok2 & ok3 & ok4;

endmodule