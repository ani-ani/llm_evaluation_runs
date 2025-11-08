module TopModule(input clk, input x, output z);
  reg q1 = 1'b0;
  reg q2 = 1'b0;
  reg q3 = 1'b0;
  
  wire d1, d2, d3;
  
  assign d1 = x ^ q1;
  assign d2 = x & (~q2);
  assign d3 = x | (~q3);
  
  always @(posedge clk) begin
    q1 <= d1;
    q2 <= d2;
    q3 <= d3;
  end
  
  assign z = ~(q1 | q2 | q3);
endmodule