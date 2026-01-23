module prime_fib (
    input [3:0] n,
    output reg [31:0] result
);

    always @(*) begin
        case (n)
            4'd1:    result = 32'h00000002;
            4'd2:    result = 32'h00000003;
            4'd3:    result = 32'h00000005;
            4'd4:    result = 32'h0000000D;
            4'd5:    result = 32'h00000059;
            4'd6:    result = 32'h000000E9;
            4'd7:    result = 32'h0000063D;
            4'd8:    result = 32'h00006FF1;
            default: result = 32'h00000000;
        endcase
    end

endmodule