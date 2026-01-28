module NeighborhoodGenerator(
    input [7:0] in_x,
    input [7:0] in_y,
    output [7:0] out_x [0:8],
    output [7:0] out_y [0:8],
    output [0:8] valid
);

    integer i;
    always @(*) begin
        for (i = 0; i < 9; i = i + 1) begin
            out_x[i] = in_x + (i / 3) - 1;
            out_y[i] = in_y + (i % 3) - 1;
            valid[i] = 1'b1;
        end
    end

endmodule