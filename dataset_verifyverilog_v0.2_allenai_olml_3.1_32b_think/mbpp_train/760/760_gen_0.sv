module unique_element_check (
    input [7:0] arr [0:7],
    output result
);
assign result = (arr[1] == arr[0]) & (arr[2] == arr[0]) & (arr[3] == arr[0]) & (arr[4] == arr[0]) & (arr[5] == arr[0]) & (arr[6] == arr[0]) & (arr[7] == arr[0]);
endmodule