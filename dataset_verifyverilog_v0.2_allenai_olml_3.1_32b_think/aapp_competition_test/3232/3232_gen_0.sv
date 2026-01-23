module string_rearrange (input clk, input rst_n, input start, input [7:0][7:0] char_array, output reg [7:0][7:0] result, output reg valid, output reg no_solution, output reg done);
reg [7:0][7:0] current_chars;
reg [2:0] state;
reg [6:0] sort_step;
reg [31:0] sub0, sub1, sub2, sub3, sub4;
reg dup_found;
assign result = current_chars;
always @(*) begin
sub0 = {current_chars[0], current_chars[1], current_chars[2], current_chars[3]};
sub1 = {current_chars[1], current_chars[2], current_chars[3], current_chars[4]};
sub2 = {current_chars[2], current_chars[3], current_chars[4], current_chars[5]};
sub3 = {current_chars[3], current_chars[4], current_chars[5], current_chars[6]};
sub4 = {current_chars[4], current_chars[5], current_chars[6], current_chars[7]};
dup_found = 0;
dup_found |= (sub0 == sub1);
dup_found |= (sub0 == sub2);
dup_found |= (sub0 == sub3);
dup_found |= (sub0 == sub4);
dup_found |= (sub1 == sub2);
dup_found |= (sub1 == sub3);
dup_found |= (sub1 == sub4);
dup_found |= (sub2 == sub3);
dup_found |= (sub2 == sub4);
dup_found |= (sub3 == sub4);
end
always @(posedge clk) begin
if (!rst_n) begin
state <= 3'b000;
current_chars <= 8'b0;
sort_step <= 0;
valid <= 0;
o_solution <= 0;
done <= 0;
end else begin
case(state)
3'b000: if (start) begin
current_chars <= char_array;
state <= 3'b001;
sort_step <= 0;
end;
end
3'b001: if (sort_step < 49) begin
int compare_index = sort_step % 7;
if (current_chars[compare_index] > current_chars[compare_index + 1]) begin
current_chars[compare_index] <= current_chars[compare_index + 1];
current_chars[compare_index + 1] <= current_chars[compare_index];
end
sort_step <= sort_step + 1;
end else begin
state <= 3'b010;
end;
end
3'b010: if (!dup_found) begin
state <= 3'b101;
valid <= 1;
o_solution <= 0;
done <= 1;
end else begin
state <= 3'b011;
end;
end
3'b011: current_chars[0] <= current_chars[7];
current_chars[1] <= current_chars[6];
current_chars[2] <= current_chars[5];
current_chars[3] <= current_chars[4];
current_chars[4] <= current_chars[3];
current_chars[5] <= current_chars[2];
current_chars[6] <= current_chars[1];
current_chars[7] <= current_chars[0];
state <= 3'b100;
end;
3'b100: if (!dup_found) begin
state <= 3'b101;
valid <= 1;
o_solution <= 0;
done <= 1;
end else begin
state <= 3'b101;
valid <= 0;
o_solution <= 1;
done <= 1;
end;
end
3'b101: // No action
endcase
endcase
end
endmodule