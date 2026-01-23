module woodall_check(
    input [15:0] num,
    output reg is_woodall
);

    always @(*) begin
        case(num)
            16'h0001, 16'h0007, 16'h0017, 16'h003F, 16'h009F, 16'h017F, 16'h037F, 16'h07FF, 16'h11FF, 16'h27FF, 16'h57FF, 16'hBFFF: is_woodall = 1'b1;
            default: is_woodall = 1'b0;
        endcase
    end

endmodule