module k_mfree_subset (
input clk,
input rst_n,
input start,
input [7:0] k,
input [2:0] n,
input [11:0] arr [0:7],
output reg [3:0] result,
output reg done
);
parameter IDLE = 2'd0,
SORT = 2'd1,
PROCESS = 2'd2,
DONE = 2'd3;
reg [1:0] state;
reg [7:0] captured_k;
reg [2:0] captured_n;
reg [11:0] captured_arr [7:0];
reg [2:0] sort_pass;
reg [2:0] sort_idx;
reg [2:0] process_idx;
reg [3:0] accum_result;
reg [7:0] selected_flags;
reg [11:0] temp;
reg temp_selected;
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
captured_k <= 0;
captured_n <= 0;
captured_arr <= 0;
sort_pass <= 0;
sort_idx <= 0;
process_idx <= 0;
accum_result <= 0;
selected_flags <= 0;
temp <= 0;
temp_selected <=0;
result <= 0;
done <= 0;
end else begin
if (state == IDLE) begin
if (start) begin
captured_k <= k;
captured_n <= n;
captured_arr <= arr;
state <= SORT;
end
end
else if (state == SORT) begin
if (sort_idx < captured_n - 1) begin
if (captured_arr[sort_idx] > captured_arr[sort_idx + 1]) begin
temp = captured_arr[sort_idx];
captured_arr[sort_idx] = captured_arr[sort_idx + 1];
captured_arr[sort_idx + 1] = temp;
end
sort_idx <= sort_idx + 1;
end else begin
if (sort_pass < 7) begin
sort_pass <= sort_pass + 1;
sort_idx <= 0;
end else begin
state <= PROCESS;
end
end
end
else if (state == PROCESS) begin
if (process_idx < captured_n) begin
temp_selected = 1;
if (process_idx > 0) begin
if (selected_flags[0] && (captured_arr[0] * captured_k == captured_arr[process_idx])) 
temp_selected = 0;
end
end
if (process_idx > 1) begin
if (selected_flags[1] && (captured_arr[1] * captured_k == captured_arr[process_idx])) 
temp_selected = 0;
end
end
if (process_idx > 2) begin
if (selected_flags[2] && (captured_arr[2] * captured_k == captured_arr[process_idx])) 
temp_selected = 0;
end
end
if (process_idx > 3) begin
if (selected_flags[3] && (captured_arr[3] * captured_k == captured_arr[process_idx])) 
temp_selected = 0;
end
end
if (process_idx > 4) begin
if (selected_flags[4] && (captured_arr[4] * captured_k == captured_arr[process_idx])) 
temp_selected = 0;
end
end
if (process_idx > 5) begin
if (selected_flags[5] && (captured_arr[5] * captured_k == captured_arr[process_idx])) 
temp_selected = 0;
end
end
if (process_idx > 6) begin
if (selected_flags[6] && (captured_arr[6] * captured_k == captured_arr[process_idx])) 
temp_selected = 0;
end
end
if (temp_selected) begin
selected_flags[process_idx] <= 1;
accum_result <= accum_result + 1;
end else begin
selected_flags[process_idx] <= 0;
end
process_idx <= process_idx + 1;
end else begin
state <= DONE;
result <= accum_result;
done <= 1;
end
end
else if (state == DONE) begin
done <= 1;
end
end
endmodule