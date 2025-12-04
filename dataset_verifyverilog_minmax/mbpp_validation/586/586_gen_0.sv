module array_rotator(
  input [2:0] n,
  input logic [7:0] arr [0:7],
  output logic [7:0] result [0:7]
);

  genvar i;
  generate
    for (i = 0; i < 8; i++) begin
      assign result[i] = arr[(i + n) % 8];
    end
  endgenerate

endmodule
