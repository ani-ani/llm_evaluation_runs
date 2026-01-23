module majority_check(
    input [2:0] n,
    input [7:0][7:0] arr,
    input [7:0] x,
    output reg result
);

    reg [2:0] first_idx;
    reg found;
    reg [2:0] majority_idx;
    reg [2:0] i;

    // Initialize first_idx to 0 (not found) and found to 0
    always @(*) begin
        first_idx = 3'b0;
        found = 1'b0;
        result = 1'b0;

        // Parallel search for first occurrence of x
        for (i = 0; i < 8; i = i + 1) begin
            if ((arr[i] == x) && ((i == 0) || (arr[i-1] < x))) begin
                first_idx = i;
                found = 1'b1;
            end
        end

        // Calculate majority index
        majority_idx = first_idx + (n >> 1);

        // Check if x is majority
        if (found && (majority_idx < n) && (arr[majority_idx] == x)) begin
            result = 1'b1;
        end
    end

endmodule