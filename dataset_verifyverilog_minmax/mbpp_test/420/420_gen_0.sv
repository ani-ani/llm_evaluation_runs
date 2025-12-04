module cube_sum (output [31:0] sum, input reg [7:0] n);
  // Calculate n*(n+1)
  wire [15:0] a = n * (n+1);
  // Divide by 2
  wire [15:0] b = a >> 1;
  // Square b
  wire [31:0] c = b * b;
  // Multiply by 8 (shift left by 3)
  assign sum = c << 3;
endmodule