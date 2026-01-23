module choose_num (
    input [15:0] x,
    input [15:0] y,
    output [15:0] result
);

    wire [15:0] largest_even;
    wire [15:0] y_minus_1;
    wire x_gt_y;
    wire largest_even_ge_x;

    // 2. Find largest even number <= y
    // If y is even, use y; if y is odd, use y - 1
    assign y_minus_1 = y - 1;
    assign largest_even = (y[0] == 1'b0) ? y : y_minus_1;

    // 1. Check if x > y
    assign x_gt_y = (x > y);

    // 3. Check if largest_even >= x
    assign largest_even_ge_x = (largest_even >= x);

    // Output logic
    // If x > y OR largest_even < x, return -1 (0xFFFF)
    // Else return largest_even
    assign result = (x_gt_y || !largest_even_ge_x) ? 16'hFFFF : largest_even;

endmodule