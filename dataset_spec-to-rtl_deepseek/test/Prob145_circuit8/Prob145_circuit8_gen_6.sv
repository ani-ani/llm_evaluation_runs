module TopModule(input clock, input a, output p, output q);
  reg q_reg;
  
  assign p = clock & a;
  
  always @(negedge clock) begin
    q_reg <= p;
  end
  
  assign q = q_reg;
endmodule