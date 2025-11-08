module TopModule(input clk, enable, S, A, B, C, output Z);
  reg [7:0] Q;
  always_ff @(posedge clk) begin
    if (enable) Q <= {Q[6:0], S};
  end
  assign Z = Q[{A, B, C}];
endmodule