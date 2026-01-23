module factorial_last_digit(input [7:0] n, output [3:0] last_digit);
assign last_digit = (n >= 5) ? 4'b0 : case(n)
0: 4'b1;
1: 4'b1;
2: 4'b2;
3: 4'b6;
4: 4'b4;
endmodule