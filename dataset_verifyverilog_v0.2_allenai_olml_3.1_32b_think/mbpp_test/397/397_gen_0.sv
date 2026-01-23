module median_three (
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output [7:0] median
);
assign median = (a > b) ? ( (a < c) ? a : ( (b > c) ? b : c ) ) : ( (a > c) ? a : ( (b < c) ? b : c ) );
endmodule