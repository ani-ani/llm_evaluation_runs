module sum_even(input [7:0] n, output result);
assign result = (n >= 8) && (n[0] == 0);
endmodule