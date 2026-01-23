module pattern_matcher(
input clk,
input rst_n,
input start,
input [7:0][7:0] word_char,
input [7:0][7:0] pattern_char,
input [3:0] pattern_len,
input [3:0] word_len,
output reg match,
output reg done
);

// Registers
reg [2:0] state;
reg [7:0] word_char_reg [7:0];
reg [7:0] pattern_char_reg [7:0];
reg [3:0] pattern_len_reg;
reg [3:0] word_len_reg;
reg [2:0] star_pos;
reg [1:0] cycle_count;

// States
parameter IDLE = 3'd0,
LOAD = 3'd1,
FIND_STAR = 3'd2,
CHECK_LENGTH = 3'd3,
CHECK_PREFIX = 3'd4,
CHECK_SUFFIX = 3'd5,
MATCH_DONE = 3'd6,
NO_MATCH = 3'd7,
DONE_STATE = 3'd8;

// Outputs
reg match_reg;
reg done_reg;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
word_char_reg <= 8'b0;
pattern_char_reg <= 8'b0;
pattern_len_reg <= 4'd0;
word_len_reg <= 4'd0;
star_pos <= 2'd0;
cycle_count <= 2'd0;
match_reg <= 1'b0;
done_reg <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) state <= LOAD;
end
LOAD: begin
word_char_reg <= word_char;
pattern_char_reg <= pattern_char;
pattern_len_reg <= pattern_len;
word_len_reg <= word_len;
state <= FIND_STAR;
cycle_count <= 0;
end
FIND_STAR: begin
if (cycle_count < 8) begin
cycle_count <= cycle_count + 1;
integer current_index = cycle_count - 1;
if (current_index < pattern_len_reg && pattern_char_reg[current_index] == 8'h2A) begin
star_pos <= current_index;
end
if (cycle_count == 8) state <= CHECK_LENGTH;
end
end
CHECK_LENGTH: begin
integer min_len = star_pos + (pattern_len_reg - 1 - star_pos);
if (word_len_reg < min_len) begin
state <= NO_MATCH;
end else begin
state <= CHECK_PREFIX;
end
end
CHECK_PREFIX: begin
localparam MAX_PREFIX = 8;
wire prefix_match = 1;
generate
for (int i = 0; i < MAX_PREFIX; i++) begin: loop
if (i < star_pos) begin
if (word_char_reg[i] != pattern_char_reg[i]) begin
prefix_match = 0;
end
end
end
endgenerate
if (!prefix_match) begin
state <= NO_MATCH;
end else begin
state <= CHECK_SUFFIX;
end
end
CHECK_SUFFIX: begin
integer suffix_len = pattern_len_reg - 1 - star_pos;
integer start_word = word_len_reg - suffix_len;
wire suffix_match = 1;
generate
for (int i = 0; i < 8; i++) begin: loop
if (i < suffix_len) begin
if (word_char_reg[start_word + i] != pattern_char_reg[star_pos + 1 + i]) begin
suffix_match = 0;
end
end
end
endgenerate
if (!suffix_match) begin
state <= NO_MATCH;
end else begin
match_reg <= 1'b1;
state <= MATCH_DONE;
end
end
MATCH_DONE: begin
state <= DONE_STATE;
done_reg <= 1'b1;
match_reg <= 1'b1;
end
NO_MATCH: begin
match_reg <= 1'b0;
state <= DONE_STATE;
done_reg <= 1'b1;
end
DONE_STATE: begin
if (start) begin
state <= IDLE;
done_reg <= 1'b0;
end else begin
state <= DONE_STATE;
end
end
default: state <= IDLE;
endcase
end
// Outputs
match = match_reg;
done = done_reg;
endmodule