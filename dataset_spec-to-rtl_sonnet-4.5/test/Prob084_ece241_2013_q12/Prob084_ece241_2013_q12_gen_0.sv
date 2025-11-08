module TopModule(
  input clk,
  input enable,
  input S,
  input A,
  input B,
  input C,
  output Z
);

  reg [7:0] Q;
  wire [2:0] addr;

  // 8-bit shift register
  always @(posedge clk) begin
    if (enable) begin
      Q[7:1] <= Q[6:0];
      Q[0] <= S;
    end
  end

  // Address for multiplexer
  assign addr = {C, B, A};

  // 8-to-1 multiplexer
  assign Z = Q[addr];

endmodule