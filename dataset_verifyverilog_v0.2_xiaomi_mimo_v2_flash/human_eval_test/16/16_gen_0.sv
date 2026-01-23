module count_distinct_characters (
    input [127:0] char_array,
    input [3:0] length,
    output reg [3:0] distinct_count
);

    // Internal wires to store normalized characters
    wire [7:0] norm_char [15:0];
    wire [15:0] is_present;

    genvar i, j;

    // 1. Character Normalization
    // Generate block iterates through all 16 positions
    // If character is lowercase (0x61-0x7A), subtract 0x20
    // Otherwise keep as is
    generate
        for (i = 0; i < 16; i = i + 1) begin : normalize_loop
            wire [7:0] raw_char = char_array[i*8 +: 8];
            assign norm_char[i] = (raw_char >= 8'h61 && raw_char <= 8'h7A) ? (raw_char - 8'h20) : raw_char;
        end
    endgenerate

    // 2. Distinctness Check Logic
    // Iterate through each position (0 to 15).
    // A character at position 'idx' is considered 'new' (distinct) if:
    //   a. idx < length (it is part of the string)
    //   b. For all j < idx, norm_char[idx] != norm_char[j]
    generate
        for (i = 0; i < 16; i = i + 1) begin : check_loop
            wire [7:0] current_char = norm_char[i];
            wire [i-1:0] matches;
            
            if (i > 0) begin
                // Compare with all previous characters
                for (j = 0; j < i; j = j + 1) begin : compare_loop
                    assign matches[j] = (current_char == norm_char[j]);
                end
                // If no matches found among previous characters and within valid length
                assign is_present[i] = (i < length) && (matches == 0);
            end else begin
                // First character is always distinct if valid length >= 1
                assign is_present[0] = (length > 0);
            end
        end
    endgenerate

    // 3. Count distinct characters (OR Reduction)
    always @(*) begin
        distinct_count = 4'd0;
        // Synthesis tools optimize this loop into a popcount / adder tree
        for (int k = 0; k < 16; k = k + 1) begin
            distinct_count = distinct_count + {3'b0, is_present[k]};
        end
    end

endmodule
