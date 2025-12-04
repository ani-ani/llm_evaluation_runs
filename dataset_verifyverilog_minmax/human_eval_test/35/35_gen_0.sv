module max_element (
  input logic [7:0] values [0:7],
  output logic [7:0] max_value
);

  // Stage 0: compare adjacent pairs
  logic [7:0] mid0, mid1, mid2, mid3;
  assign mid0 = ($signed(values[0]) > $signed(values[1])) ? values[0] : values[1];
  assign mid1 = ($signed(values[2]) > $signed(values[3])) ? values[2] : values[3];
  assign mid2 = ($signed(values[4]) > $signed(values[5])) ? values[4] : values[5];
  assign mid3 = ($signed(values[6]) > $signed(values[7])) ? values[6] : values[7];

  // Stage 1: compare two intermediate results
  logic [7:0] mid4, mid5;
  assign mid4 = ($signed(mid0) > $signed(mid1)) ? mid0 : mid1;
  assign mid5 = ($signed(mid2) > $signed(mid3)) ? mid2 : mid3;

  // Stage 2: final maximum
  assign max_value = ($signed(mid4) > $signed(mid5)) ? mid4 : mid5;

endmodule