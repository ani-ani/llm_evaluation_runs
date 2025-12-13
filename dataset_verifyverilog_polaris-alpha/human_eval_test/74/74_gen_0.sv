module list_char_compare(
  input  [63:0] lst1,
  input  [63:0] lst2,
  output [7:0]  total1,
  output [7:0]  total2,
  output        list_sel
);

  // Internal extended-width wires for accurate summation
  wire [10:0] sum1;
  wire [10:0] sum2;

  assign sum1 = lst1[63:56] + lst1[55:48] + lst1[47:40] + lst1[39:32] +
                lst1[31:24] + lst1[23:16] + lst1[15:8]  + lst1[7:0];

  assign sum2 = lst2[63:56] + lst2[55:48] + lst2[47:40] + lst2[39:32] +
                lst2[31:24] + lst2[23:16] + lst2[15:8]  + lst2[7:0];

  // Truncate to 8 bits for outputs (safe given max 128)
  assign total1 = sum1[7:0];
  assign total2 = sum2[7:0];

  // Select list2 only if its total is strictly smaller
  assign list_sel = (sum2 < sum1) ? 1'b1 : 1'b0;

endmodule