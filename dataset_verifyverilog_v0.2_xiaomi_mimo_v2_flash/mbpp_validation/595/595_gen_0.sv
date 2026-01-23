module min_swaps (
    input [15:0] str1,
    input [15:0] str2,
    input [3:0] length,
    output reg [3:0] swaps,
    output reg possible
);

    integer i;
    reg [4:0] mismatch_count;

    always @(*) begin
        // Initialize mismatch count to zero
        mismatch_count = 5'b0;

        // Count mismatches for the specified length (1 to 16)
        // If length is 0, loop does not execute, count remains 0
        for (i = 0; i < 16; i = i + 1) begin
            if (i < length) begin
                if (str1[i] != str2[i]) begin
                    mismatch_count = mismatch_count + 1'b1;
                end
            end
        end

        // Check parity and assign outputs
        if (mismatch_count[0] == 1'b0) begin
            // Even number of mismatches
            swaps = mismatch_count[4:1]; // Integer division by 2 (right shift)
            possible = 1'b1;
        end else begin
            // Odd number of mismatches
            swaps = 4'b0;
            possible = 1'b0;
        end
    end

endmodule