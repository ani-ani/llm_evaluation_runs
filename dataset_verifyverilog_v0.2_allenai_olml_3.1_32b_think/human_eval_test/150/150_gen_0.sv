module x_or_y(input [3:0] n, input [31:0] x, input [31:0] y, output [31:0] result);
assign result = (n == 2 || n == 3 || n ==5 || n ==7 || n ==11 || n ==13) ? x : y;
endmodule