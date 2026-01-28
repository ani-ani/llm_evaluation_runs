module ascii_to_lowercase(
    input [7:0] string_in [0:7],
    output reg [7:0] string_out [0:7]
);
    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            // Check if character is uppercase (A-Z: 0x41 to 0x5A)
            if (string_in[i] >= 8'h41 && string_in[i] <= 8'h5A) begin
                // Convert to lowercase by setting bit 5 (add 0x20)
                string_out[i] = string_in[i] | 8'h20;
            end else begin
                // Pass through unchanged
                string_out[i] = string_in[i];
            end
        end
    end
endmodule