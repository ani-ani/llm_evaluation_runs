module top_n_prices(
  input  [127:0] item_prices, // Packed array of 4x32-bit prices: {p3,p2,p1,p0}
  input  [1:0]   n,          // Number of top prices to return (1-3)
  output [95:0]  top_prices  // {price2, price1, price0}
);

  // Extract individual prices
  wire [31:0] p0 = item_prices[31:0];
  wire [31:0] p1 = item_prices[63:32];
  wire [31:0] p2 = item_prices[95:64];
  wire [31:0] p3 = item_prices[127:96];

  // Stage 1: pairwise max/min
  wire [31:0] max01 = (p0 >= p1) ? p0 : p1;
  wire [31:0] min01 = (p0 >= p1) ? p1 : p0;

  wire [31:0] max23 = (p2 >= p3) ? p2 : p3;
  wire [31:0] min23 = (p2 >= p3) ? p3 : p2;

  // Stage 2: combine to get full sort (descending) via sorting network
  wire [31:0] maxA = (max01 >= max23) ? max01 : max23; // largest
  wire [31:0] midA = (max01 >= max23) ? max23 : max01;

  wire [31:0] maxB = (min01 >= min23) ? min01 : min23;
  wire [31:0] minB = (min01 >= min23) ? min23 : min01; // smallest

  // Final ordering among midA and maxB to ensure full sort
  wire [31:0] price0_full = maxA; // largest (descending)
  wire [31:0] price1_full = (midA >= maxB) ? midA : maxB;
  wire [31:0] price2_full = (midA >= maxB) ? maxB : midA;
  wire [31:0] price3_full = minB; // smallest

  // Select top n (1-3) in descending order, zero-padding unused
  wire [31:0] out0 = (n >= 2'd1) ? price0_full : 32'd0;
  wire [31:0] out1 = (n >= 2'd2) ? price1_full : 32'd0;
  wire [31:0] out2 = (n >= 2'd3) ? price2_full : 32'd0;

  assign top_prices = {out2, out1, out0};

endmodule