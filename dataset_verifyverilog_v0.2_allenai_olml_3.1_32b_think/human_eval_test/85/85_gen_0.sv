module add_even_at_odd_indices (
    input [7:0] arr [0:7],
    output [15:0] result
);
assign result = (arr[1][0] == 0) ? arr[1] : 0 + (arr[3][0] == 0) ? arr[3] : 0 + (arr[5][0] == 0) ? arr[5] : 0 + (arr[7][0] == 0) ? arr[7] : 0;
endmodule