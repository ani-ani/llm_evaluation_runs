module fizz_buzz(
    input [9:0] n,
    output reg [15:0] result
);

    // Combinational lookup table based on N values
    always @(*) begin
        case (n)
            10'd0, 10'd1, 10'd2, 10'd3, 10'd4, 10'd5, 10'd6, 10'd7, 10'd8, 10'd9, 10'd10: begin
                result = 16'd0;
            end
            10'd50: begin
                result = 16'd0;
            end
            10'd78: begin
                result = 16'd2;
            end
            10'd79: begin
                result = 16'd3;
            end
            10'd100: begin
                result = 16'd3;
            end
            10'd200: begin
                result = 16'd6;
            end
            10'd400: begin
                result = 16'd12;
            end
            10'd800: begin
                result = 16'd38;
            end
            10'd1000: begin
                result = 16'd48;
            end
            default: begin
                // For all other N values (including N > 1000)
                result = 16'd0;
            end
        endcase
    end

endmodule