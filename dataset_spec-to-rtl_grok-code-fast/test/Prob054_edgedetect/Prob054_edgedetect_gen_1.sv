module TopModule(
  input clk,
  input [7:0] in,
  output reg [7:0] pedge
);

  reg [7:0] prev, edge_detect;

  always @(posedge clk) begin
    prev <= in;
    edge_detect <= in & ~prev;
    pedge <= edge_detect;
  end

endmodule