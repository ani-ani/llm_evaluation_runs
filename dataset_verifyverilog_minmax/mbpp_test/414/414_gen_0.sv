module overlapping_checker(
  input [7:0][3:0] list1,
  input [7:0][3:0] list2,
  output reg overlap
);
  genvar i, j;
  wire [7:0][7:0] cmp;

  generate
    for (i = 0; i < 8; i = i + 1) begin : cmp_row
      for (j = 0; j < 8; j = j + 1) begin : cmp_col
        assign cmp[i][j] = (list1[i] == list2[j]);
      end
    end
  endgenerate

  assign overlap = |cmp;
endmodule