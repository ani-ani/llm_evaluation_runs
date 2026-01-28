module is_sorted(
    input [7:0] arr [0:7],
    output reg result
);

    // Internal signals for checking conditions
    reg sorted_ok;
    reg no_more_than_one_duplicate;

    // Check 1: Array sorted in non-decreasing order
    // Check arr[i] <= arr[i+1] for i = 0 to 6
    always @(*) begin
        sorted_ok = 1'b1; // Assume sorted initially
        if (arr[0] > arr[1]) sorted_ok = 1'b0;
        if (arr[1] > arr[2]) sorted_ok = 1'b0;
        if (arr[2] > arr[3]) sorted_ok = 1'b0;
        if (arr[3] > arr[4]) sorted_ok = 1'b0;
        if (arr[4] > arr[5]) sorted_ok = 1'b0;
        if (arr[5] > arr[6]) sorted_ok = 1'b0;
        if (arr[6] > arr[7]) sorted_ok = 1'b0;
    end

    // Check 2: No number appears more than once (max 1 duplicate)
    // Since the array is sorted, duplicates must be adjacent.
    // We check if any value appears more than twice in a row.
    always @(*) begin
        no_more_than_one_duplicate = 1'b1;
        // Check for patterns like [x, x, x] (x appears 3+ times)
        if (arr[0] == arr[1] && arr[1] == arr[2]) no_more_than_one_duplicate = 1'b0;
        if (arr[1] == arr[2] && arr[2] == arr[3]) no_more_than_one_duplicate = 1'b0;
        if (arr[2] == arr[3] && arr[3] == arr[4]) no_more_than_one_duplicate = 1'b0;
        if (arr[3] == arr[4] && arr[4] == arr[5]) no_more_than_one_duplicate = 1'b0;
        if (arr[4] == arr[5] && arr[5] == arr[6]) no_more_than_one_duplicate = 1'b0;
        if (arr[5] == arr[6] && arr[6] == arr[7]) no_more_than_one_duplicate = 1'b0;
    end

    // Final Output: Both conditions must be met
    always @(*) begin
        result = sorted_ok && no_more_than_one_duplicate;
    end

endmodule