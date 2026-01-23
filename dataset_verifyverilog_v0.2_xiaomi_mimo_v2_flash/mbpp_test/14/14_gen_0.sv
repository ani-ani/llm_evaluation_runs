module triangular_prism_volume (
    input [15:0] l,
    input [15:0] b,
    input [15:0] h,
    output reg [15:0] volume
);

    // Intermediate wire for 48-bit product: l * b * h
    wire [47:0] product;
    assign product = l * b * h;

    // Combinational logic: divide by 2 and truncate to 16 bits
    always @(*) begin
        volume = product[47:1]; // Right shift by 1 to divide by 2
    end

endmodule