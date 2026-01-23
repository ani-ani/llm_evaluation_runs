module add_even_at_odd_indices (
  input [7:0] arr [0:7],
  output [15:0] result
);

  wire [7:0] even_elements_at_odd_indices [0:3];
  wire [15:0] sum;

  assign even_elements_at_odd_indices[0] = (arr[1][0] == 0) ? arr[1] : 0;
  assign even_elements_at_odd_indices[1] = (arr[3][0] == 0) ? arr[3] : 0;
  assign even_elements_at_odd_indices[2] = (arr[5][0] == 0) ? arr[5] : 0;
  assign even_elements_at_odd_indices[3] = (arr[7][0] == 0) ? arr[7] : 0;

  assign sum = even_elements_at_odd_indices[0] + even_elements_at_odd_indices[1] + even_elements_at_odd_indices[2] + even_elements_at_odd_indices[3];

  assign result = sum;

endmodule