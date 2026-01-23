module toggle_middle_bits(input [7:0] n, output [7:0] result);
    assign temp1 = n | (n >> 1);
    assign temp2 = temp1 | (temp1 >> 2);
    assign mask = temp2 | (temp2 >> 4);
    assign middle = (mask >> 1) ^ 1;
    assign result = n ^ middle;
endmodule