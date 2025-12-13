module perimeter_pentagon(
  input  [7:0]  a,
  output [10:0] perimeter
);

  assign perimeter = (a << 2) + a; // 5 * a = 4*a + a

endmodule