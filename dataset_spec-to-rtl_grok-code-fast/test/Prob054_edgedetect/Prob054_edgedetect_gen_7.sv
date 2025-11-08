module TopModule (
  input clk,
  input [7:0] in,
  output [7:0] pedge
);
  reg [7:0] prev;
  reg [7:0] edge_detect;
  reg [7:0] pedge_reg;
  always @(posedge clk) begin
    edge_detect <= in & ~prev;
    prev <= in;
    pedge_reg <= edge_detect;
  end
  assign pedge = pedge_reg;
endmodule