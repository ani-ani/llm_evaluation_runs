module prime_counter(input [3:0] n, output [3:0] count);
wire c2 = (2 < n);
wire c3 = (3 < n);
wire c5 = (5 < n);
wire c7 = (7 < n);
wire c11 = (11 < n);
wire c13 = (13 < n);
assign count = c2 + c3 + c5 + c7 + c11 + c13;
endmodule