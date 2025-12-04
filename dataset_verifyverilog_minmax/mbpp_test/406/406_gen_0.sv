module parity_checker (
  input [7:0] x,
  output logic odd_parity
);
  logic [7:0] y;
  y = x ^ (x >> 1);
  y = y ^ (y >> 2);
  y = y ^ (y >> 4);
  odd_parity = y[0];
endmodule