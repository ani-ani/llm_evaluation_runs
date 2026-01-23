module replace_blank (
  input [127:0] str_in,
  input [7:0] char_in,
  output [127:0] str_out
);

  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : byte_loop
      assign str_out[(i+1)*8-1 : i*8] = (str_in[(i+1)*8-1 : i*8] == 8'h20) ? char_in : str_in[(i+1)*8-1 : i*8];
    end
  endgenerate

endmodule