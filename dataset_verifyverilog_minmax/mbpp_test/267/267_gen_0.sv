module square_sum(input [4:0] n, output [15:0] sum);
  // Intermediate signals to prevent overflow
  wire [9:0] n_squared;        // n*n (max 961, fits in 10 bits)
  wire [11:0] four_n_squared;  // 4*n*n (max 3844, fits in 12 bits)
  wire [11:0] numerator_term;  // 4*n*n - 1 (max 3843)
  wire [16:0] numerator;       // n * (4*n*n - 1) (max 119133, needs 17 bits)
  
  // Compute n*n
  assign n_squared = n * n;
  
  // Compute 4*n*n
  assign four_n_squared = {n_squared, 2'b00};
  
  // Compute (4*n*n - 1)
  assign numerator_term = four_n_squared - 1;
  
  // Compute n * (4*n*n - 1)
  assign numerator = n * numerator_term;
  
  // Divide by 3 and output as 16-bit (truncates remainder)
  assign sum = numerator / 3;
endmodule