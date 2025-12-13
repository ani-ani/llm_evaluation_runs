module list_increment(
  input  logic [7:0] l [7:0],
  output logic [7:0] result [7:0]
);

  genvar i;
  generate
    for (i = 0; i < 8; i++) begin : gen_inc
      assign result[i] = l[i] + 8'd1;
    end
  endgenerate

endmodule