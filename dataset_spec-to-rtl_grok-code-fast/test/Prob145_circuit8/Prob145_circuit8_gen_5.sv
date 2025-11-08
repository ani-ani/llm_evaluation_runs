module TopModule(input clock, input a, output reg p, output reg q);
  always @(clock or a) begin
    if (clock) p = a;
  end
  always @(negedge clock) q <= p;
endmodule