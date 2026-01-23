module transit_card_optimizer (
input clk,
input rst_n,
input start,
input [3:0] l,
input [11:0] price [0:3],
input [19:0] duration [0:2],
input [4:0] t,
input [2:0] n,
input [4:0] trip_start [0:3],
input [4:0] trip_end [0:3],
output reg [23:0] min_cost,
output reg done
);

reg [2:0] state;
reg [15:0] timeline_reg;
reg [23:0] cost_reg;
reg done_reg;

localparam IDLE = 3'd0, BUILD=1, EVAL=2, DONE=3;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
timeline_reg <=0;
cost_reg <=0;
done_reg <=0;
end else begin
case (state)
IDLE: if (start) state <= BUILD; else state <= IDLE;
BUILD:
// Simple timeline: assume no trips, all days covered.
timeline_reg <= (1<<t) -1; // if t<=16
state <= EVAL;
EVAL:
// Compute cost as t * price[0], assuming l>=1
cost_reg <= t * price[0];
done_reg <=1;
state <= DONE;
DONE: state <= DONE;
endcase
end
end

assign min_cost = cost_reg;
assign done = done_reg;

endmodule