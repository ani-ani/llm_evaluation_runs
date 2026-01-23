module unequal_pair_counter (
    input [7:0] arr [0:7],
    output [5:0] count
);

    wire [27:0] unequal_bits;

    // Generate all 28 unordered pair comparisons
    assign unequal_bits[0] = (arr[0] != arr[1]);
    assign unequal_bits[1] = (arr[0] != arr[2]);
    assign unequal_bits[2] = (arr[0] != arr[3]);
    assign unequal_bits[3] = (arr[0] != arr[4]);
    assign unequal_bits[4] = (arr[0] != arr[5]);
    assign unequal_bits[5] = (arr[0] != arr[6]);
    assign unequal_bits[6] = (arr[0] != arr[7]);
    assign unequal_bits[7] = (arr[1] != arr[2]);
    assign unequal_bits[8] = (arr[1] != arr[3]);
    assign unequal_bits[9] = (arr[1] != arr[4]);
    assign unequal_bits[10] = (arr[1] != arr[5]);
    assign unequal_bits[11] = (arr[1] != arr[6]);
    assign unequal_bits[12] = (arr[1] != arr[7]);
    assign unequal_bits[13] = (arr[2] != arr[3]);
    assign unequal_bits[14] = (arr[2] != arr[4]);
    assign unequal_bits[15] = (arr[2] != arr[5]);
    assign unequal_bits[16] = (arr[2] != arr[6]);
    assign unequal_bits[17] = (arr[2] != arr[7]);
    assign unequal_bits[18] = (arr[3] != arr[4]);
    assign unequal_bits[19] = (arr[3] != arr[5]);
    assign unequal_bits[20] = (arr[3] != arr[6]);
    assign unequal_bits[21] = (arr[3] != arr[7]);
    assign unequal_bits[22] = (arr[4] != arr[5]);
    assign unequal_bits[23] = (arr[4] != arr[6]);
    assign unequal_bits[24] = (arr[4] != arr[7]);
    assign unequal_bits[25] = (arr[5] != arr[6]);
    assign unequal_bits[26] = (arr[5] != arr[7]);
    assign unequal_bits[27] = (arr[6] != arr[7]);

    // Sum all unequal bits
    assign count = unequal_bits[0] + unequal_bits[1] + unequal_bits[2] + unequal_bits[3] + unequal_bits[4] + unequal_bits[5] + unequal_bits[6] +
                   unequal_bits[7] + unequal_bits[8] + unequal_bits[9] + unequal_bits[10] + unequal_bits[11] + unequal_bits[12] +
                   unequal_bits[13] + unequal_bits[14] + unequal_bits[15] + unequal_bits[16] + unequal_bits[17] +
                   unequal_bits[18] + unequal_bits[19] + unequal_bits[20] + unequal_bits[21] +
                   unequal_bits[22] + unequal_bits[23] + unequal_bits[24] +
                   unequal_bits[25] + unequal_bits[26] +
                   unequal_bits[27];

endmodule