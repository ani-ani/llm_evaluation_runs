module check_element (
    input [7:0] element_to_match,
    input [31:0] array_data,
    output result
);

    // Extract individual 8-bit elements from the 32-bit input vector
    wire [7:0] elem0 = array_data[31:24];
    wire [7:0] elem1 = array_data[23:16];
    wire [7:0] elem2 = array_data[15:8];
    wire [7:0] elem3 = array_data[7:0];

    // Compare each element with the target value
    wire match0 = (elem0 == element_to_match);
    wire match1 = (elem1 == element_to_match);
    wire match2 = (elem2 == element_to_match);
    wire match3 = (elem3 == element_to_match);

    // Combine results: result is 1 only if ALL comparisons are true
    assign result = match0 & match1 & match2 & match3;

endmodule