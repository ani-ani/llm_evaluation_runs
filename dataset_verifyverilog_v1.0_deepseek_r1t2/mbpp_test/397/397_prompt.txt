module median_three_numbers (
    // Inputs (3 numbers)
    input  [7:0] a,
    input  [7:0] b,
    input  [7:0] c,
    
    // Output (median value)
    output [7:0] median
);

// Combinational logic to find median of three 8-bit numbers
// Strategy: Use comparators to determine which value is the middle

// Internal signals
wire a_gt_b;
wire a_gt_c;
wire b_gt_c;

// Comparison results
assign a_gt_b = (a > b);
assign a_gt_c = (a > c);
assign b_gt_c = (b > c);

// The median is the value that is not the maximum and not the minimum
// a is median when: (a >= b && a <= c) or (a <= b && a >= c)
// b is median when: (b >= a && b <= c) or (b <= a && b >= c)
// otherwise c is median

wire use_a;
wire use_b;

assign use_a = (a_gt_b && a_gt_c == 0) || (a_gt_b == 0 && a_gt_c);
assign use_b = (a_gt_b == 0 && b_gt_c) || (a_gt_b && b_gt_c == 0);

// Final multiplexer
assign median = use_a ? a :
                use_b ? b :
                        c;

endmodule