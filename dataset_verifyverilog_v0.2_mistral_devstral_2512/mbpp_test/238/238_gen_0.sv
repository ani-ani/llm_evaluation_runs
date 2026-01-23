module substring_counter (
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  output [7:0] result
);

  wire [2:0] n;
  wire [7:0] n_plus_1;
  wire [8:0] product;

  // Detect string length n (0-8)
  assign n = (char_0 != 0) + 
             (char_1 != 0) + 
             (char_2 != 0) + 
             (char_3 != 0) + 
             (char_4 != 0) + 
             (char_5 != 0) + 
             (char_6 != 0) + 
             (char_7 != 0);

  // Compute n+1
  assign n_plus_1 = n + 1;

  // Compute n*(n+1)
  assign product = n * n_plus_1;

  // Compute result = n*(n+1)/2
  assign result = product >> 1;

endmodule