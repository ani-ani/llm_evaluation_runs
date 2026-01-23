module octagonal_number(input [7:0] n, output [15:0] result);
assign result = (3 * n * n) - (2 * n);
endmodule