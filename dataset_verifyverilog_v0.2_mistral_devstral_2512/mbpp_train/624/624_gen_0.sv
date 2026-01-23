module string_to_upper (
  input [7:0][7:0] input_string,
  output [7:0][7:0] result
);

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : char_loop
      assign result[i] = (input_string[i] >= 8'h61 && input_string[i] <= 8'h7A) ?
                         (input_string[i] & 8'hDF) :
                         input_string[i];
    end
  endgenerate

endmodule