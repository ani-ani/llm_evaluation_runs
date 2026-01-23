module multiple_to_single (input clk, input rst_n, input start, input [31:0] num_1, num_2, num_3, num_4, num_5, num_6, input [2:0] count, output reg [63:0] result, output reg done, output reg error);
reg [2:0] state;
reg [2:0] current_num_index;
reg is_negative;
reg [63:0] accumulated_result;
reg [31:0] temp_num;
reg [3:0] digit_count;
always @(*) begin
state <= 3'b000;
current_num_index <= 3'b000;
is_negative <= 0;
accumulated_result <= 64'b0;
temp_num <= 32'b0;
digit_count <= 4'b0;
end
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 3'b000;
current_num_index <= 3'b000;
is_negative <= 0;
accumulated_result <= 64'b0;
temp_num <= 32'b0;
digit_count <= 4'b0;
end else begin
case (state)
3'b000: if (start == 1) state <= 3'b001;
3'b001: is_negative <= 0;
if (count >=1) is_negative |= (num_1 >= 32'd2147483648);
if (count >=2) is_negative |= (num_2 >= 32'd2147483648);
if (count >=3) is_negative |= (num_3 >= 32'd2147483648);
if (count >=4) is_negative |= (num_4 >= 32'd2147483648);
if (count >=5) is_negative |= (num_5 >= 32'd2147483648);
if (count >=6) is_negative |= (num_6 >= 32'd2147483648);
state <= 3'b010;
3'b010: if (current_num_index < count) begin
case (current_num_index)
0: temp_num <= num_1;
1: temp_num <= num_2;
2: temp_num <= num_3;
3: temp_num <= num_4;
4: temp_num <= num_5;
5: temp_num <= num_6;
endcase
if (temp_num >= 32'd2147483648) begin
temp_num <= ~temp_num + 1;
end
accumulated_result <= accumulated_result * 10 + temp_num[3:0];
current_num_index <= current_num_index + 1;
if (current_num_index == count) state <= 3'b100;
end else begin
state <= 3'b100;
end
3'b100: error <= 0;
if (is_negative) begin
error <= (accumulated_result > 32'd9223372036854775807);
end else begin
error <= (accumulated_result > 32'd9223372036854775807);
end
done <= 1;
state <= 3'b101;
3'b101: // stay
default: state <=3'b000;
endcase
end
end
assign result = is_negative ? (~accumulated_result + 1) : accumulated_result;
assign done = done;
assign error = error;
endmodule