module kth_sequence (
input clk,
input rst_n,
input start,
input [31:0] k,
output reg [3:0] result,
output reg valid,
output reg done
);
localparam IDLE = 2'b00;
localparam COUNTING = 2'b01;
localparam CHECKING = 2'b10;
localparam OUTPUT_STATE = 2'b11;
reg [1:0] state;
reg [2:0] seq [3:0];
reg [31:0] valid_count;
reg [2:0] saved_seq [3:0];
reg [1:0] element_index;
reg first_sequence;
reg [2:0] current_element;
reg done_flag;
function automatic bit is_valid;
input [2:0] seq [3:0];
begin
int i, j;
int sum;
for (i=0; i<4; i++) begin
sum = 0;
for (j=i; j<4; j++) begin
sum += seq[j];
if (sum % 5 == 0) return 0;
end
end
return 1;
endfunction
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
seq <= {4{3'b001}};
valid_count <= 0;
saved_seq <= {4{3'b001}};
element_index <= 0;
first_sequence <= 1'b1;
done_flag <= 0;
end else begin
if (state == IDLE) begin
if (start) begin
state <= COUNTING;
first_sequence <= 0;
end
end else if (state == COUNTING) begin
if (first_sequence) begin
state <= CHECKING;
first_sequence <= 0;
end else begin
int i;
for (i=3; i>=0; i--) begin
if (seq[i] < 4) begin
seq[i] = seq[i] + 1;
break;
end else begin
seq[i] = 1;
end
end
state <= CHECKING;
end
end else if (state == CHECKING) begin
if (is_valid(seq)) begin
valid_count <= valid_count + 1;
if (valid_count == k) begin
saved_seq <= seq;
state <= OUTPUT_STATE;
element_index <= 0;
end else begin
state <= COUNTING;
end
end else begin
state <= COUNTING;
end
end else if (state == OUTPUT_STATE) begin
if (element_index < 4) begin
current_element <= saved_seq[element_index];
result <= {3'b0, current_element};
valid <= 1;
element_index <= element_index + 1;
end else begin
valid <= 0;
done_flag <= 1;
end
end
end
end
assign done = done_flag;
endmodule