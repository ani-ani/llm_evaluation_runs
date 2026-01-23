module histogram_max (
input clk,
input rst_n,
input start,
input [7:0] char_in [0:15],
output reg [3:0] max_count,
output reg [25:0] max_letters,
output reg done
);

function [3:0] max_of_array;
input [3:0] counts [0:25];
reg [3:0] max_val;
integer i;
max_val = counts[0];
for (i=1; i<26; i=i+1) begin
if (counts[i] > max_val) max_val = counts[i];
end
max_of_array = max_val;
endfunction

function [25:0] build_mask;
input [3:0] max_val;
input [3:0] counts [0:25];
reg [25:0] mask;
integer i;
for (i=0; i<26; i=i+1) begin
if (counts[i] == max_val) begin
mask[i] =1'b1;
end else begin
mask[i] =1'b0;
end
end
build_mask = mask;
endfunction

reg [1:0] state;
reg [3:0] count_idx;
reg [3:0] counts [0:25];
reg [3:0] max_val_reg;
reg [25:0] max_mask_reg;
reg [1:0] find_max_count;

always @(posedge clk) begin
if (!rst_n) begin
state <= 2'b00;
count_idx <=4'd0;
for (int i=0; i<26; i++) counts[i] <=4'd0;
max_val_reg <=4'd0;
max_mask_reg <=26'd0;
find_max_count <=2'd0;
max_count <=4'd0;
max_letters <=26'd0;
done <=1'b0;
end else begin
case(state)
2'b00: begin
if (start) state <= 2'b01;
end
2'b01: begin
reg [7:0] current_char;
integer i;
i = count_idx;
current_char = char_in[(i*8)+7 : i*8];
if (current_char == 8'h20) begin
// ignore
end else begin
if (current_char >=8'h61 && current_char <=8'h7a) begin
integer letter_index = current_char - 8'h61;
counts[letter_index] <= counts[letter_index] +1;
end
end
if (count_idx <15) begin
count_idx <= count_idx +1;
end else begin
count_idx <=16;
state <= 2'b10;
end
end
2'b10: begin
if (find_max_count ==2'd0) begin
max_val_reg <= max_of_array(counts);
find_max_count <=1;
end else if (find_max_count ==2'd1) begin
max_mask_reg <= build_mask(max_val_reg, counts);
find_max_count <=2;
state <= 2'b11;
end
end
2'b11: begin
max_count <= max_val_reg;
max_letters <= max_mask_reg;
done <=1;
end
endcase
end
end

endmodule