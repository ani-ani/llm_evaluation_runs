module opponent_location(
    input [9:0] l,
    output reg [63:0] result_fixed
);

    localparam [63:0] INV_PI_E_FIXED = 64'd503000000;

    wire [63:0] l_squared = $signed(l) * $signed(l);
    wire [63:0] term1 = l_squared * INV_PI_E_FIXED;
    wire [63:0] denom = $signed(l) + 64'd1;
    wire [63:0] term2 = ((64'd1 << 32) + (denom >> 1)) / denom;

    always @(*) begin
        result_fixed = term1 + term2;
    end

endmodule