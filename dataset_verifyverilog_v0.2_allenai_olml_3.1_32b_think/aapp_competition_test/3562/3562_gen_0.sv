module grade_optimizer (
input clk,
input rst_n,
input start,
input [3:0] num_subjects,
input [7:0] total_time,
input [31:0] params_a [0:9],
input [31:0] params_b [0:9],
input [31:0] params_c [0:9],
output reg [31:0] avg_grade,
output reg done
);

reg [2:0] state;
reg [31:0] t [0:9];
reg [31:0] total_allocated;
reg [31:0] iteration_count;
localparam IDLE=3'd0, CALC_DERIV=3'd1, ALLOCATE=3'd2, CHECK_DONE=3'd3, DONE=3'd4;
initial begin
state<=IDLE; t<=0; total_allocated<=0; iteration_count<=0; done<=0; avg_grade<=0;
end

always @(posedge clk) begin
if (!rst_n) begin
state<=IDLE; t<=0; total_allocated<=0; iteration_count<=0; done<=0; avg_grade<=0;
end else begin
case(state)
IDLE: if (start && num_subjects>0 && num_subjects<4'd10 && total_time>0) state<=CALC_DERIV;
CALC_DERIV: begin
// compute derivatives, allocate, etc.
// placeholder:
t[0] <= t[0]+32'd0x000028F6;
total_allocated <= total_allocated +32'd0x000028F6;
iteration_count <= iteration_count +1;
if (iteration_count >=24000) state<=CHECK_DONE;
end
CHECK_DONE: begin
// compute average
avg_grade <= 32'd0;
if (total_allocated >= total_time) state<=DONE;
end
DONE: state<=DONE;
default: state<=IDLE;
endcase
end
end
endmodule