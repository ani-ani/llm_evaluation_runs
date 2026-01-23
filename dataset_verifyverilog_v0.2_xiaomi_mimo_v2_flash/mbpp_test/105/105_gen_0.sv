module bool_count (
    input [7:0] data,
    output [3:0] count
);

    // Internal sum signals for the parallel adder tree
    wire [1:0] sum1, sum2, sum3, sum4;
    wire [2:0] sum5, sum6;

    // Level 1: Add adjacent pairs of bits
    assign sum1 = data[7] + data[6];
    assign sum2 = data[5] + data[4];
    assign sum3 = data[3] + data[2];
    assign sum4 = data[1] + data[0];

    // Level 2: Add results from Level 1
    assign sum5 = sum1 + sum2;
    assign sum6 = sum3 + sum4;

    // Level 3: Final addition to get 4-bit count
    assign count = sum5 + sum6;

endmodule