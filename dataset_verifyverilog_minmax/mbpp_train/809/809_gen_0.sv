module tuple_comparator (
  input reg [7:0] t1 [3:0],
  input reg [7:0] t2 [3:0],
  output reg result
);

  wire [3:0] comp;

  assign comp = { (t1[0] > t2[0]), (t1[1] > t2[1]), (t1[2] > t2[2]), (t1[3] > t2[3]) };
  assign result = &comp;

endmodule