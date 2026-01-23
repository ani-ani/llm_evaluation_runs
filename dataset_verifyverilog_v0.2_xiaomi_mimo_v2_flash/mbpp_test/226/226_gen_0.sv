module odd_index_filter (
    input [7:0] char_array [0:15],
    input [3:0] length,
    output [7:0] result [0:7],
    output [3:0] result_length
);

    // Combinational logic to filter even-indexed characters
    always @(*) begin
        // Initialize result array to zero
        for (int i = 0; i < 8; i++) begin
            result[i] = 8'h00;
        end

        // Calculate result length
        // For input length N, number of even indices is (N + 1) / 2
        result_length = (length + 1) >> 1;

        // Populate result array with even-indexed characters
        // Only process up to the input length
        for (int i = 0; i < length; i++) begin
            if ((i & 1'b0) == 1'b0) begin // Check if index is even (i % 2 == 0)
                result[i >> 1] = char_array[i];
            end
        end
    end

endmodule
