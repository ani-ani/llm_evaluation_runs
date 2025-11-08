module TopModule(input clk, input enable, input S, input A, input B, input C, output Z);
  reg [0:7] q_reg;

  always @(posedge clk) begin
    if (enable) begin
      q_reg <= {S, q_reg[0:6]};
    end
  end

  assign Z = q_reg[{A,B,C}];
endmodule