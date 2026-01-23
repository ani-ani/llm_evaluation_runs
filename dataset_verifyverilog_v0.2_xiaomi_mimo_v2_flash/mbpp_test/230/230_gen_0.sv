module replace_blank (
    input [127:0] str_in,
    input [7:0] char_in,
    output [127:0] str_out
);

    // Generate block to process each of the 16 bytes independently
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_replace
            // Extract current byte from input
            wire [7:0] current_byte = str_in[(i*8)+7 : (i*8)];
            // Assign output byte: replace space with char_in, otherwise keep original
            assign str_out[(i*8)+7 : (i*8)] = (current_byte == 8'h20) ? char_in : current_byte;
        end
    endgenerate

endmodule
