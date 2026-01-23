module replace_specialchar (
    input  [127:0] text_in,
    input  [7:0]   valid_len,
    output [127:0] text_out,
    output [7:0]   out_len
);

    // Output length is always the same as input length
    assign out_len = valid_len;

    // Process 16 bytes in parallel using a generate loop
    generate
        genvar i;
        for (i = 0; i < 16; i = i + 1) begin : gen_byte_replace
            // Extract the current byte (8 bits)
            wire [7:0] current_char = text_in[i*8 +: 8];
            
            // Combinational logic to replace specific characters
            // ASCII 0x20 (space), 0x2C (comma), 0x2E (dot) -> 0x3A (colon)
            // Otherwise keep the original character
            assign text_out[i*8 +: 8] = (
                (current_char == 8'h20) || 
                (current_char == 8'h2C) || 
                (current_char == 8'h2E)
            ) ? 8'h3A : current_char;
        end
    endgenerate

endmodule
