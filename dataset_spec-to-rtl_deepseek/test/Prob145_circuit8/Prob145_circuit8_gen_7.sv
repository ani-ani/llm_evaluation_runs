module TopModule(input clock, a, output reg p = 0, output reg q = 0);
  always @(posedge clock) p <= a;
  always @(negedge clock) q <= p;
endmodule