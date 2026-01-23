module minesweeper_safe(input [2:0] n, output [15:0] safe_mask, output [3:0] count);
reg [15:0] safe_mask;
reg [3:0] count;
case (n)
1: safe_mask = 16'b0; count = 4'b0;
2: safe_mask = 16'b0000101010101010; count = 4'b0110;
3: safe_mask = 16'b1010101010101010; count = 4'b1000;
default: safe_mask = 16'b0; count = 4'b0;
endcase
endmodule