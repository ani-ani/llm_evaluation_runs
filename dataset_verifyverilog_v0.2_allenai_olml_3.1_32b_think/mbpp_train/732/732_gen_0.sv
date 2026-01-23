module replace_specialchar(
    input [127:0] text_in,
    input [7:0] valid_len,
    output [127:0] text_out,
    output [7:0] out_len
);

always_comb begin
    out_len = valid_len;
    generate
    for (int i=0; i<16; i++) begin
        int start_bit = (15 - i)*8 + 7;
        reg [7:0] current_byte;
        current_byte = text_in[start_bit : (15 - i)*8];
        if (current_byte == 8'h20 || current_byte == 8'h2C || current_byte == 8'h2E) begin
            current_byte = 8'h3A;
        end
        text_out[start_bit : (15 - i)*8] = current_byte;
    end
    endgenerate
end

endmodule