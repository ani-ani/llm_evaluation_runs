module count_same_pair (
    input [7:0] nums1,
    input [7:0] nums2,
    output [3:0] count
);

    // Internal wire to store comparison results for each bit position
    wire [7:0] eq_vec;

    // Generate block to compare each 8-bit element in parallel
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_comparators
            // Compare element i of nums1 with element i of nums2
            assign eq_vec[i] = (nums1[8*i +: 8] == nums2[8*i +: 8]);
        end
    endgenerate

    // Count the number of set bits in the comparison result vector
    assign count = $countones(eq_vec);

endmodule