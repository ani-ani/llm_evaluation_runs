module string_concatenate (
    input wire [7:0] strings[0:7][7:0],
    input wire [2:0] num_strings,
    output reg [7:0] result[0:63][7:0]
);

    // Local parameters
    localparam [2:0] NUM_STRINGS_MAX = 3'd8;
    localparam [5:0] RESULT_SIZE = 6'd64;
    localparam [7:0] NULL_CHAR = 8'd0;

    // Internal variables for loop processing
    reg [2:0] str_idx;
    reg [2:0] char_idx;
    reg [5:0] result_pos;
    reg [2:0] valid_len;
    reg [5:0] total_len;
    reg processing_done;
    integer i, j;

    always @(*) begin
        // Initialize result array to all zeros
        for (i = 0; i < 64; i = i + 1) begin
            result[i] = NULL_CHAR;
        end

        // Check if num_strings is 0
        if (num_strings == 3'd0) begin
            // Output is all zeros (already initialized)
        end else begin
            result_pos = 6'd0;
            str_idx = 3'd0;
            processing_done = 1'b0;

            // Iterate through each string until num_strings or result is full
            while ((str_idx < num_strings) && (result_pos < RESULT_SIZE) && !processing_done) begin
                // Find valid length of current string (scan for null terminator)
                valid_len = 3'd0;
                for (char_idx = 3'd0; char_idx < 3'd8; char_idx = char_idx + 3'd1) begin
                    if (strings[str_idx][char_idx] == NULL_CHAR) begin
                        // Found null terminator, stop scanning
                        valid_len = char_idx;
                        break;
                    end
                end
                // If no null found, valid_len remains 0
                if (valid_len == 3'd0) begin
                    // Check if all 8 bytes are non-null
                    // If first byte is not null, we need to check if there's any null in remaining
                    // Simplified: If first byte is not null and we didn't find null, valid_len = 8
                    valid_len = 3'd8;
                    // Actually, need to check all 8 positions
                    valid_len = 3'd0;
                    for (char_idx = 3'd0; char_idx < 3'd8; char_idx = char_idx + 3'd1) begin
                        if (strings[str_idx][char_idx] != NULL_CHAR) begin
                            valid_len = char_idx + 3'd1;
                        end else begin
                            break;
                        end
                    end
                end

                // Copy valid characters to result
                for (char_idx = 3'd0; char_idx < valid_len; char_idx = char_idx + 3'd1) begin
                    if (result_pos < RESULT_SIZE) begin
                        result[result_pos] = strings[str_idx][char_idx];
                        result_pos = result_pos + 6'd1;
                    end else begin
                        processing_done = 1'b1;
                    end
                end

                // Move to next string
                str_idx = str_idx + 3'd1;
            end
        end
    end

endmodule