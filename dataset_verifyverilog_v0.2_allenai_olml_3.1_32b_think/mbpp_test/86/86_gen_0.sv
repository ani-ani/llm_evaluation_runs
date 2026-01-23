module centered_hexagonal(input [7:0] n, output reg [31:0] result);
assign result = 3'u * n * (n - 1) + 1;
endmodule