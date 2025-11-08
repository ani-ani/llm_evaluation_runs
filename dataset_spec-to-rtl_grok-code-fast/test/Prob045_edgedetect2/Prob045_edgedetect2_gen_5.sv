module TopModule(
  input clk,
  input [7:0] in,
  output [7:0] anyedge
);
  reg [7:0] prev_in;
  reg [7:0] change_detected;
  reg [7:0] anyedge_reg;

  assign anyedge = anyedge_reg;

  always @(posedge clk) begin
    change_detected <= in ^ prev_in;
    prev_in <= in;
  end

  always @(posedge clk) begin
    anyedge_reg <= change_detected;
  end
endmodule