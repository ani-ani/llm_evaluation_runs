module replace_char (
  input [7:0][7:0] str_in,
  input [7:0] ch,
  input [7:0] newch,
  output [7:0][7:0] str_out
);

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : char_replace
      assign str_out[i] = (str_in[i] == ch) ? newch : str_in[i];
    end
  endgenerate

endmodule