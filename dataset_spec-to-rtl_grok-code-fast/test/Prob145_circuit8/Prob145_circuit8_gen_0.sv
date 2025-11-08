module TopModule(
  input clock,
  input a,
  output reg p,
  output reg q
);
  always_latch begin
    if (clock) p <= a;
  end
  always_ff @(negedge clock) q <= p;
endmodule