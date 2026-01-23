module string_to_upper (
    input  [7:0][7:0] input_string,
    output [7:0][7:0] result
);

    // Generate block to process each of the 8 bytes independently
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_uppercase
            // Check if the byte is a lowercase letter (0x61 to 0x7A)
            // If yes, clear bit 5 (AND with 8'hDF)
            // If no, pass through the original byte
            assign result[i] = (input_string[i] >= 8'h61 && input_string[i] <= 8'h7A) ? 
                              (input_string[i] & 8'hDF) : 
                              input_string[i];
        end
    endgenerate

endmodule