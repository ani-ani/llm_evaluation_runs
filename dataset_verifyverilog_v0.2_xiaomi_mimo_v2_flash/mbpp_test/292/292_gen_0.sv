module integer_division (
    input [15:0] dividend,
    input [15:0] divisor,
    output reg [15:0] quotient
);

    always @(*) begin
        quotient = dividend / divisor;
    end

endmodule