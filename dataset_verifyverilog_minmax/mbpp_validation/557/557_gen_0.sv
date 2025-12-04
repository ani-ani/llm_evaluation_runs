module toggle_case (
    input [63:0] str_in,
    output [63:0] str_out
);

    // Combinational case toggling for each of the 8 bytes
    integer i;
    always @* begin
        for (i = 0; i < 8; i = i + 1) begin
            logic [7:0] c;
            c = str_in[(i*8) +: 8];
            if (c >= 8'd65 && c <= 8'd90) begin
                // Uppercase (A-Z) -> lowercase (a-z)
                str_out[(i*8) +: 8] = c + 8'd32;
            end
            else if (c >= 8'd97 && c <= 8'd122) begin
                // Lowercase (a-z) -> uppercase (A-Z)
                str_out[(i*8) +: 8] = c - 8'd32;
            end
            else begin
                // Other characters unchanged
                str_out[(i*8) +: 8] = c;
            end
        end
    end

endmodule