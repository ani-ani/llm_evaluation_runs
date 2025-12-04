module toggle_middle_bits (input [7:0] n, output [7:0] result);
  logic [7:0] set_mask;
  logic [7:0] mask;
  assign set_mask = n | (n >> 1) | (n >> 2) | (n >> 3) | (n >> 4) | (n >> 5) | (n >> 6) | (n >> 7);
  assign mask = (set_mask >> 1) ^ 8'h01;
  assign result = (n == 8'h0 || n == 8'h1) ? n : (n ^ mask);
endmodule