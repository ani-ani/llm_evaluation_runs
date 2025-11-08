module TopModule(
  input clk,
  input reset,
  output [2:0] ena,
  output [15:0] q
);
  reg [3:0] d0, d1, d2, d3;
  assign q = {d3, d2, d1, d0};
  reg [2:0] ena_reg;
  assign ena = ena_reg;
  always @(posedge clk) begin
    if (reset) begin
      d0 <= 4'd0;
      d1 <= 4'd0;
      d2 <= 4'd0;
      d3 <= 4'd0;
      ena_reg <= 3'b000;
    end else begin
      logic carry0 = (d0 == 4'd9);
      logic [3:0] next_d0 = carry0 ? 4'd0 : d0 + 4'd1;
      logic [3:0] next_d1 = carry0 ? ((d1 == 4'd9) ? 4'd0 : d1 + 4'd1) : d1;
      logic carry1 = carry0 && (d1 == 4'd9);
      logic [3:0] next_d2 = carry1 ? ((d2 == 4'd9) ? 4'd0 : d2 + 4'd1) : d2;
      logic carry2 = carry1 && (d2 == 4'd9);
      logic [3:0] next_d3 = carry2 ? ((d3 == 4'd9) ? 4'd0 : d3 + 4'd1) : d3;
      d0 <= next_d0;
      d1 <= next_d1;
      d2 <= next_d2;
      d3 <= next_d3;
      ena_reg[0] <= carry0;
      ena_reg[1] <= carry1;
      ena_reg[2] <= carry2;
    end
  end
endmodule