module armstrong_checker (
input clk,
input rst_n,
input start,
input [9:0] number,
output reg result,
output done
);

reg [9:0] original_num;
reg [9:0] working_num;
reg [9:0] sum;
reg [3:0] digit_count;
reg [3:0] current_digit;

reg [4:0] state;

localparam IDLE = 3'd0;
localparam COUNT_DIGITS = 3'd1;
localparam EXTRACT_DIGITS = 3'd2;
localparam CHECK_RESULT = 3'd3;
localparam DONE = 3'd4;

always @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
original_num <= 0;
working_num <= 0;
sum <= 0;
digit_count <= 0;
current_digit <= 0;
result <= 0;
done <= 0;
end else begin
case(state)
IDLE: begin
if (start) begin
original_num <= number;
working_num <= number;
digit_count <= 0;
current_digit <= 0;
sum <= 0;
state <= COUNT_DIGITS;
end
done <= 0;
result <= 0;
end

COUNT_DIGITS: begin
if (original_num >= 100) begin
digit_count <= 3;
current_digit <= 3;
state <= EXTRACT_DIGITS;
done <= 0;
result <= 0;
end else if (original_num >= 10) begin
digit_count <= 2;
state <= CHECK_RESULT;
done <= 0;
result <= 0;
end else begin
digit_count <= 1;
state <= CHECK_RESULT;
done <= 0;
result <= 0;
end
end

EXTRACT_DIGITS: begin
if (current_digit == 0) begin
state <= CHECK_RESULT;
done <= 0;
result <= 0;
end else begin
sum <= sum + ((working_num & 9) * (working_num & 9) * (working_num & 9));
working_num <= working_num / 10;
current_digit <= current_digit - 1;
done <= 0;
result <= 0;
end
end

CHECK_RESULT: begin
result <= (digit_count == 3 && sum == original_num) ? 1'b1 : 1'b0;
state <= DONE;
done <= 0;
end

DONE: begin
done <= 1'b1;
state <= DONE;
end

default: begin
state <= IDLE;
done <= 0;
result <= 0;
end
endcase
end
endmodule