module StringConcatenator(
    input [7:0] strings [0:7],
    input [2:0] num_strings,
    output [7:0] result [0:63]
);

    integer i, j, k;
    reg [7:0] char;
    reg [5:0] result_index;

    always @(*) begin
        // Initialize result to all zeros
        for (i = 0; i < 64; i = i + 1) begin
            result[i] = 8'd0;
        end

        // If no strings, output remains all zeros
        if (num_strings == 3'd0) begin
            // Already initialized to zeros
        end else begin
            result_index = 6'd0;
            // Iterate through each string
            for (i = 0; i < num_strings; i = i + 1) begin
                // Copy characters until null terminator or max length
                for (j = 0; j < 8; j = j + 1) begin
                    char = strings[i][j];
                    // Check for null terminator
                    if (char == 8'd0) begin
                        // Stop copying this string
                        j = 8; // Exit loop
                    end else if (result_index < 6'd64) begin
                        // Copy character to result
                        result[result_index] = char;
                        result_index = result_index + 6'd1;
                    end else begin
                        // Result is full, stop processing
                        i = num_strings; // Exit outer loop
                        j = 8; // Exit inner loop
                    end
                end
            end
        end
    end

endmodule