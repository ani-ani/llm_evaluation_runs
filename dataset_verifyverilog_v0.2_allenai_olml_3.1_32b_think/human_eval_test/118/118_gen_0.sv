module closest_vowel (
input clk,
input rst_n,
input start,
input [7:0][7:0] word,
output reg [7:0] result,
output reg done);
function automatic int is_vowel(input [7:0] c);
return (c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u' || c == 'A' || c == 'E' || c == 'I' || c == 'O' || c == 'U');
endfunction

function automatic int is_consonant(input [7:0] c);
return ( ( (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ) && !is_vowel(c) );
endfunction

reg [1:0] state; // 0: IDLE, 1: SEARCH, 2: DONE
reg [2:0] current_i; // current i value, from 6 downto 1
reg [7:0] result_reg;
reg done_reg;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= 2'd0;
current_i <= 3'd6; // Initial value, but only used if entering SEARCH
result_reg <= 8'b0;
done_reg <= 1'b0;
end else begin
case (state)
2'd0: // IDLE
if (start)
state <= 2'd1;
current_i <= 3'd6;
else
state <= 2'd0;
endcase

2'd1: // SEARCH
if (current_i >= 1) begin
// Check conditions for current_i
if (is_vowel(word[current_i]) && is_consonant(word[current_i + 1]) && is_consonant(word[current_i - 1])) begin
// Found, transition to DONE
state <= 2'd2;
result_reg <= word[current_i];
done_reg <= 1'b1;
end else begin
// Continue searching
state <= 2'd1;
current_i <= current_i - 1;
end
end else begin
// Reached i=0, no match
state <= 2'd2;
result_reg <= 8'b0;
done_reg <= 1'b1;
end
endcase

2'd2: // DONE
// Stay in DONE, no change
state <= 2'd2;
endcase
end
end

assign result = result_reg;
assign done = done_reg;
endmodule