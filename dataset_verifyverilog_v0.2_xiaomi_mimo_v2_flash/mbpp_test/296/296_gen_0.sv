module inversion_counter (
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output [7:0] inv_count
);

    wire [7:0] arr [0:7];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;

    wire [27:0] comps;

    // Generate all 28 comparisons (i < j)
    assign comps[0] = (arr[0] > arr[1]);
    assign comps[1] = (arr[0] > arr[2]);
    assign comps[2] = (arr[0] > arr[3]);
    assign comps[3] = (arr[0] > arr[4]);
    assign comps[4] = (arr[0] > arr[5]);
    assign comps[5] = (arr[0] > arr[6]);
    assign comps[6] = (arr[0] > arr[7]);
    assign comps[7] = (arr[1] > arr[2]);
    assign comps[8] = (arr[1] > arr[3]);
    assign comps[9] = (arr[1] > arr[4]);
    assign comps[10] = (arr[1] > arr[5]);
    assign comps[11] = (arr[1] > arr[6]);
    assign comps[12] = (arr[1] > arr[7]);
    assign comps[13] = (arr[2] > arr[3]);
    assign comps[14] = (arr[2] > arr[4]);
    assign comps[15] = (arr[2] > arr[5]);
    assign comps[16] = (arr[2] > arr[6]);
    assign comps[17] = (arr[2] > arr[7]);
    assign comps[18] = (arr[3] > arr[4]);
    assign comps[19] = (arr[3] > arr[5]);
    assign comps[20] = (arr[3] > arr[6]);
    assign comps[21] = (arr[3] > arr[7]);
    assign comps[22] = (arr[4] > arr[5]);
    assign comps[23] = (arr[4] > arr[6]);
    assign comps[24] = (arr[4] > arr[7]);
    assign comps[25] = (arr[5] > arr[6]);
    assign comps[26] = (arr[5] > arr[7]);
    assign comps[27] = (arr[6] > arr[7]);

    // Combinational tree of adders to sum all 1-bit comparison results
    // Level 1: 14 adders (28 inputs -> 14 sums)
    wire [4:0] l1 [0:13];
    assign l1[0] = {3'b0, comps[0]} + {3'b0, comps[1]};
    assign l1[1] = {3'b0, comps[2]} + {3'b0, comps[3]};
    assign l1[2] = {3'b0, comps[4]} + {3'b0, comps[5]};
    assign l1[3] = {3'b0, comps[6]} + {3'b0, comps[7]};
    assign l1[4] = {3'b0, comps[8]} + {3'b0, comps[9]};
    assign l1[5] = {3'b0, comps[10]} + {3'b0, comps[11]};
    assign l1[6] = {3'b0, comps[12]} + {3'b0, comps[13]};
    assign l1[7] = {3'b0, comps[14]} + {3'b0, comps[15]};
    assign l1[8] = {3'b0, comps[16]} + {3'b0, comps[17]};
    assign l1[9] = {3'b0, comps[18]} + {3'b0, comps[19]};
    assign l1[10] = {3'b0, comps[20]} + {3'b0, comps[21]};
    assign l1[11] = {3'b0, comps[22]} + {3'b0, comps[23]};
    assign l1[12] = {3'b0, comps[24]} + {3'b0, comps[25]};
    assign l1[13] = {3'b0, comps[26]} + {3'b0, comps[27]};

    // Level 2: 7 adders (14 sums -> 7 sums)
    wire [5:0] l2 [0:6];
    assign l2[0] = {1'b0, l1[0]} + {1'b0, l1[1]};
    assign l2[1] = {1'b0, l1[2]} + {1'b0, l1[3]};
    assign l2[2] = {1'b0, l1[4]} + {1'b0, l1[5]};
    assign l2[3] = {1'b0, l1[6]} + {1'b0, l1[7]};
    assign l2[4] = {1'b0, l1[8]} + {1'b0, l1[9]};
    assign l2[5] = {1'b0, l1[10]} + {1'b0, l1[11]};
    assign l2[6] = {1'b0, l1[12]} + {1'b0, l1[13]};

    // Level 3: 4 adders (7 sums -> 4 sums)
    wire [6:0] l3 [0:3];
    assign l3[0] = {1'b0, l2[0]} + {1'b0, l2[1]};
    assign l3[1] = {1'b0, l2[2]} + {1'b0, l2[3]};
    assign l3[2] = {1'b0, l2[4]} + {1'b0, l2[5]};
    assign l3[3] = {1'b0, l2[6]};

    // Level 4: 2 adders (4 sums -> 2 sums)
    wire [7:0] l4 [0:1];
    assign l4[0] = {1'b0, l3[0]} + {1'b0, l3[1]};
    assign l4[1] = {1'b0, l3[2]} + {1'b0, l3[3]};

    // Level 5: 1 adder (2 sums -> 1 sum)
    wire [8:0] l5;
    assign l5 = {1'b0, l4[0]} + {1'b0, l4[1]};

    // The result is 8 bits, max value 28 fits easily
    assign inv_count = l5[7:0];

endmodule