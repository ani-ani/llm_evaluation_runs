module difference_module(input [3:0] n, output [31:0] result);
    wire [4:0] n_plus_1;
    wire [8:0] temp;
    assign n_plus_1 = ({1'b0, n}) + 1;
    assign temp = n * n_plus_1;
    assign result = (temp >> 1) * ( (temp >> 1) - 1 );
endmodule