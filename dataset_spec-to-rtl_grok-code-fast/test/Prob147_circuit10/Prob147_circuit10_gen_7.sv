module TopModule(
  input clk,
  input a,
  input b,
  output reg state,
  output q
);
  assign q = a ^ b ^ state;
  always @(posedge clk) begin
    if (a == b) begin
      state <= ~state;
    end
    // else state <= state;  // remains the same
  end
endmodule