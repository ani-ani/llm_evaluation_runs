module TopModule(input clock, a, output reg p, output reg q);
  always_latch begin
    if (clock) p = a;
  end

  always_ff @(negedge clock) begin
    q <= p;
  end
endmodule