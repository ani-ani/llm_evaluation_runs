module SublistCounter (
    // Sublist 0
    input [7:0] s0_0,
    input [7:0] s0_1,
    input [7:0] s0_2,
    // Sublist 1
    input [7:0] s1_0,
    input [7:0] s1_1,
    input [7:0] s1_2,
    // Sublist 2
    input [7:0] s2_0,
    input [7:0] s2_1,
    input [7:0] s2_2,
    // Sublist 3
    input [7:0] s3_0,
    input [7:0] s3_1,
    input [7:0] s3_2,
    // Search element
    input [7:0] search_element,
    // Output
    output reg [2:0] count
);

    // Internal signals for each sublist match
    reg match0, match1, match2, match3;

    always @(*) begin
        // Check each sublist for any matching element
        match0 = (s0_0 == search_element) || (s0_1 == search_element) || (s0_2 == search_element);
        match1 = (s1_0 == search_element) || (s1_1 == search_element) || (s1_2 == search_element);
        match2 = (s2_0 == search_element) || (s2_1 == search_element) || (s2_2 == search_element);
        match3 = (s3_0 == search_element) || (s3_1 == search_element) || (s3_2 == search_element);

        // Count matches
        count = 3'd0;
        if (match0) count = count + 3'd1;
        if (match1) count = count + 3'd1;
        if (match2) count = count + 3'd1;
        if (match3) count = count + 3'd1;
    end

endmodule