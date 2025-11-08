module TopModule(input clk, enable, S, A, B, C, output Z);
  reg [7:0] q;

  always @(posedge clk) begin
    if (enable) begin
      q <= {S, q[7:1]};
    end
  end

  assign Z = q[{A,B,C}];
endmodule