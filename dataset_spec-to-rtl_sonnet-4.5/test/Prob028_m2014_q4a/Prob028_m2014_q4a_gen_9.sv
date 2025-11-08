module TopModule(
  input  d,
  input  ena,
  output q
);

  reg q_reg;

  always @(*) begin
    if (ena)
      q_reg = d;
  end

  assign q = q_reg;

endmodule