module tuple_intersection (
    input  [7:0] in1_0, in1_1,  // Tuple 0 of list1: elements {in1_1, in1_0}
    input  [7:0] in1_2, in1_3,  // Tuple 1 of list1: elements {in1_3, in1_2}
    input  [7:0] in1_4, in1_5,  // Tuple 2 of list1: elements {in1_5, in1_4}
    input  [7:0] in1_6, in1_7,  // Tuple 3 of list1: elements {in1_7, in1_6}
    input  [7:0] in2_0, in2_1,  // Tuple 0 of list2: elements {in2_1, in2_0}
    input  [7:0] in2_2, in2_3,  // Tuple 1 of list2: elements {in2_3, in2_2}
    input  [7:0] in2_4, in2_5,  // Tuple 2 of list2: elements {in2_5, in2_4}
    input  [7:0] in2_6, in2_7,  // Tuple 3 of list2: elements {in2_7, in2_6}
    output [3:0] match_mask     // Bit i is 1 if tuple i from list1 matches any in list2
);

    // Sort tuples in list1
    wire [7:0] list1_min0 = (in1_0 < in1_1) ? in1_0 : in1_1;
    wire [7:0] list1_max0 = (in1_0 < in1_1) ? in1_1 : in1_0;
    wire [7:0] list1_min1 = (in1_2 < in1_3) ? in1_2 : in1_3;
    wire [7:0] list1_max1 = (in1_2 < in1_3) ? in1_3 : in1_2;
    wire [7:0] list1_min2 = (in1_4 < in1_5) ? in1_4 : in1_5;
    wire [7:0] list1_max2 = (in1_4 < in1_5) ? in1_5 : in1_4;
    wire [7:0] list1_min3 = (in1_6 < in1_7) ? in1_6 : in1_7;
    wire [7:0] list1_max3 = (in1_6 < in1_7) ? in1_7 : in1_6;

    // Sort tuples in list2
    wire [7:0] list2_min0 = (in2_0 < in2_1) ? in2_0 : in2_1;
    wire [7:0] list2_max0 = (in2_0 < in2_1) ? in2_1 : in2_0;
    wire [7:0] list2_min1 = (in2_2 < in2_3) ? in2_2 : in2_3;
    wire [7:0] list2_max1 = (in2_2 < in2_3) ? in2_3 : in2_2;
    wire [7:0] list2_min2 = (in2_4 < in2_5) ? in2_4 : in2_5;
    wire [7:0] list2_max2 = (in2_4 < in2_5) ? in2_5 : in2_4;
    wire [7:0] list2_min3 = (in2_6 < in2_7) ? in2_6 : in2_7;
    wire [7:0] list2_max3 = (in2_6 < in2_7) ? in2_7 : in2_6;

    // Compare all combinations
    wire match_00 = (list1_min0 == list2_min0) & (list1_max0 == list2_max0);
    wire match_01 = (list1_min0 == list2_min1) & (list1_max0 == list2_max1);
    wire match_02 = (list1_min0 == list2_min2) & (list1_max0 == list2_max2);
    wire match_03 = (list1_min0 == list2_min3) & (list1_max0 == list2_max3);
    wire match_10 = (list1_min1 == list2_min0) & (list1_max1 == list2_max0);
    wire match_11 = (list1_min1 == list2_min1) & (list1_max1 == list2_max1);
    wire match_12 = (list1_min1 == list2_min2) & (list1_max1 == list2_max2);
    wire match_13 = (list1_min1 == list2_min3) & (list1_max1 == list2_max3);
    wire match_20 = (list1_min2 == list2_min0) & (list1_max2 == list2_max0);
    wire match_21 = (list1_min2 == list2_min1) & (list1_max2 == list2_max1);
    wire match_22 = (list1_min2 == list2_min2) & (list1_max2 == list2_max2);
    wire match_23 = (list1_min2 == list2_min3) & (list1_max2 == list2_max3);
    wire match_30 = (list1_min3 == list2_min0) & (list1_max3 == list2_max0);
    wire match_31 = (list1_min3 == list2_min1) & (list1_max3 == list2_max1);
    wire match_32 = (list1_min3 == list2_min2) & (list1_max3 == list2_max2);
    wire match_33 = (list1_min3 == list2_min3) & (list1_max3 == list2_max3);

    // Aggregate results
    assign match_mask[0] = match_00 | match_01 | match_02 | match_03;
    assign match_mask[1] = match_10 | match_11 | match_12 | match_13;
    assign match_mask[2] = match_20 | match_21 | match_22 | match_23;
    assign match_mask[3] = match_30 | match_31 | match_32 | match_33;

endmodule