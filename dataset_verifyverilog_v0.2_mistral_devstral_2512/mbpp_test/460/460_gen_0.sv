module ExtractFirst (
  input [7:0] sublists [0:3][0:7],
  output [7:0] first_elements [0:3]
);

  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : extract_loop
      assign first_elements[i] = sublists[i][0];
    end
  endgenerate

endmodule