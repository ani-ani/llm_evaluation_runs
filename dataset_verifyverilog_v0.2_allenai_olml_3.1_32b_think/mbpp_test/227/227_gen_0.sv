module min_of_three(
    input signed [7:0] a,
    input signed [7:0] b,
    input signed [7:0] c,
    output signed [7:0] min
);
assign min = (a <= b && a <= c) ? a : ( (b <= a && b <= c) ? b : c );
endmodule