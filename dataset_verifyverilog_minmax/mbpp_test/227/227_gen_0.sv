module min_of_three (input reg signed [7:0] a, b, c, output wire signed [7:0] min_val);
    wire signed [7:0] min_ab;
    assign min_ab = (a < b) ? a : b;
    assign min_val = (min_ab < c) ? min_ab : c;
endmodule