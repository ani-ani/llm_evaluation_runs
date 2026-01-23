module interleave_lists (input clk, input rst_n, input start, input [7:0] list1_data, input [7:0] list2_data, input [7:0] list3_data, input list1_valid, input list2_valid, input list3_valid, output reg [7:0] result, output reg result_valid, output reg done, output reg [2:0] rd_en);
parameter LIST_LEN = 8;
localparam IDLE = 3'b000;
localparam READ_LIST1 = 3'b001;
localparam READ_LIST2 = 3'b010;
localparam READ_LIST3 = 3'b011;
localparam DONE_STATE = 3'b100;
reg [2:0] state;
reg [2:0] i;
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
i <= 0;
result <= 8'b0;
result_valid <= 1'b0;
done <= 1'b0;
end
else begin
case (state)
IDLE: begin
if (start) state <= READ_LIST1;
end
READ_LIST1: begin
if (list1_valid) begin
result <= list1_data;
result_valid <= 1'b1;
state <= READ_LIST2;
end
end
READ_LIST2: begin
if (list2_valid) begin
result <= list2_data;
result_valid <= 1'b1;
state <= READ_LIST3;
end
end
READ_LIST3: begin
if (list3_valid) begin
result <= list3_data;
result_valid <= 1'b1;
i <= i + 1;
if (i == LIST_LEN) begin
state <= DONE_STATE;
done <= 1'b1;
end
else begin
state <= READ_LIST1;
end
end
end
DONE_STATE: begin
done <= 1'b1;
result <= 8'b0;
result_valid <= 1'b0;
end
endcase
end
end
assign rd_en = state == READ_LIST1 ? 3'b001 : state == READ_LIST2 ? 3'b010 : state == READ_LIST3 ? 3'b100 : 3'b000;
endmodule