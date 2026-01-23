module polygon_count (
    input [1:0] R,
    input [1:0] C,
    output reg [15:0] count
);

always @(*) begin
    case ({R, C})
        4'b0000: count = 16'd1;
        4'b0001: count = 16'd3;
        4'b0010: count = 16'd6;
        4'b0011: count = 16'd10;
        4'b0100: count = 16'd3;
        4'b0101: count = 16'd13;
        4'b0110: count = 16'd41;
        4'b0111: count = 16'd108;
        4'b1000: count = 16'd6;
        4'b1001: count = 16'd41;
        4'b1010: count = 16'd128;
        4'b1011: count = 16'd355;
        4'b1100: count = 16'd10;
        4'b1101: count = 16'd108;
        4'b1110: count = 16'd355;
        4'b1111: count = 16'd1190;
        default: count = 16'd0;
    endcase
end

endmodule