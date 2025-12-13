module tuple_modulo #(
  parameter int N = 8
) (
  input  logic [7:0] tuple1 [0:N-1],
  input  logic [7:0] tuple2 [0:N-1],
  output logic [7:0] result [0:N-1]
);

  genvar i;
  generate
    for (i = 0; i < N; i++) begin : gen_mod
      // Combinational element-wise modulo; define behavior for divisor 0 as 0
      assign result[i] = (tuple2[i] != 8'd0) ? (tuple1[i] % tuple2[i]) : 8'd0;
    end
  endgenerate

endmodule