module undulating_check (
  input  [31:0] num,
  output        is_undulating
);

  wire [3:0] d0 = num[31:28];
  wire [3:0] d1 = num[27:24];
  wire [3:0] d2 = num[23:20];
  wire [3:0] d3 = num[19:16];
  wire [3:0] d4 = num[15:12];
  wire [3:0] d5 = num[11:8];
  wire [3:0] d6 = num[7:4];
  wire [3:0] d7 = num[3:0];

  assign is_undulating =
       (d0 == d2) & (d0 == d4) & (d0 == d6) &
       (d1 == d3) & (d1 == d5) & (d1 == d7) &
       (d0 != d1);

endmodule