module sum_digits_binary(input [13:0] N, output [5:0] sum_bin);
  wire [3:0] d4 = N / 14'd10000;
  wire [3:0] d3 = (N % 14'd10000) / 14'd1000;
  wire [3:0] d2 = (N % 14'd1000) / 14'd100;
  wire [3:0] d1 = (N % 14'd100) / 14'd10;
  wire [3:0] d0 = N % 14'd10;
  assign sum_bin = d4 + d3 + d2 + d1 + d0;
endmodule