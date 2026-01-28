module remove_duplicates (
    input [7:0] numbers [0:7],
    input [3:0] length,
    output reg [7:0] result [0:7],
    output reg [3:0] result_length
);

    integer i, j;
    reg is_duplicate;

    always @(*) begin
        // Initialize outputs
        for (i = 0; i < 8; i = i + 1) begin
            result[i] = 8'd0;
        end
        result_length = 4'd0;

        // Process each element up to specified length
        for (i = 0; i < 8; i = i + 1) begin
            is_duplicate = 1'b0;

            // Only process elements within valid length
            if (i < length) begin
                // Check against all other elements
                for (j = 0; j < 8; j = j + 1) begin
                    if (j != i && j < length) begin
                        if (numbers[j] == numbers[i]) begin
                            is_duplicate = 1'b1;
                        end
                    end
                end

                // Add to result if not duplicate
                if (!is_duplicate) begin
                    result[result_length] = numbers[i];
                    result_length = result_length + 4'd1;
                end
            end
        end
    end

endmodule