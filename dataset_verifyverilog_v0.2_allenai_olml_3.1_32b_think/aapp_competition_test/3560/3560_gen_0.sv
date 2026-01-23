module barbarian_substring_matcher (
input clk,
input rst_n,
input start,
input [2:0] operation_type,
input [2:0] barbarian_id,
input [63:0] string_input,
input [2:0] string_length,
output reg [15:0] result,
output reg done,
output reg valid
);

reg [7:0] patterns [7:0];
reg [2:0] pattern_lengths [7:0];
reg [15:0] counters [7:0];
reg [2:0] state;
reg [3:0] load_idx;
reg [2:0] last_operation;

always @(negedge rst_n) begin
if (!rst_n) begin
patterns <= 0;
pattern_lengths <=0;
counters <=0;
state <= 0;
load_idx <=0;
last_operation <=0;
end
end

always @(posedge clk) begin
if (!rst_n) begin
done <=0;
result <=0;
valid <=0;
end else begin
done <=0;
result <=0;
valid <=0;
case (state)
IDLE: begin
if (start ==1) begin
if (operation_type ==0) state <=1;
else if (operation_type ==1) state <=2;
else if (operation_type ==2) state <=3;
end
end
LOAD_PATTERN: begin
if (load_idx <8) begin
patterns[load_idx] <= string_input[load_idx*8 +7 : load_idx*8];
pattern_lengths[load_idx] <=1;
load_idx <= load_idx +1;
end else begin
load_idx <=8;
state <=0;
end
end
PROCESS_TYPE1: begin
integer i, j;
for (i=0; i<8; i++) begin
integer match_found =0;
for (j=0; j<string_length; j++) begin
integer char_j = string_input[j*8 +7 : j*8];
if (char_j == patterns[i]) begin
match_found =1;
break;
end
end
if (match_found ==1) begin
counters[i] <= counters[i] +1;
end
end
state <=4;
last_operation <=2;
end
PROCESS_TYPE2: begin
integer barbarian_idx;
barbarian_idx = barbarian_id -1;
if (barbarian_idx <0) barbarian_idx =0;
if (barbarian_idx >7) barbarian_idx =7;
result <= counters[barbarian_idx];
state <=4;
last_operation <=3;
end
DONE: begin
state <=0;
done <=1;
valid <= (last_operation ==3) ? 1 :0;
end
endcase
end
endmodule