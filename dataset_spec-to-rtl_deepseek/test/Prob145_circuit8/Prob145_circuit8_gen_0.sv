module TopModule(input clock, input a, output logic p, output logic q);
  always_ff @(posedge clock) begin
    p <= a;
  end

  always_ff @(negedge clock) begin
    q <= p;
  end
endmodule