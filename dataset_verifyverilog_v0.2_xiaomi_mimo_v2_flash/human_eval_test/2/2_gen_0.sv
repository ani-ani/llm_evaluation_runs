module truncate_number (
    input [31:0] number_in,
    output [31:0] decimal_out
);
    // In Q16.16 format, integer part is bits [31:16], fractional part is bits [15:0]
    // To extract the decimal part, we keep only the fractional bits (lower 16 bits)
    // and zero-extend to 32 bits for output in Q16.16 format.
    assign decimal_out = {16'b0, number_in[15:0]};
endmodule