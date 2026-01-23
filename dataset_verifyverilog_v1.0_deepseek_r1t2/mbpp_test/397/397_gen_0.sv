module median_three_numbers (
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output [7:0] median
);

    wire a_gt_b = (a > b);
    wire a_gt_c = (a > c);
    wire b_gt_c = (b > c);

    wire use_a = (a_gt_b ? !a_gt_c : a_gt_c);
    wire use_b = (a_gt_b ? !b_gt_c : b_gt_c);

    assign median = use_a ? a : (use_b ? b : c);
endmodule