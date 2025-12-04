module vector_sum(
  input [31:0] arr1,
  input [31:0] arr2,
  output [31:0] result
);

  assign result = {(arr1[31:24] + arr2[31:24]),
                  (arr1[23:16] + arr2[23:16]),
                  (arr1[15:8] + arr2[15:8]),
                  (arr1[7:0] + arr2[7:0])};

endmodule