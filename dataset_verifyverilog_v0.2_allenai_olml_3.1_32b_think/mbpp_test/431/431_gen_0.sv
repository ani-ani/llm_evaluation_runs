module common_element (
    input [7:0] list1 [0:4],
    input [7:0] list2 [0:4],
    output result
);

genvar i, j;
wire [24:0] comparisons;

generate
    for (i=0; i<5; i=i+1)
        for (j=0; j<5; j=j+1)
            comparisons[i*5 + j] = list1[i] == list2[j];
endgenerate

assign result = |comparisons;

endmodule