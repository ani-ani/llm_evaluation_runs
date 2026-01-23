module common_divisors_sum (
  input [15:0] a,
  input [15:0] b,
  output [15:0] sum
);

  wire [15:0] divisor_checks [15:0];
  integer i;

  // Check each divisor from 1 to 15
  genvar j;
  generate
    for (j = 1; j <= 15; j = j + 1) begin : divisor_loop
      assign divisor_checks[j] = (a % j == 0) && (b % j == 0) ? j : 0;
    end
  endgenerate

  // Sum all valid divisors
  assign sum = divisor_checks[1] + divisor_checks[2] + divisor_checks[3] + divisor_checks[4] + 
               divisor_checks[5] + divisor_checks[6] + divisor_checks[7] + divisor_checks[8] + 
               divisor_checks[9] + divisor_checks[10] + divisor_checks[11] + divisor_checks[12] + 
               divisor_checks[13] + divisor_checks[14] + divisor_checks[15];

endmodule