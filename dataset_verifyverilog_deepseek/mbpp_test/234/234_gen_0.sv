module cube_volume (
  input [3:0] side_length,
  output logic [14:0] volume
);

  assign volume = side_length * side_length * side_length;

endmodule