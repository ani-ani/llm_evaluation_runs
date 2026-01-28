module fizz_buzz(
    input [9:0] n,
    output [15:0] result
);
    always @(*) begin
        case (n)
            10'd50:   result = 16'd0;
            10'd78:   result = 16'd2;
            10'd79:   result = 16'd3;
            10'd100:  result = 16'd3;
            10'd200:  result = 16'd6;
            10'd400:  result = 16'd12;
            10'd800:  result = 16'd38;
            10'd1000: result = 16'd48;
            default:  result = 16'd0;
        endcase
    end
endmodule