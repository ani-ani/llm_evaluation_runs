module flatten_unique (input clk, input rst_n, input start, input [2:0][7:0] tuple_0, input [2:0][7:0] tuple_1, input [2:0][7:0] tuple_2, output reg [7:0] result_data, output reg [2:0] result_count, output reg done);
function automatic int is_element_unique;
input [7:0] element;
input [7:0] buf_arr [9];
input [2:0] buf_s;
begin
for (int i=0; i<buf_s; i++) begin
if (element == buf_arr[i]) begin
return 0;
end
end
return 1;
endfunction
reg [2:0] state;
reg [1:0] el_index;
reg [7:0] unique_buf [9];
reg [2:0] buf_size;
reg [7:0] result_data;
reg [2:0] result_count;
reg done;
parameter IDLE = 3'b000;
parameter CHECK_TUPLE0 = 3'b001;
parameter CHECK_TUPLE1 = 3'b010;
parameter CHECK_TUPLE2 = 3'b011;
parameter DONE_STATE = 3'b100;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state = IDLE;
el_index = 0;
buf_size = 0;
result_data = 8'b0;
result_count = 3'b0;
done = 0;
end else begin
case (state)
IDLE: begin
if (start) begin
state = CHECK_TUPLE0;
el_index = 0;
end
end
CHECK_TUPLE0: begin
int current_element;
current_element = tuple_0[el_index][7:0];
int is_unique = is_element_unique(current_element, unique_buf, buf_size);
if (is_unique) begin
unique_buf[buf_size] = current_element;
buf_size = buf_size + 1;
result_data = current_element;
result_count = buf_size;
end
if (el_index < 2) begin
el_index = el_index + 1;
end else begin
state = CHECK_TUPLE1;
el_index = 0;
end
end
CHECK_TUPLE1: begin
int current_element;
current_element = tuple_1[el_index][7:0];
int is_unique = is_element_unique(current_element, unique_buf, buf_size);
if (is_unique) begin
unique_buf[buf_size] = current_element;
buf_size = buf_size + 1;
result_data = current_element;
result_count = buf_size;
end
if (el_index < 2) begin
el_index = el_index + 1;
end else begin
state = CHECK_TUPLE2;
el_index = 0;
end
end
CHECK_TUPLE2: begin
int current_element;
current_element = tuple_2[el_index][7:0];
int is_unique = is_element_unique(current_element, unique_buf, buf_size);
if (is_unique) begin
unique_buf[buf_size] = current_element;
buf_size = buf_size + 1;
result_data = current_element;
result_count = buf_size;
end
if (el_index < 2) begin
el_index = el_index + 1;
end else begin
state = DONE_STATE;
done = 1;
end
end
DONE_STATE: begin
// No action
endcase
endcase
end
endmodule