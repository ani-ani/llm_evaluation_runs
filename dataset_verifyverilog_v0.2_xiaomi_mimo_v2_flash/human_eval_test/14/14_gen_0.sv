module all_prefixes (
    input [7:0][7:0] input_string,
    input [2:0] input_length,
    output reg [7:0][7:0] prefixes,
    output reg [2:0] prefix_count
);

    integer i, j;

    always @(*) begin
        // Initialize outputs to zero
        prefixes = 64'b0;
        prefix_count = 3'b0;

        // If input_length is zero, prefix_count remains 0 and prefixes are zeros
        if (input_length > 3'b0) begin
            prefix_count = input_length;

            // Iterate through each prefix
            for (i = 0; i < 8; i = i + 1) begin
                // Only process up to input_length - 1
                if (i < input_length) begin
                    // Copy characters from input_string to prefixes[i]
                    // For prefix index i, we need i+1 characters (indices 0 to i)
                    for (j = 0; j <= i; j = j + 1) begin
                        prefixes[i][j] = input_string[j];
                    end
                    // Remaining bytes in prefixes[i] are already 0 from initialization
                end
            end
        end
    end

endmodule
