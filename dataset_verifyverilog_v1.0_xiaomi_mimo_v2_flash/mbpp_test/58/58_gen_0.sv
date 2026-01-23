module opposite_signs(
    input signed [7:0] x,
    input signed [7:0] y,
    output reg result
);
    // Combinational logic - XOR of MSBs
    // x[7] is MSB for signed 8-bit, y[7] is MSB for signed 8-bit
    always @(*) begin
        result = x[7] ^ y[7];
    end
endmodule