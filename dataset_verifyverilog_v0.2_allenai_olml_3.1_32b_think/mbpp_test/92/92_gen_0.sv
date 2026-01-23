module is_undulating (
input clk,
input rst_n, // active-low reset
input start,
input [31:0] number,
output reg result,
output reg done
);

localparam IDLE = 3'd0,
EXTRACT = 3'd1,
CHECK = 3'd2,
DONE = 3'd3;

reg [2:0] state = 3'd0;
reg [31:0] temp_num = 32'd0;
reg [3:0] digits [10] = 4'd0;
reg [3:0] extract_counter = 4'd0;
reg [3:0] check_counter = 4'd0;
reg [1:0] done_counter = 2'd0;
reg [3:0] actual_digit_count = 4'd0;
reg [3:0] result_reg = 4'd0;

always_ff @(posedge clk) begin
if (!rst_n) begin
state <= IDLE;
temp_num <= 32'd0;
extract_counter <= 4'd0;
check_counter <= 4'd0;
done_counter <= 2'd0;
actual_digit_count <= 4'd0;
result_reg <= 4'd0;
end else begin
case (state)
IDLE: begin
if (start) begin
state <= EXTRACT;
temp_num <= number;
extract_counter <= 4'd0;
check_counter <= 4'd0;
done_counter <= 2'd0;
actual_digit_count <= 4'd0;
result_reg <= 4'd0;
end
end
EXTRACT: begin
if (extract_counter < 10) begin
digits[extract_counter] <= temp_num % 10;
temp_num <= temp_num / 10;
extract_counter <= extract_counter + 1;
state <= EXTRACT;
end else begin
state <= CHECK;
extract_counter <= 4'd0;
check_counter <= 4'd0;
end
end
CHECK: begin
if (check_counter < 8) begin
check_counter <= check_counter + 1;
// Compute actual_digit_count
actual_digit_count <= 4'd0;
if (digits[0] != 4'd0) actual_digit_count <= 1;
else if (digits[1] != 4'd0) actual_digit_count <= 2;
else if (digits[2] != 4'd0) actual_digit_count <= 3;
else if (digits[3] != 4'd0) actual_digit_count <= 4;
else if (digits[4] != 4'd0) actual_digit_count <= 5;
else if (digits[5] != 4'd0) actual_digit_count <= 6;
else if (digits[6] != 4'd0) actual_digit_count <= 7;
else if (digits[7] != 4'd0) actual_digit_count <= 8;
else if (digits[8] != 4'd0) actual_digit_count <= 9;
else if (digits[9] != 4'd0) actual_digit_count <= 10;
else actual_digit_count <= 1;
// Compute result_reg
result_reg <= 4'd0;
if (actual_digit_count > 2) begin
result_reg <= 4'd1;
if (digits[2] != digits[0]) result_reg <= 4'd0;
if (result_reg && actual_digit_count > 3) begin
if (digits[3] != digits[1]) result_reg <= 4'd0;
end
if (result_reg && actual_digit_count > 4) begin
if (digits[4] != digits[2]) result_reg <= 4'd0;
end
if (result_reg && actual_digit_count > 5) begin
if (digits[5] != digits[3]) result_reg <= 4'd0;
end
if (result_reg && actual_digit_count > 6) begin
if (digits[6] != digits[4]) result_reg <= 4'd0;
end
if (result_reg && actual_digit_count > 7) begin
if (digits[7] != digits[5]) result_reg <= 4'd0;
end
if (result_reg && actual_digit_count > 8) begin
if (digits[8] != digits[6]) result_reg <= 4'd0;
end
if (result_reg && actual_digit_count > 9) begin
if (digits[9] != digits[7]) result_reg <= 4'd0;
end
end
if (check_counter == 8) begin
state <= DONE;
check_counter <= 4'd0;
end
end
end
DONE: begin
if (done_counter < 2) begin
done_counter <= done_counter + 1;
if (done_counter == 2) begin
// Keep result_reg
end
end else begin
state <= DONE;
done_counter <= 2'd1;
end
endcase
end
end

// Assign outputs
assign result = result_reg;
assign done = (state == DONE) && (done_counter == 1);

endmodule