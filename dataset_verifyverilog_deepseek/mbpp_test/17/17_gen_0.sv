module square_perimeter (
  input [7:0] a,
  output [9:0] perimeter
);
  assign perimeter = a * 4;
endmodule