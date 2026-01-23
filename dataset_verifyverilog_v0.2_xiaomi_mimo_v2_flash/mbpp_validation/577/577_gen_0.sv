module factorial_last_digit (
    input [7:0] n,
    output reg [3:0] last_digit
);

    always @(*) begin
        case(n)
            8'd0: last_digit = 4'd1;
            8'd1: last_digit = 4'd1;
            8'd2: last_digit = 4'd2;
            8'd3: last_digit = 4'd6;
            8'd4: last_digit = 4'd4;
            default: last_digit = 4'd0;
        endcase
    end

endmodule