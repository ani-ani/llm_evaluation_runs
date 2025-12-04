module find_min (
  input  [7:0] numbers [0:7],
  input  [2:0] count,
  output [7:0] min_num
);

  wire [7:0] eff0 = (count > 3'd0) ? numbers[0] : 8'hFF;
  wire [7:0] eff1 = (count > 3'd1) ? numbers[1] : 8'hFF;
  wire [7:0] eff2 = (count > 3'd2) ? numbers[2] : 8'hFF;
  wire [7:0] eff3 = (count > 3'd3) ? numbers[3] : 8'hFF;
  wire [7:0] eff4 = (count > 3'd4) ? numbers[4] : 8'hFF;
  wire [7:0] eff5 = (count > 3'd5) ? numbers[5] : 8'hFF;
  wire [7:0] eff6 = (count > 3'd6) ? numbers[6] : 8'hFF;
  wire [7:0] eff7 = (count > 3'd7) ? numbers[7] : 8'hFF;

  // Level 1 comparisons
  wire [7:0] l1_0 = (eff0 < eff1) ? eff0 : eff1;
  wire [7:0] l1_1 = (eff2 < eff3) ? eff2 : eff3;
  wire [7:0] l1_2 = (eff4 < eff5) ? eff4 : eff5;
  wire [7:0] l1_3 = (eff6 < eff7) ? eff6 : eff7;

  // Level 2 comparisons
  wire [7:0] l2_0 = (l1_0 < l1_1) ? l1_0 : l1_1;
  wire [7:0] l2_1 = (l1_2 < l1_3) ? l1_2 : l1_3;

  // Level 3 comparison
  wire [7:0] l3_0 = (l2_0 < l2_1) ? l2_0 : l2_1;

  assign min_num = (count == 3'd0) ? 8'hFF : l3_0;

endmodule