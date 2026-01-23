module toggle_middle_bits (
  input [7:0] n,
  output [7:0] result
);
  
  wire [7:0] mask = n | (n >> 1);
  wire [7:0] mask2 = mask | (mask >> 2);
  wire [7:0] mask3 = mask2 | (mask2 >> 4);
  wire [7:0] middle = (mask3 >> 1) ^ 1;
  wire [7:0] result = n ^ middle;
  
  assign result = result;
  
endmodule