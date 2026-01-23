module sublist_histogram (input clk,input rst_n,input start,input [2:0] num_sublists,input [2:0] sublist_lengths [0:7],input [7:0] sublists [0:7][0:7],output reg [2:0] output_index,output reg [7:0] unique_list,output reg [2:0] list_length,output reg [7:0] count,output reg output_valid,output reg done);
localparam IDLE = 3'd0;
localparam PROCESS = 3'd1;
localparam OUTPUT = 3'd2;
localparam DONE_STATE = 3'd3;
reg [2:0] state;
reg [2:0] input_idx;
reg [2:0] unique_cnt;
reg [7:0] unique_data [0:7];
reg [2:0] unique_len [0:7];
reg [7:0] unique_count [0:7];
reg [0:0] unique_valid [0:7];
reg [2:0] output_idx;
reg [7:0] current_unique;
reg [2:0] current_len;
reg [7:0] current_count;
reg [2:0] reset_flag;
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
input_idx <= 3'b0;
unique_cnt <= 3'b0;
output_idx <= 3'b0;
output_index <= 3'b0;
list_length <= 3'b0;
count <= 8'b0;
output_valid <= 1'b0;
done <= 1'b0;
reset_flag <= 3'b0;
for (int i=0; i<8; i++) begin
unique_data[i] <= 8'b0;
unique_len[i] <= 3'b0;
unique_count[i] <= 8'b0;
unique_valid[i] <= 1'b0;
end
end else if (reset_flag) begin
state <= PROCESS;
input_idx <= 3'b0;
unique_cnt <= 3'b0;
for (int i=0; i<8; i++) begin
unique_data[i] <= 8'b0;
unique_len[i] <= 3'b0;
unique_count[i] <= 8'b0;
unique_valid[i] <= 1'b0;
end
reset_flag <= 3'b0;
end else begin
if (state == IDLE) begin
if (start) begin
reset_flag <= 3'b1;
state <= PROCESS;
end
end
end
end
always @(*) begin
if (state == PROCESS) begin
if (input_idx < num_sublists) begin
int current_len = sublist_lengths[input_idx];
[7:0] current_first = sublists[input_idx][0];
int found = 0;
int match_idx = -1;
for (int i=0; i<unique_cnt; i++) begin
if (unique_valid[i] && unique_len[i] == current_len && unique_data[i][0] == current_first) begin
found = 1;
match_idx = i;
break;
end
end
if (found) begin
unique_count[match_idx] <= unique_count[match_idx] + 1;
end else begin
if (unique_cnt < 8) begin
unique_data[unique_cnt] <= {8{{sublists[input_idx][0]}}};
unique_len[unique_cnt] <= current_len;
unique_count[unique_cnt] <= 1;
unique_valid[unique_cnt] <= 1;
unique_cnt <= unique_cnt + 1;
end
end
input_idx <= input_idx + 1;
end else begin
state <= OUTPUT;
input_idx <= 8'd0;
end
end else if (state == OUTPUT) begin
if (output_idx < unique_cnt) begin
output_idx <= output_idx + 1;
current_unique <= unique_data[output_idx - 1][0];
current_len <= unique_len[output_idx - 1];
current_count <= unique_count[output_idx - 1];
output_valid <= 1'b1;
done <= 1'b0;
end else begin
state <= DONE_STATE;
output_valid <= 1'b0;
done <= 1'b1;
end
end
end
assign output_index = output_idx;
assign unique_list = current_unique;
assign list_length = current_len;
assign count = current_count;
endmodule