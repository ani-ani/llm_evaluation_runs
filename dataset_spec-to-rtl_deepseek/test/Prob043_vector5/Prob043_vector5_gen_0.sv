module TopModule(
  input a, b, c, d, e,
  output [24:0] out
);

wire [0:4] inp_array;
assign inp_array = {a, b, c, d, e};

genvar i, j;
generate
  for (i = 0; i <= 4; i = i + 1) begin : i_loop
    for (j = 0; j <= 4; j = j + 1) begin : j_loop
      assign out[24 - (5 * i + j)] = (inp_array[i] == inp_array[j]);
    end
  end
endgenerate

endmodule