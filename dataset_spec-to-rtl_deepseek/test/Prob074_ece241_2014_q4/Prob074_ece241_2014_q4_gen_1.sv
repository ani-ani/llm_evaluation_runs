module TopModule(input clk, input x, output z);
  logic q_xor = 1'b0, q_and = 1'b0, q_or = 1'b0;
  logic xor_out, and_out, or_out;
  
  assign xor_out = x ^ q_xor;
  assign and_out = x & ~q_and;
  assign or_out = x | ~q_or;
  
  always_ff @(posedge clk) begin
    q_xor <= xor_out;
    q_and <= and_out;
    q_or <= or_out;
  end
  
  assign z = ~(q_xor | q_and | q_or);
endmodule