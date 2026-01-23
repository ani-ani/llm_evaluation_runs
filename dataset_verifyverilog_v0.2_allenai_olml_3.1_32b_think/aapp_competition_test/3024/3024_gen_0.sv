module palindrome_partition (input clk,input rst_n,input start,input [7:0][7:0] str_data,input [3:0] str_len,output reg [3:0] max_k,output reg done);
reg [1:0] state;
reg [3:0] left_idx;
reg [3:0] right_idx;
reg [3:0] current_i;
reg [3:0] k_count;
reg done_flag;
localparam IDLE = 2'b00, CHECK_MATCH = 2'b01, UPDATE = 2'b10, DONE = 2'b11;
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
left_idx <= 4'd0;
right_idx <= 4'd0;
current_i <= 4'd0;
k_count <= 4'd0;
done_flag <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
left_idx <= str_len - 4'd1;
right_idx <= str_len - 4'd1;
current_i <= 4'd1;
k_count <= 4'd0;
state <= CHECK_MATCH;
end
else begin
state <= IDLE;
end
end
CHECK_MATCH: begin
integer L;
L = right_idx - left_idx + 1;
bit valid_match;
valid_match = 1'b0;
case (current_i)
4'd1: valid_match = (str_data[left_idx][7:0] == str_data[right_idx][7:0]);
4'd2: valid_match = (str_data[left_idx][7:0] == str_data[right_idx][7:0] && str_data[left_idx+1][7:0] == str_data[right_idx-1][7:0]);
4'd3: valid_match = (str_data[left_idx][7:0] == str_data[right_idx][7:0] && str_data[left_idx+1][7:0] == str_data[right_idx-1][7:0] && str_data[left_idx+2][7:0] == str_data[right_idx-2][7:0]);
4'd4: valid_match = (str_data[left_idx][7:0] == str_data[right_idx][7:0] && str_data[left_idx+1][7:0] == str_data[right_idx-1][7:0] && str_data[left_idx+2][7:0] == str_data[right_idx-2][7:0] && str_data[left_idx+3][7:0] == str_data[right_idx-3][7:0]);
4'd5: valid_match = (str_data[left_idx][7:0] == str_data[right_idx][7:0] && str_data[left_idx+1][7:0] == str_data[right_idx-1][7:0] && str_data[left_idx+2][7:0] == str_data[right_idx-2][7:0] && str_data[left_idx+3][7:0] == str_data[right_idx-3][7:0] && str_data[left_idx+4][7:0] == str_data[right_idx-4][7:0]);
4'd6: valid_match = (str_data[left_idx][7:0] == str_data[right_idx][7:0] && str_data[left_idx+1][7:0] == str_data[right_idx-1][7:0] && str_data[left_idx+2][7:0] == str_data[right_idx-2][7:0] && str_data[left_idx+3][7:0] == str_data[right_idx-3][7:0] && str_data[left_idx+4][7:0] == str_data[right_idx-4][7:0] && str_data[left_idx+5][7:0] == str_data[right_idx-5][7:0]);
4'd7: valid_match = (str_data[left_idx][7:0] == str_data[right_idx][7:0] && str_data[left_idx+1][7:0] == str_data[right_idx-1][7:0] && str_data[left_idx+2][7:0] == str_data[right_idx-2][7:0] && str_data[left_idx+3][7:0] == str_data[right_idx-3][7:0] && str_data[left_idx+4][7:0] == str_data[right_idx-4][7:0] && str_data[left_idx+5][7:0] == str_data[right_idx-5][7:0] && str_data[left_idx+6][7:0] == str_data[right_idx-6][7:0]);
4'd8: valid_match = (str_data[left_idx][7:0] == str_data[right_idx][7:0] && str_data[left_idx+1][7:0] == str_data[right_idx-1][7:0] && str_data[left_idx+2][7:0] == str_data[right_idx-2][7:0] && str_data[left_idx+3][7:0] == str_data[right_idx-3][7:0] && str_data[left_idx+4][7:0] == str_data[right_idx-4][7:0] && str_data[left_idx+5][7:0] == str_data[right_idx-5][7:0] && str_data[left_idx+6][7:0] == str_data[right_idx-6][7:0] && str_data[left_idx+7][7:0] == str_data[right_idx-7][7:0]);
default: valid_match = 1'b0;
endcase

if (current_i > L) begin
current_i <= L;
valid_match = 1'b1;
state <= UPDATE;
end else if (valid_match) begin
state <= UPDATE;
end else begin
if (current_i < L) begin
current_i <= current_i + 1;
state <= CHECK_MATCH;
end else begin
state <= UPDATE;
end
end
end
UPDATE: begin
left_idx <= left_idx + current_i;
right_idx <= right_idx - current_i;
k_count <= k_count + 1;
if (left_idx > right_idx || k_count >= 4'd8) begin
state <= DONE;
done_flag <= 1'b1;
end else begin
current_i <= 4'd1;
state <= CHECK_MATCH;
end
end
DONE: begin
state <= DONE;
done_flag <= 1'b1;
end
default: state <= IDLE;
endcase
end
max_k <= k_count;
done <= done_flag;
end
endmodule