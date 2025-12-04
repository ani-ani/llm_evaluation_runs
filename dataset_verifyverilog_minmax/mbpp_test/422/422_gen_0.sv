module average_of_cubes(
  input [3:0] n,
  output reg [31:0] average_q16_16
);

  always @(*) begin
    // Compute: ((n * (n+1) * (n+1)) << 14) in 16.16 fixed-point format
    // This is equivalent to (n*(n+1)^2/4) * 65536
    average_q16_16 = (n * (n+1) * (n+1)) << 14;
  end

endmodule