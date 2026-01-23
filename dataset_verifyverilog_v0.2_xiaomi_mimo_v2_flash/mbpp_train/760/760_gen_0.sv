module unique_element_check(
    input [7:0] arr [0:7],
    output result
);

    // Intermediate wires for comparison results
    wire comp1, comp2, comp3, comp4, comp5, comp6, comp7;

    // Compare each element with arr[0]
    assign comp1 = (arr[1] == arr[0]);
    assign comp2 = (arr[2] == arr[0]);
    assign comp3 = (arr[3] == arr[0]);
    assign comp4 = (arr[4] == arr[0]);
    assign comp5 = (arr[5] == arr[0]);
    assign comp6 = (arr[6] == arr[0]);
    assign comp7 = (arr[7] == arr[0]);

    // AND all comparison results together
    assign result = comp1 & comp2 & comp3 & comp4 & comp5 & comp6 & comp7;

endmodule