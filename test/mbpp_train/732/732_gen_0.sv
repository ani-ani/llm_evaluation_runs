module char_replacer(
  input  [3:0]        str_len,
  input  [15:0][7:0]  in_str,
  output [15:0][7:0]  out_str
);

  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : gen_replace
      assign out_str[i] = (i < str_len) ?
                          ((in_str[i] == 8'h20 ||
                            in_str[i] == 8'h2C ||
                            in_str[i] == 8'h2E) ? 8'h3A : in_str[i]) :
                          8'h00;
    end
  endgenerate

endmodule