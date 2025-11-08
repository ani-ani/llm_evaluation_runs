module TopModule(
  input clk,
  input x,
  output z
);
  logic Q1, Q2, Q3;
  
  initial begin
    Q1 = 0;
    Q2 = 0;
    Q3 = 0;
  end
  
  always_ff @(posedge clk) begin
    Q1 <= x ^ Q1;
    Q2 <= x & ~Q2;
    Q3 <= x | ~Q3;
  end
  
  assign z = !(Q1 | Q2 | Q3);
endmodule