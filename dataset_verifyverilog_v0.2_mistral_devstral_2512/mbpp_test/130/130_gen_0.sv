module max_frequency (
    input [7:0] data_in [0:15],
    output [7:0] max_value,
    output [3:0] max_count
);

    // Arrays to store unique values and their counts
    reg [7:0] unique_values [0:15];
    reg [3:0] counts [0:15];

    // Initialize arrays
    integer i, j;
    always @* begin
        // Reset counts and unique_values
        for (i = 0; i < 16; i = i + 1) begin
            counts[i] = 0;
            unique_values[i] = 0;
        end

        // Process each input element
        for (i = 0; i < 16; i = i + 1) begin
            reg match_found = 0;
            // Check against existing unique values
            for (j = 0; j < 16; j = j + 1) begin
                if (counts[j] != 0 && data_in[i] == unique_values[j]) begin
                    counts[j] = counts[j] + 1;
                    match_found = 1;
                end
            end
            // If no match, add as new unique value
            if (!match_found) begin
                for (j = 0; j < 16; j = j + 1) begin
                    if (counts[j] == 0) begin
                        unique_values[j] = data_in[i];
                        counts[j] = 1;
                        break;
                    end
                end
            end
        end

        // Find max count and corresponding value
        reg [3:0] current_max = 0;
        reg [7:0] current_value = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if (counts[i] > current_max) begin
                current_max = counts[i];
                current_value = unique_values[i];
            end
        end

        max_value = current_value;
        max_count = current_max;
    end

endmodule