module trapezium_median (
    input [31:0] base1,
    input [31:0] base2,
    output [31:0] median
);

    // Intermediate signal for the sum of the two bases
    wire [31:0] sum;

    // Calculate sum = base1 + base2
    assign sum = base1 + base2;

    // Calculate median = sum / 2 using arithmetic right shift
    // Since inputs are unsigned, logical right shift is equivalent to division by 2
    assign median = sum >> 1;

endmodule
