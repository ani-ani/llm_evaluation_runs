module tuple_modulo #(
  parameter N = 8
) (
  input [7:0] tuple1 [0:N-1],
  input [7:0] tuple2 [0:N-1],
  output [7:0] result [0:N-1]
);

  genvar i;
  generate
    for (i = 0; i < N; i++) begin : elementwise_modulo
      assign result[i] = tuple1[i] % tuple2[i];
    end
  endgenerate

endmodule