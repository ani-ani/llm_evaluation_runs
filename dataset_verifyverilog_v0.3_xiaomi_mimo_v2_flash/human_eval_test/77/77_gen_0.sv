module iscube(
    input signed [7:0] a,
    output reg is_cube
);
    always @(*) begin
        case (a)
            8'sd-64,
            8'sd-27,
            8'sd-8,
            8'sd-1,
            8'sd0,
            8'sd1,
            8'sd8,
            8'sd27,
            8'sd64: is_cube = 1'b1;
            default: is_cube = 1'b0;
        endcase
    end
endmodule