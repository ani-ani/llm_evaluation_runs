module remove_whitespaces(
    input [7:0][7:0] text_in,
    input [3:0] length_in,
    output [7:0][7:0] text_out,
    output [3:0] length_out
);

    // Internal signals for combinational logic
    reg [7:0] out_chars [0:7];
    reg [3:0] out_len;
    integer i, j;

    always @(*) begin
        j = 0;
        out_len = 0;
        // Initialize output array to 0 (or don't care, but 0 is safe)
        for (int k = 0; k < 8; k = k + 1) begin
            out_chars[k] = 8'h00;
        end
        
        // Iterate through input based on specified length
        for (i = 0; i < 8; i = i + 1) begin
            if (i < length_in) begin
                // Check for whitespace (ASCII 0x20)
                if (text_in[i] != 8'h20) begin
                    if (j < 8) begin
                        out_chars[j] = text_in[i];
                        j = j + 1;
                    end
                end
            end
        end
        out_len = j;
    end

    assign text_out = {out_chars[0], out_chars[1], out_chars[2], out_chars[3], 
                       out_chars[4], out_chars[5], out_chars[6], out_chars[7]};
    assign length_out = out_len;

endmodule