module prime_fib(input [3:0] n, output [31:0] result);
case(n)
1: result = 2;
2: result = 3;
3: result = 5;
4: result = 13;
5: result = 89;
6: result = 233;
7: result = 1597;
8: result = 28657;
default: result = 0;
endcase
endmodule