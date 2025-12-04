module cube_volume(
  input  [3:0]  side_length,
  output [14:0] volume
);

  wire [7:0] square;

  assign square = side_length * side_length;
  assign volume = square * side_length;

endmodule