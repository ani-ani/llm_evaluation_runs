module octagonal_number (
  input [7:0] n,
  output [17:0] oct_num
);

  wire [15:0] n_squared = n * n;
  wire [8:0] two_n = 2 * n;
  wire [17:0] three_n_squared = 3 * n_squared;

  assign oct_num = three_n_squared - {9'b0, two_n};

endmodule