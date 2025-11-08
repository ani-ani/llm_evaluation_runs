module TopModule(
  input clk,
  input [7:0] in,
  output reg [7:0] pedge
);

  reg [7:0] prev_in = 8'b0;
  reg [7:0] trans = 8'b0;

  always @(posedge clk) begin
    trans <= ~prev_in & in;
    prev_in <= in;
    pedge <= trans;
  end

endmodule