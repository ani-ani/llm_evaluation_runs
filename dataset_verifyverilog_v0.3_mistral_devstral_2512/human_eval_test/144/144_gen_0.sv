module fraction_simplify(
    input [15:0] x_num,
    input [15:0] x_den,
    input [15:0] n_num,
    input [15:0] n_den,
    output result
);
    wire [31:0] prod_num;
    wire [31:0] prod_den;
    assign prod_num = x_num * n_num;
    assign prod_den = x_den * n_den;
    assign result = (prod_den != 16'd0) && (prod_num % prod_den == 16'd0);
endmodule