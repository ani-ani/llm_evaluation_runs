module substring_count(
  input  [3:0] str_len,
  output [7:0] count
);
  // count = (str_len * (str_len + 1)) / 2
  assign count = (str_len * (str_len + 1)) >> 1;
endmodule
