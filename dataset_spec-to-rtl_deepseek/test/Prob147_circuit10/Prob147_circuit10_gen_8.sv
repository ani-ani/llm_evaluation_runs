module TopModule(input clk, a, b, output q, state);
  reg state_reg = 1'b0;
  
  always @(posedge clk) begin
  
    end
  
  assign state = state_reg;
  assign q = (a & b) ? state_reg : (a | b);
endmodule