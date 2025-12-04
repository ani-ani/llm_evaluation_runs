module substring_count(input [3:0] str_len, output [7:0] count);
  assign count = (str_len * (str_len + 4'b1)) >> 1;
endmodule