module TopModule(
  input [3:0] x,
  input [3:0] y,
  output [4:0] sum
);

  wire [3:0] c;
  wire [3:0] s;

  // Full adder for bit 0
  assign s[0] = x[0] ^ y[0];
  assign c[0] = x[0] & y[0];

  // Full adder for bit 1
  assign s[1] = x[1] ^ y[1] ^ c[0];
  assign c[1] = (x[1] & y[1]) | (x[1] & c[0]) | (y[1] & c[0]);

  // Full adder for bit 2
  assign s[2] = x[2] ^ y[2] ^ c[1];
  assign c[2] = (x[2] & y[2]) | (x[2] & c[1]) | (y[2] & c[1]);

  // Full adder for bit 3
  assign s[3] = x[3] ^ y[3] ^ c[2];
  assign c[3] = (x[3] & y[3]) | (x[3] & c[2]) | (y[3] & c[2]);

  // Assign sum with overflow bit
  assign sum = {c[3], s};

endmodule