module common_element(
  input  [7:0][7:0] list1,
  input  [7:0]      list1_valid,
  input  [7:0][7:0] list2,
  input  [7:0]      list2_valid,
  output            result
);

  wire [63:0] match_matrix;
  wire [63:0] valid_matrix;

  genvar i, j;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_list1
      for (j = 0; j < 8; j = j + 1) begin : gen_list2
        assign match_matrix[i*8 + j] = (list1[i] == list2[j]);
        assign valid_matrix[i*8 + j] = list1_valid[i] & list2_valid[j];
      end
    end
  endgenerate

  assign result = |(match_matrix & valid_matrix);

endmodule