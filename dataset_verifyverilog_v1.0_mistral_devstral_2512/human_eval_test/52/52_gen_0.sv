module below_threshold(
    input [7:0] threshold,
    input [7:0] numbers [0:7],
    output result
);
    wire [7:0] comparisons;
    
    assign comparisons[0] = (numbers[0] < threshold);
    assign comparisons[1] = (numbers[1] < threshold);
    assign comparisons[2] = (numbers[2] < threshold);
    assign comparisons[3] = (numbers[3] < threshold);
    assign comparisons[4] = (numbers[4] < threshold);
    assign comparisons[5] = (numbers[5] < threshold);
    assign comparisons[6] = (numbers[6] < threshold);
    assign comparisons[7] = (numbers[7] < threshold);
    
    assign result = comparisons[0] & comparisons[1] & comparisons[2] & comparisons[3] &
                   comparisons[4] & comparisons[5] & comparisons[6] & comparisons[7];
endmodule