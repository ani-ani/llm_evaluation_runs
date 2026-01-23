module ascii_value (
    input  [7:0] char_in,
    output [7:0] ascii_out
);

    // The input is already the ASCII representation.
    // Pass the input directly to the output combinationally.
    assign ascii_out = char_in;

endmodule