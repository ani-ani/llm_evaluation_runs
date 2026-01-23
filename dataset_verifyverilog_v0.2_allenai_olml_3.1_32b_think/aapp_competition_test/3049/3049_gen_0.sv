module substitution_cipher_matcher (
input clk,
input rst_n,
input start,
input [127:0] encrypted_msg,
input [63:0] fragment,
input [4:0] msg_len,
input [3:0] frag_len,

output reg [127:0] result_string,
output reg [4:0] result_pos,
output reg [7:0] match_count,
output reg done
);

reg [2:0] state;
reg [3:0] current_pos;
reg [7:0] valid_positions_count;
reg [7:0] match_count;
reg [4:0] result_pos;
reg [127:0] result_string;
reg [4:0] captured_msg_len;
reg [3:0] captured_frag_len;
reg [2:0] current_char_index;
reg [5:0] mapping_forward [25:0];
reg [5:0] mapping_reverse [25:0];
reg valid_position;
reg [3:0] last_valid_pos;

always @(posedge clk) begin
if (!rst_n) begin
state <= 0;
current_pos <=0;
valid_positions_count <=0;
match_count <=0;
result_pos <=0;
result_string <=0;
captured_msg_len <=0;
captured_frag_len <=0;
current_char_index <=0;
mapping_forward <= {26{26}};
mapping_reverse <= {26{26}};
valid_position <=1;
last_valid_pos <=0;
end else begin
case(state)
0: 
if (start) state <=1;
else state <=0;
1: 
captured_msg_len <= msg_len;
captured_frag_len <= frag_len;
current_pos <=0;
valid_positions_count <=0;
match_count <=0;
result_pos <=0;
result_string <=0;
current_char_index <=0;
mapping_forward <= {26{26}};
mapping_reverse <= {26{26}};
valid_position <=1;
if (captured_msg_len < captured_frag_len) state <=4;
else state <=2;
2: 
if (current_pos < (captured_msg_len - captured_frag_len +1)) begin
state <=3;
current_char_index <=0;
valid_position <=1;
mapping_forward <= {26{26}};
mapping_reverse <= {26{26}};
end else state <=4;
3: 
if (current_char_index < captured_frag_len) begin
if (mapping_forward[fragment[current_char_index] - 'a'] !=26) begin
if (mapping_forward[fragment[current_char_index] - 'a'] != (encrypted_msg[current_pos + current_char_index] - 'a')) begin
valid_position <=0;
end
end else begin
mapping_forward[fragment[current_char_index] - 'a'] <= encrypted_msg[current_pos + current_char_index] - 'a';
end

if (mapping_reverse[encrypted_msg[current_pos + current_char_index] - 'a'] !=26) begin
if (mapping_reverse[encrypted_msg[current_pos + current_char_index] - 'a'] != (fragment[current_char_index] - 'a')) begin
valid_position <=0;
end
end else begin
mapping_reverse[encrypted_msg[current_pos + current_char_index] - 'a'] <= fragment[current_char_index] - 'a';
end

current_char_index <= current_char_index +1;
state <=3;
end else begin
if (valid_position) begin
valid_positions_count <= valid_positions_count +1;
if (valid_positions_count ==1) last_valid_pos <= current_pos;
end
current_pos <= current_pos +1;
if (current_pos < (captured_msg_len - captured_frag_len +1)) state <=2;
else state <=4;
end
4: 
match_count <= valid_positions_count;
result_pos <= (valid_positions_count ==1) ? last_valid_pos :0;
result_string <= {16{8'h20}};
state <=5;
5: 
done <=1;
state <=6;
6: 
state <=6;
default: state <=0;
endcase
end
endmodule