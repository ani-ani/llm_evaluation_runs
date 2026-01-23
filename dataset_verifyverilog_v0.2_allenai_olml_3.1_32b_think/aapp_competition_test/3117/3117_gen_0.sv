module longest_repeated_substring (
input clk,
input rst_n, // active-low reset
input start,
input [4:0] char_in [0:15], // 16 elements
output reg [4:0] max_len,
output reg done
);
// Internal registers
reg [2:0] state;
reg [4:0] current_length;
reg [3:0] i, j, char_index;
reg match_found;
// Reset and state machine
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 3'b000;
current_length <= 5'd0;
i <= 4'd0;
j <= 4'd0;
char_index <= 4'd0;
match_found <= 1'b0;
max_len <= 5'd0;
done <= 1'b0;
end else begin
case (state)
3'b000: // IDLE
if (start)
state <= 3'b001;
// else stay in IDLE
3'b001: // CHECK_LEN
current_length <= 15;
state <= 3'b010;
3'b010: // CHECK_DUPLICATES
if (i < (16 - current_length)) begin
if (j < (i + 1)) begin
j <= i + 1;
end else if (j < (16 - current_length)) begin
if (char_index < current_length) begin
if (char_in[i + char_index] == char_in[j + char_index]) begin
char_index <= char_index + 1;
end else begin
char_index <= 4'd0;
match_found <= 1'b0;
end
end else begin // all characters matched
match_found <= 1'b1;
i <= (16 - current_length); // force exit i loop
end
end else begin // j >= 16 - current_length, no more j for this i
i <= i + 1;
j <= 4'd0;
char_index <= 4'd0;
match_found <= 1'b0;
end
end else begin // i loop finished
if (match_found) begin
max_len <= current_length;
done <= 1'b1;
state <= 3'b100;
end else begin
state <= 3'b011; // NEXT_LEN
end
3'b011: // NEXT_LEN
if (current_length > 1) begin
current_length <= current_length - 1;
i <= 4'd0;
j <= 4'd0;
char_index <= 4'd0;
match_found <= 1'b0;
state <= 3'b010;
end else begin
max_len <= 5'd0;
done <= 1'b1;
state <= 3'b100;
end
3'b100: // OUTPUT
// stay in output
state <= 3'b100;
default: state <= 3'b000;
endcase
end
endmodule