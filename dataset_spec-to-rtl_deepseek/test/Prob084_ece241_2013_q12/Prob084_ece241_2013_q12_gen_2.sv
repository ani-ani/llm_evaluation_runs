module TopModule(input clk, input enable, input S, input A, input B, input C, output Z);
  reg [7:0] q_reg;
  
  always @(posedge clk) begin
    if (enable) begin
      q_reg <= {q_reg[6:0], S};
    end
  end
  
  assign Z = q_reg[{A,B,C}];
endmodule