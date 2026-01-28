module GenerateNeighborhoodPoints (
    input [7:0] in_x,
    input [7:0] in_y,
    output reg [7:0] out_x [0:8],
    output reg [7:0] out_y [0:8],
    output reg valid [0:8]
);
    // Row-major order: y varies fastest, then x
    // Index mapping:
    // y=in_y-1: indices 0,1,2 (x=in_x-1,in_x,in_x+1)
    // y=in_y:   indices 3,4,5 (x=in_x-1,in_x,in_x+1)
    // y=in_y+1: indices 6,7,8 (x=in_x-1,in_x,in_x+1)

    always @(*) begin
        // Row 0: y = in_y - 1
        out_x[0] = in_x - 8'd1;
        out_y[0] = in_y - 8'd1;
        valid[0] = 1'b1;

        out_x[1] = in_x;
        out_y[1] = in_y - 8'd1;
        valid[1] = 1'b1;

        out_x[2] = in_x + 8'd1;
        out_y[2] = in_y - 8'd1;
        valid[2] = 1'b1;

        // Row 1: y = in_y
        out_x[3] = in_x - 8'd1;
        out_y[3] = in_y;
        valid[3] = 1'b1;

        out_x[4] = in_x;
        out_y[4] = in_y;
        valid[4] = 1'b1;

        out_x[5] = in_x + 8'd1;
        out_y[5] = in_y;
        valid[5] = 1'b1;

        // Row 2: y = in_y + 1
        out_x[6] = in_x - 8'd1;
        out_y[6] = in_y + 8'd1;
        valid[6] = 1'b1;

        out_x[7] = in_x;
        out_y[7] = in_y + 8'd1;
        valid[7] = 1'b1;

        out_x[8] = in_x + 8'd1;
        out_y[8] = in_y + 8'd1;
        valid[8] = 1'b1;
    end

endmodule