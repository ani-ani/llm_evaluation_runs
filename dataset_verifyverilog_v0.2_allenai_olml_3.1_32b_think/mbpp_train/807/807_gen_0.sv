module first_odd_finder (input clk, input rst_n, input start, input [7:0] data_in, input [2:0] list_size, input valid_in, output reg [7:0] first_odd, output reg found, output reg done);
reg [1:0] state;
reg [2:0] count;
reg [2:0] captured_list_size;
reg [7:0] first_odd;
reg found;
reg done;
parameter IDLE = 2'b00
parameter PROCESSING = 2'b01
parameter CHECKING = 2'b10
parameter DONE = 2'b11;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
count <= 3'b000;
captured_list_size <= 3'b000;
first_odd <= 8'b00000000;
found <= 1'b0;
done <= 1'b0;
end
else begin
case (state)
IDLE: begin
if (start) begin
captured_list_size <= list_size;
count <= 3'b000;
state <= PROCESSING;
end
else begin
state <= IDLE;
end
end
PROCESSING: begin
if (valid_in) begin
state <= CHECKING;
end
else begin
state <= PROCESSING;
end
end
CHECKING: begin
if (data_in[0]) begin
first_odd <= data_in;
found <= 1'b1;
done <= 1'b1;
state <= DONE;
end
else begin
count <= count + 1;
if (count < captured_list_size) begin
state <= PROCESSING;
end
else begin
first_odd <= 8'hFF;
found <= 1'b0;
done <= 1'b1;
state <= DONE;
end
end
end
DONE: begin
state <= DONE;
end
endcase
end
end
endmodule