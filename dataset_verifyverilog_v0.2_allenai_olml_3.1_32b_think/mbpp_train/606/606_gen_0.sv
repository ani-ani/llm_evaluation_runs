module deg_to_rad (
    input [15:0] degree,
    output reg [31:0] radian
);
assign radian = (degree << 8) * 0x477 >> 16;
endmodule