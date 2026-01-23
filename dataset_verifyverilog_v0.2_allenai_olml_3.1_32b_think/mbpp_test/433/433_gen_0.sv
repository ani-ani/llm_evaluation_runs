module check_greater(input [7:0] number, input [7:0] arr [0:7], output result);
    assign result = (number > arr[0]) & (number > arr[1]) & (number > arr[2]) & (number > arr[3]) & (number > arr[4]) & (number > arr[5]) & (number > arr[6]) & (number > arr[7]);
endmodule