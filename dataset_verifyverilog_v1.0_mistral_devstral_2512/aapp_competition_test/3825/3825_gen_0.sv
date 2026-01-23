module roman_digit_count(
    input [31:0] n,
    output reg [63:0] result
);
    always @(*) begin
        if (n >= 12) begin
            result = 64'd49 * n - 64'd247;
        end else begin
            case (n)
                32'd1: result = 64'd4;
                32'd2: result = 64'd10;
                32'd3: result = 64'd20;
                32'd4: result = 64'd35;
                32'd5: result = 64'd56;
                32'd6: result = 64'd83;
                32'd7: result = 64'd116;
                32'd8: result = 64'd155;
                32'd9: result = 64'd198;
                32'd10: result = 64'd244;
                32'd11: result = 64'd292;
                default: result = 64'd0;
            endcase
        end
    end
endmodule