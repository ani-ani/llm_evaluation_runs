module substring_count(
  input  [3:0] str_len,
  output [7:0] count
);

  wire [4:0] len_plus_1;
  wire [8:0] mult_result;

  assign len_plus_1  = str_len + 4'd1;
  assign mult_result = str_len * len_plus_1;
  assign count       = mult_result[8:1];

endmodule