module neighbor_generator(
    input [7:0] x,
    input [7:0] y,
    output [71:0] neighbors_x,
    output [71:0] neighbors_y,
    output valid
);

    // Generate all 9 neighbors in row-major order
    // Neighbor order: (x-1,y-1), (x-1,y), (x-1,y+1), (x,y-1), (x,y), (x,y+1), (x+1,y-1), (x+1,y), (x+1,y+1)
    
    // Helper wires for wrapped coordinates
    wire [7:0] x_minus_1 = x - 8'd1;  // Wraps to 255 when x=0
    wire [7:0] x_plus_1 = x + 8'd1;   // Wraps to 0 when x=255
    wire [7:0] y_minus_1 = y - 8'd1;  // Wraps to 255 when y=0
    wire [7:0] y_plus_1 = y + 8'd1;   // Wraps to 0 when y=255

    // Assign each neighbor coordinate to the packed output arrays
    assign neighbors_x[7:0]   = x_minus_1;  // (x-1,y-1)
    assign neighbors_x[15:8]  = x_minus_1;  // (x-1,y)
    assign neighbors_x[23:16] = x_minus_1;  // (x-1,y+1)
    assign neighbors_x[31:24] = x;          // (x,y-1)
    assign neighbors_x[39:32] = x;          // (x,y)
    assign neighbors_x[47:40] = x;          // (x,y+1)
    assign neighbors_x[55:48] = x_plus_1;   // (x+1,y-1)
    assign neighbors_x[63:56] = x_plus_1;   // (x+1,y)
    assign neighbors_x[71:64] = x_plus_1;   // (x+1,y+1)

    assign neighbors_y[7:0]   = y_minus_1;  // (x-1,y-1)
    assign neighbors_y[15:8]  = y;          // (x-1,y)
    assign neighbors_y[23:16] = y_plus_1;   // (x-1,y+1)
    assign neighbors_y[31:24] = y_minus_1;  // (x,y-1)
    assign neighbors_y[39:32] = y;          // (x,y)
    assign neighbors_y[47:40] = y_plus_1;   // (x,y+1)
    assign neighbors_y[55:48] = y_minus_1;  // (x+1,y-1)
    assign neighbors_y[63:56] = y;          // (x+1,y)
    assign neighbors_y[71:64] = y_plus_1;   // (x+1,y+1)

    // Valid signal is always 1 for combinational output
    assign valid = 1'b1;

endmodule