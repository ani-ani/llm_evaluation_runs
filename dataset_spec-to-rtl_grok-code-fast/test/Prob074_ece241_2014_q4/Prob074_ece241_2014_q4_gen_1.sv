module TopModule(
  input clk,
  input x,
  output z
);
  reg ff0 = 1'b0;
  reg ff1 = 1'b0;
  reg ff2 = 1'b0;

  always @(posedge clk) begin
    ff0 <= x ^ ff0;
    ff1 <= x & (~ff1);
    ff2 <= x | (~ff2);
  end

  assign z = ~(ff0 | ff1 | ff2);
endmodule