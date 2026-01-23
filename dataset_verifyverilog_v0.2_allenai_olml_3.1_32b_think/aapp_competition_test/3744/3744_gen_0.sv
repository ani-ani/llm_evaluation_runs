module team_selection (input clk, input rst_n, input start, input [2:0] n, input [2:0] p, input [2:0] s, input [7:0] a [0:7], input [7:0] b [0:7], output reg [15:0] max_strength, output reg [2:0] prog_indices [0:7], output reg [2:0] sports_indices [0:7], output reg done);
reg [7:0] n_val, p_val, s_val;
reg [7:0] a_reg [0:7], b_reg [0:7];
reg [7:0] prog_mask_candidate;
reg [7:0] current_prog_mask;
reg [7:0] sports_mask_candidate;
reg [7:0] current_sports_mask;
reg [15:0] max_strength_reg;
reg [2:0] prog_indices_reg [0:7];
reg [2:0] sports_indices_reg [0:7];
reg [2:0] state;
reg done_reg;
localparam IDLE = 3'b000;
localparam PREPARE = 3'b001;
localparam FIND_NEXT_PROG = 3'b010;
localparam PROCESS_SPORTS = 3'b011;
localparam EVALUATE = 3'b100;
localparam DONE_STATE = 3'b111;
function int count_bits;
input [7:0] x;
int count;
count = x[0] + x[1] + x[2] + x[3] + x[4] + x[5] + x[6] + x[7];
return count;
endfunction
always_ff @(posedge clk)
if (!rst_n) begin
n_val <= 3'b000;
p_val <= 3'b000;
s_val <= 3'b000;
a_reg <= 8'd0;
b_reg <= 8'd0;
prog_mask_candidate <= 8'd0;
current_prog_mask <= 8'd0;
sports_mask_candidate <= 8'd0;
current_sports_mask <= 8'd0;
max_strength_reg <= 16'd0;
prog_indices_reg <= 8'd0;
sports_indices_reg <= 8'd0;
state <= IDLE;
done_reg <= 1'b0;
end else begin
 case (state)
IDLE: 
if (start) begin
n_val <= n;
p_val <= p;
s_val <= s;
a_reg <= a;
b_reg <= b;
state <= PREPARE;
end
else begin
state <= IDLE;
end
PREPARE: 
state <= FIND_NEXT_PROG;
FIND_NEXT_PROG: 
prog_mask_candidate <= prog_mask_candidate + 1;
if (prog_mask_candidate < (1 << n_val)) begin
if (count_bits(prog_mask_candidate) == p_val) begin
current_prog_mask <= prog_mask_candidate;
sports_mask_candidate <= 8'd0;
state <= PROCESS_SPORTS;
end
end else begin
state <= DONE_STATE;
end
PROCESS_SPORTS: 
sports_mask_candidate <= sports_mask_candidate + 1;
int available_mask = ~current_prog_mask & ((1 << n_val) - 1);
if (sports_mask_candidate > available_mask) begin
state <= FIND_NEXT_PROG;
end else if (((sports_mask_candidate & available_mask) == sports_mask_candidate) && (count_bits(sports_mask_candidate) == s_val)) begin
current_sports_mask <= sports_mask_candidate;
state <= EVALUATE;
end else begin
state <= PROCESS_SPORTS;
end
EVALUATE: 
int total = 0;
if (n_val > 0) begin
if (current_prog_mask & 1) total += a_reg[0];
if (current_sports_mask & 1) total += b_reg[0];
end
if (n_val > 1) begin
if (current_prog_mask & 2) total += a_reg[1];
if (current_sports_mask & 2) total += b_reg[1];
end
if (n_val > 2) begin
if (current_prog_mask & 4) total += a_reg[2];
if (current_sports_mask & 4) total += b_reg[2];
end
if (n_val > 3) begin
if (current_prog_mask & 8) total += a_reg[3];
if (current_sports_mask & 8) total += b_reg[3];
end
if (n_val > 4) begin
if (current_prog_mask & 16) total += a_reg[4];
if (current_sports_mask & 16) total += b_reg[4];
end
if (n_val > 5) begin
if (current_prog_mask & 32) total += a_reg[5];
if (current_sports_mask & 32) total += b_reg[5];
end
if (n_val > 6) begin
if (current_prog_mask & 64) total += a_reg[6];
if (current_sports_mask & 64) total += b_reg[6];
end
if (n_val > 7) begin
if (current_prog_mask & 128) total += a_reg[7];
if (current_sports_mask & 128) total += b_reg[7];
end
if (total > max_strength_reg) begin
max_strength_reg <= total;
if (current_prog_mask & 1) prog_indices_reg[0] = 0; else prog_indices_reg[0] = 3'b000;
if (current_prog_mask & 2) prog_indices_reg[1] = 1; else prog_indices_reg[1] = 3'b000;
if (current_prog_mask & 4) prog_indices_reg[2] = 2; else prog_indices_reg[2] = 3'b000;
if (current_prog_mask & 8) prog_indices_reg[3] = 3; else prog_indices_reg[3] = 3'b000;
if (current_prog_mask & 16) prog_indices_reg[4] = 4; else prog_indices_reg[4] = 3'b000;
if (current_prog_mask & 32) prog_indices_reg[5] = 5; else prog_indices_reg[5] = 3'b000;
if (current_prog_mask & 64) prog_indices_reg[6] = 6; else prog_indices_reg[6] = 3'b000;
if (current_prog_mask & 128) prog_indices_reg[7] = 7; else prog_indices_reg[7] = 3'b000;
if (current_sports_mask & 1) sports_indices_reg[0] = 0; else sports_indices_reg[0] = 3'b000;
if (current_sports_mask & 2) sports_indices_reg[1] = 1; else sports_indices_reg[1] = 3'b000;
if (current_sports_mask & 4) sports_indices_reg[2] = 2; else sports_indices_reg[2] = 3'b000;
if (current_sports_mask & 8) sports_indices_reg[3] = 3; else sports_indices_reg[3] = 3'b000;
if (current_sports_mask & 16) sports_indices_reg[4] = 4; else sports_indices_reg[4] = 3'b000;
if (current_sports_mask & 32) sports_indices_reg[5] = 5; else sports_indices_reg[5] = 3'b000;
if (current_sports_mask & 64) sports_indices_reg[6] = 6; else sports_indices_reg[6] = 3'b000;
if (current_sports_mask & 128) sports_indices_reg[7] = 7; else sports_indices_reg[7] = 3'b000;
end
state <= PROCESS_SPORTS;
DONE_STATE:
done_reg <= 1'b1;
state <= DONE_STATE;
endcase
end
assign max_strength = max_strength_reg;
assign prog_indices = prog_indices_reg;
assign sports_indices = sports_indices_reg;
assign done = done_reg;
endmodule