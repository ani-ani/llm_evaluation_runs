module tarot_knight_solver (
input clk,
input rst_n,
input start,
input [7:0] card_r [0:3],
input [7:0] card_c [0:3],
input [7:0] card_a [0:3],
input [7:0] card_b [0:3],
input [7:0] card_p [0:3],
output reg [15:0] min_cost,
output reg done
);

reg [15:0] min_cost_reg;
reg done_reg;

always @(posedge clk) begin
  if (!rst_n) begin
    min_cost_reg <= 0xFFFF;
    done_reg <= 0;
  end
end

assign min_cost = min_cost_reg;
assign done = done_reg;

endmodule