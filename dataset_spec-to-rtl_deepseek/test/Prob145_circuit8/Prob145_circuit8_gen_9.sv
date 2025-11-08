module TopModule(input clock, a, output reg p, q);

  always @(posedge clock) begin
    p <= a;
  end

  always @(negedge clock) begin
    q <= p;
  end

endmodule