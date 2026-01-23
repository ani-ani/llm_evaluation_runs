module tuple_intersection (
    input  [7:0] in1_0, in1_1,
    input  [7:0] in1_2, in1_3,
    input  [7:0] in1_4, in1_5,
    input  [7:0] in1_6, in1_7,
    input  [7:0] in2_0, in2_1,
    input  [7:0] in2_2, in2_3,
    input  [7:0] in2_4, in2_5,
    input  [7:0] in2_6, in2_7,
    output [3:0] match_mask
);
assign list1_min0 = (in1_1 < in1_0) ? in1_1 : in1_0;
assign list1_max0 = (in1_1 < in1_0) ? in1_0 : in1_1;
assign list1_min1 = (in1_3 < in1_2) ? in1_3 : in1_2;
assign list1_max1 = (in1_3 < in1_2) ? in1_2 : in1_3;
assign list1_min2 = (in1_5 < in1_4) ? in1_5 : in1_4;
assign list1_max2 = (in1_5 < in1_4) ? in1_4 : in1_5;
assign list1_min3 = (in1_7 < in1_6) ? in1_7 : in1_6;
assign list1_max3 = (in1_7 < in1_6) ? in1_6 : in1_7;
assign list2_min0 = (in2_1 < in2_0) ? in2_1 : in2_0;
assign list2_max0 = (in2_1 < in2_0) ? in2_0 : in2_1;
assign list2_min1 = (in2_3 < in2_2) ? in2_3 : in2_2;
assign list2_max1 = (in2_3 < in2_2) ? in2_2 : in2_3;
assign list2_min2 = (in2_5 < in2_4) ? in2_5 : in2_4;
assign list2_max2 = (in2_5 < in2_4) ? in2_4 : in2_5;
assign list2_min3 = (in2_7 < in2_6) ? in2_7 : in2_6;
assign list2_max3 = (in2_7 < in2_6) ? in2_6 : in2_7;
wire match0 = (list1_min0 == list2_min0 && list1_max0 == list2_max0) || (list1_min0 == list2_min1 && list1_max0 == list2_max1) || (list1_min0 == list2_min2 && list1_max0 == list2_max2) || (list1_min0 == list2_min3 && list1_max0 == list2_max3);
wire match1 = (list1_min1 == list2_min0 && list1_max1 == list2_max0) || (list1_min1 == list2_min1 && list1_max1 == list2_max1) || (list1_min1 == list2_min2 && list1_max1 == list2_max2) || (list1_min1 == list2_min3 && list1_max1 == list2_max3);
wire match2 = (list1_min2 == list2_min0 && list1_max2 == list2_max0) || (list1_min2 == list2_min1 && list1_max2 == list2_max1) || (list1_min2 == list2_min2 && list1_max2 == list2_max2) || (list1_min2 == list2_min3 && list1_max2 == list2_max3);
wire match3 = (list1_min3 == list2_min0 && list1_max3 == list2_max0) || (list1_min3 == list2_min1 && list1_max3 == list2_max1) || (list1_min3 == list2_min2 && list1_max3 == list2_max2) || (list1_min3 == list2_min3 && list1_max3 == list2_max3);
assign match_mask = {match0, match1, match2, match3};
endmodule