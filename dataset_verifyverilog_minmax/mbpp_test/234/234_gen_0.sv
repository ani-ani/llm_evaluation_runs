module cube_volume (
  input reg [3:0] side_length,
  output [14:0] volume
);
  assign volume = (side_length * side_length) * side_length;
endmodule