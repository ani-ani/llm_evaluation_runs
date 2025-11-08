module TopModule(
  input clk,
  input enable,
  input S,
  input A,
  input B,
  input C,
  output Z
);
  reg [7:0] Q;  // Q[0] is MSB, Q[7] is LSB
  always @(posedge clk) begin
    if (enable) begin
      Q <= {S, Q[7:1]};
    end
  end
  assign Z = Q[{A, B, C}];
endmodule