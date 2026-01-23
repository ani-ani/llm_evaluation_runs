module common_elements (
  input [3:0] l1 [0:7],
  input [3:0] l2 [0:7],
  input [3:0] l3 [0:7],
  output [3:0] result [0:7]
);

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : common_check
      assign result[i] = (l1[i] == l2[i] && l1[i] == l3[i]) ? l1[i] : 4'b0;
    end
  endgenerate

endmodule