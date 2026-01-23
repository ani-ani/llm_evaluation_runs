module string_extractor (
    input  [7:0][7:0] strings,
    input       [2:0] target_len,
    input       [4:0] valid_mask,
    output reg  [7:0][7:0] result,
    output reg  [4:0] result_mask
);

    integer i;
    integer j;
    integer k;
    integer len;
    integer match_count;
    reg     [7:0] char;

    always @(*) begin
        // Initialize outputs
        for (k = 0; k < 8; k = k + 1) begin
            result[k] = 8'h00;
        end
        result_mask = 5'b00000;
        match_count = 0;

        // Iterate through the first 5 strings
        for (i = 0; i < 5; i = i + 1) begin
            // Only process if the string is marked valid in the input mask
            if (valid_mask[i]) begin
                // Calculate string length
                len = 0;
                for (j = 0; j < 8; j = j + 1) begin
                    char = strings[i][j];
                    if (char != 8'h00) begin
                        len = j + 1; // Length is index + 1
                    end
                end

                // Check if length matches target
                if (len == target_len) begin
                    // Copy matching string to result at current match position
                    if (match_count < 8) begin
                        result[match_count] = strings[i];
                        // Only set the result mask if we are within the first 5 entries
                        // to match the "5 test strings" requirement, though spec says 8 output entries.
                        // Assuming result_mask tracks the 5 specific slots or valid outputs.
                        // Based on context, result_mask corresponds to the result array entries.
                        // However, to match the specific output requirement: 
                        // "Extracted strings in order" implies dense packing.
                        // The result_mask output requirement likely implies mapping to the 5 slots 
                        // if the system expects 5 outputs, or simply marking valid entries in the 8-wide result.
                        // Given the input is 5 valid strings, and output mask is 5 bits, 
                        // this usually maps to the first N entries.
                        // We will set the mask bit at the match_count index (capped at 4).
                        if (match_count < 5) begin
                            result_mask[match_count] = 1'b1;
                        end
                        match_count = match_count + 1;
                    end
                end
            end
        end
    end

endmodule