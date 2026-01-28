module cube_volume(
    input [7:0] side_length,
    output reg [23:0] volume
);

// Calculate volume = side_length³
// side_length: 8-bit unsigned (0-255)
// volume: 24-bit unsigned (max 255³ = 16,581,375 fits in 24 bits)
// Combinational logic

always @(*) begin
    volume = side_length * side_length * side_length;
end

endmodule