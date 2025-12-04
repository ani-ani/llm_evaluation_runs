module count_before_tuple (
  input  [3:0][7:0] elements,
  output [1:0]      count
);

  wire [1:0] tuple_idx;
  wire       found_tuple;

  assign found_tuple = elements[0][7] | elements[1][7] | elements[2][7] | elements[3][7];

  assign tuple_idx = elements[0][7] ? 2'd0 :
                     elements[1][7] ? 2'd1 :
                     elements[2][7] ? 2'd2 :
                     elements[3][7] ? 2'd3 :
                     2'd0; // default, unused when !found_tuple

  assign count = found_tuple ? tuple_idx : 2'd0; // If no tuple, output 0 (truncated 4 to 2 bits).

endmodule