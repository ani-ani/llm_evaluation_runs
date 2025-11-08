module TopModule(
  input reg d,
  input reg ena,
  output reg q
);

  always @(d, ena) begin
    if (ena) q <= d;
  end

endmodule