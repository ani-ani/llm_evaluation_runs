module median_three (
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output [7:0] median
);

    wire a_gt_b = (a > b);
    wire a_lt_c = (a < c);
    wire b_gt_c = (b > c);
    wire a_gt_c = (a > c);
    wire b_lt_c = (b < c);

    assign median = 
        // a > b branch
        (a_gt_b) ? (
            (a_lt_c) ? a : // b < a < c
            (b_gt_c) ? b : // c < b < a
            c              // b < c < a
        ) :
        // a <= b branch
        (
            (a_gt_c) ? a : // c < a <= b
            (b_lt_c) ? b : // a <= b < c
            c              // a <= c <= b
        );

endmodule