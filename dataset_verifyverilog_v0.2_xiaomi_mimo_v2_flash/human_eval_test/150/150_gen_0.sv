module x_or_y(
    input [3:0] n,
    input [31:0] x,
    input [31:0] y,
    output reg [31:0] result
);

    always @(*) begin
        case (n)
            4'd2, 4'd3, 4'd5, 4'd7, 4'd11, 4'd13: result = x;
            default: result = y;
        endcase
    end

endmodule