module card_score_optimizer (
input clk,
 input rst_n, // active low
 input start,
 input [3:0] a_in,
 input [3:0] b_in,
 output reg [15:0] max_score,
 output reg done
);

localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE_STATE = 2'd2;

reg [1:0] state_reg;
reg [15:0] score;
reg [3:0] counter;
reg [3:0] a_val, b_val;
reg done_reg;

function integer calc_score;
 input integer A, B;
 integer o_blocks, m, q, r, sum_x;
 if (A == 0) o_blocks = 0;
 else o_blocks = 1;
 m = o_blocks + 1;
 if (B == 0) sum_x = 0;
 else begin
 q = B / m;
 r = B % m;
 sum_x = r * (q + 1) * (q + 1) + (m - r) * q * q;
 end
 calc_score = (A * A) - sum_x;
endfunction

always @(posedge clk) begin
 if (!rst_n) begin
 state_reg <= IDLE;
 done_reg <= 0;
 a_val <= 0;
 b_val <= 0;
 score <= 0;
 counter <= 0;
 end else begin
 if (state_reg == IDLE) begin
 if (start) begin
 a_val <= a_in;
 b_val <= b_in;
 state_reg <= PROCESSING;
 counter <= 10; // 10 cycle delay
 end
 end else if (state_reg == PROCESSING) begin
 if (counter > 0) begin
 counter <= counter - 1;
 end else begin
 state_reg <= DONE_STATE;
 done_reg <= 1;
 end
 score <= calc_score(a_val, b_val);
 end else if (state_reg == DONE_STATE) begin
 // stay in done state
 end
 end
end

assign max_score = score;
assign done = done_reg;
endmodule