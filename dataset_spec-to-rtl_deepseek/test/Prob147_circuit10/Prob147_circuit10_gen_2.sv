module TopModule(input clk, input a, input b, output q, output state);
  reg st = 1'b0;
  always @(posedge clk) begin
    st <= st ^ (a ~^ b);
  end
  assign state = st;
  assign q = st ? ~(a ^ b) : (a ^ b);
endmodule