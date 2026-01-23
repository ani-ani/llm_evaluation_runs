module diff_even_odd (
    input [7:0] list1 [0:7],
    output [7:0] diff
);

    // Internal signals for first even and first odd
    reg [7:0] first_even;
    reg [7:0] first_odd;

    // Find first even
    always @(*) begin
        // Default to -1 (0xFF)
        first_even = 8'hFF;
        
        if (!list1[0][0])
            first_even = list1[0];
        else if (!list1[1][0])
            first_even = list1[1];
        else if (!list1[2][0])
            first_even = list1[2];
        else if (!list1[3][0])
            first_even = list1[3];
        else if (!list1[4][0])
            first_even = list1[4];
        else if (!list1[5][0])
            first_even = list1[5];
        else if (!list1[6][0])
            first_even = list1[6];
        else if (!list1[7][0])
            first_even = list1[7];
    end

    // Find first odd
    always @(*) begin
        // Default to -1 (0xFF)
        first_odd = 8'hFF;
        
        if (list1[0][0])
            first_odd = list1[0];
        else if (list1[1][0])
            first_odd = list1[1];
        else if (list1[2][0])
            first_odd = list1[2];
        else if (list1[3][0])
            first_odd = list1[3];
        else if (list1[4][0])
            first_odd = list1[4];
        else if (list1[5][0])
            first_odd = list1[5];
        else if (list1[6][0])
            first_odd = list1[6];
        else if (list1[7][0])
            first_odd = list1[7];
    end

    // Compute difference
    assign diff = first_even - first_odd;

endmodule