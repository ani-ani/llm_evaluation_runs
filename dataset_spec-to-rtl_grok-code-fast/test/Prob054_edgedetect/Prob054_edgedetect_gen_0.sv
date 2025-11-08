module TopModule(
  input logic clk,
  input logic [7:0] in,
  output logic [7:0] pedge
);
  logic [7:0] prev_in;
  logic [7:0] pedge_reg;

  initial begin
    prev_in = 8'b0;
    pedge_reg = 8'b0;
  end

  always @(posedge clk) begin
    pedge_reg <= (~prev_in) & in;
    prev_in <= in;
    pedge <= pedge_reg;
  end
endmodule