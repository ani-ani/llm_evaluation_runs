module tetrahedral_number(input [7:0] n, output [31:0] result);
assign result = (n * (n + 1) * (n + 2)) / 6;
endmodule