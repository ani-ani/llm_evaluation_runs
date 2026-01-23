module min_of_three (
    input signed [7:0] a,
    input signed [7:0] b,
    input signed [7:0] c,
    output signed [7:0] min
);
    wire a_le_b;
    wire a_le_c;
    wire b_le_a;
    wire b_le_c;
    assign a_le_b = (a <= b);
    assign a_le_c = (a <= c);
    assign b_le_a = (b <= a);
    assign b_le_c = (b <= c);
    assign min = (a_le_b & a_le_c) ? a : (b_le_a & b_le_c) ? b : c;
endmodule