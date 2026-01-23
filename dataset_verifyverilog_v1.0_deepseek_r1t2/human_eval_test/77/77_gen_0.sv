module iscube(
    input signed [7:0] a,
    output reg is_cube
);
    always @(*) begin
        case (a)
            8'sd-64: is_cube = 1'b1;
            8'sd-27: is_cube = 1'b1;
            8'sd-8:  is_cube = 1'b1;
            8'sd-1:  is_cube = 1'b1;
            8'sd0:   is_cube = 1'b1;
            8'sd1:   is_cube = 1'b1;
            8'sd8:   is_cube = 1'b1;
            8'sd27:  is_cube = 1'b1;
            8'sd64:  is_cube = 1'b1;
            default: is_cube = 1'b0;
        endcase
    end
endmodule