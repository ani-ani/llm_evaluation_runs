module below_threshold(output result, input [7:0] threshold, input [7:0] array [0:7]);
assign result = (array[0] < threshold) & (array[1] < threshold) & (array[2] < threshold) & (array[3] < threshold) & (array[4] < threshold) & (array[5] < threshold) & (array[6] < threshold) & (array[7] < threshold);
endmodule