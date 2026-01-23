module array_splitter (input clk, input rst_n, input start, input [15:0][7:0] data_in, input [4:0] L, output reg [15:0][7:0] part1, output reg [15:0][7:0] part2, output reg done);
parameter SIZE = 16;
parameter WIDTH = 8;
localparam IDLE = 3'd0, LOAD=1, PROCESS=2, DONE=3;
reg [2:0] state;
reg [15:0][7:0] data_reg;
reg [4:0] L_reg;
reg [15:0][7:0] part1_reg, part2_reg;
reg [3:0] process_counter;
reg [15:0][7:0] part1_out, part2_out;
reg done;
function [15:0][7:0] compute_part1;
input [15:0][7:0] data;
input [4:0] split;
int i, j;
begin
for (i=0; i < SIZE; i=i+1) begin
for (j=0; j < WIDTH; j=j+1) begin
if (i < split) begin
compute_part1[i][j] = data[i][j];
end else begin
compute_part1[i][j] = 8'b0;
end
end
end
end
endfunction
function [15:0][7:0] compute_part2;
input [15:0][7:0] data;
input [4:0] split;
int i, j;
begin
for (i=0; i < SIZE; i=i+1) begin
for (j=0; j < WIDTH; j=j+1) begin
if (i >= split) begin
compute_part2[i][j] = data[i][j];
end else begin
compute_part2[i][j] = 8'b0;
end
end
end
end
endfunction
always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
data_reg <= 16'd0;
L_reg <= 4'd0;
part1_reg <= 16'd0;
part2_reg <= 16'd0;
process_counter <= 4'd0;
part1_out <= 16'd0;
part2_out <= 16'd0;
done <= 1'b0;
end else begin
case (state)
IDLE: begin
if (start) begin
state <= LOAD;
end
end
LOAD: begin
data_reg <= data_in;
L_reg <= L;
part1_reg <= compute_part1(data_reg, L_reg);
part2_reg <= compute_part2(data_reg, L_reg);
state <= PROCESS;
process_counter <= 15;
end
PROCESS: begin
if (process_counter == 4'd0) begin
state <= DONE;
done <= 1'b1;
part1_out <= part1_reg;
part2_out <= part2_reg;
end else begin
process_counter <= process_counter - 1;
state <= PROCESS;
end
end
DONE: begin
state <= DONE;
done <= 1'b1;
part1_out <= part1_reg;
part2_out <= part2_reg;
end
default: state <= IDLE;
endcase
end
end
assign part1 = part1_out;
assign part2 = part2_out;
assign done = done;
endmodule