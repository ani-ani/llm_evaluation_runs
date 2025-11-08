module TopModule(
  input clk,
  input x,
  output z
);
  
  reg qxor = 1'b0;
  reg qand = 1'b0;
  reg qor = 1'b0;
  
  wire dxor = x ^ qxor;
  wire dand = x & (~qand);
  wire dor = x | (~qor);
  
  always @(posedge clk) begin
    qxor <= dxor;
    qand <= dand;
    qor <= dor;
  end
  
  assign z = ~(qxor | qand | qor);
  
endmodule