module sum_list (
    input [7:0] lst1_0, lst1_1, lst1_2, lst1_3, lst1_4, lst1_5, lst1_6, lst1_7,
    input [7:0] lst2_0, lst2_1, lst2_2, lst2_3, lst2_4, lst2_5, lst2_6, lst2_7,
    output [7:0] result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7
);

    // Parallel element-wise addition
    // Carry out is truncated by assigning to 8-bit output

    assign result_0 = lst1_0 + lst2_0;
    assign result_1 = lst1_1 + lst2_1;
    assign result_2 = lst1_2 + lst2_2;
    assign result_3 = lst1_3 + lst2_3;
    assign result_4 = lst1_4 + lst2_4;
    assign result_5 = lst1_5 + lst2_5;
    assign result_6 = lst1_6 + lst2_6;
    assign result_7 = lst1_7 + lst2_7;

endmodule