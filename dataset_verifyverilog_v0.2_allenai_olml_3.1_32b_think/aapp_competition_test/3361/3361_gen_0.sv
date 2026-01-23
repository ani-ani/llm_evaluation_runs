module ore_partitioner (input clk, input rst_n, input start, input valid_in, input [11:0] dist_in, input [3:0] row_idx, input [3:0] col_idx, output reg [11:0] result, output reg done);
localparam FIFO_DEPTH = 120;
reg [19:0] data_fifo [FIFO_DEPTH-1:0];
reg [7:0] writeptr, readptr;
reg [7:0] fifo_count;
reg [19:0] sort_array [FIFO_DEPTH-1:0];
reg [7:0] sort_index;
reg [3:0] node_group [15:0];
reg [11:0] max_A, max_B;
reg [2:0] state;
reg was_start;
always @(posedge clk) begin
if (!rst_n) begin
state <= 3'b000;
was_start <= 1'b0;
writeptr <= 0;
readptr <= 0;
fifo_count <= 0;
sort_index <= 0;
node_group <= 16'b0;
max_A <= 12'b0;
max_B <= 12'b0;
done <= 1'b0;
end else begin
done <= 1'b0;
case(state)
3'b000: begin
if (start == 1'b1 && was_start == 1'b0) begin
state <= 3'b001;
was_start <= 1'b1;
end
end
3'b001: begin
state <= 3'b010;
end
3'b010: begin
if (fifo_count > 0) begin
sort_array[sort_index] <= data_fifo[readptr];
readptr <= readptr + 1;
sort_index <= sort_index + 1;
fifo_count <= fifo_count - 1;
end else begin
state <= 3'b011;
end
end
3'b011: begin
static reg [7:0] proc_cnt;
if (proc_cnt == 0) begin
proc_cnt <= 8;
end else begin
proc_cnt <= proc_cnt - 1;
if (proc_cnt == 0) begin
state <= 3'b100;
end
end
end
3'b100: begin
result <= 12'b0;
done <= 1'b1;
end
endcase
// Handle FIFO write in all states
if (valid_in) begin
if (writeptr < FIFO_DEPTH) begin
data_fifo[writeptr] <= {dist_in, row_idx, col_idx};
writeptr <= writeptr + 1;
fifo_count <= fifo_count + 1;
end
end
end
end
endmodule