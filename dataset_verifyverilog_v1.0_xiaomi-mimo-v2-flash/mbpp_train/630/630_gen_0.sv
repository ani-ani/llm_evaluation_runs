module neighbor_generator (
    input [7:0] x,
    input [7:0] y,
    output reg [71:0] neighbors_x,
    output reg [71:0] neighbors_y,
    output reg valid
);
    // Wrap-around addition for 8-bit unsigned
    // x-1: (x - 1) mod 256
    // x+1: (x + 1) mod 256
    // Using wrap-around arithmetic with 8-bit registers
    
    always @(*) begin
        // Initialize valid signal (combinational)
        valid = 1'b1;
        
        // Generate 9 neighbors in row-major order
        // Order: (x-1,y-1), (x-1,y), (x-1,y+1), (x,y-1), (x,y), (x,y+1), (x+1,y-1), (x+1,y), (x+1,y+1)
        
        // Row 0: y-1 (wraps around)
        neighbors_x[7:0]   = x - 8'd1;    // (x-1, y-1)
        neighbors_y[7:0]   = y - 8'd1;
        neighbors_x[15:8]  = x - 8'd1;    // (x-1, y)
        neighbors_y[15:8]  = y;
        neighbors_x[23:16] = x - 8'd1;    // (x-1, y+1)
        neighbors_y[23:16] = y + 8'd1;
        
        // Row 1: y (center)
        neighbors_x[31:24] = x;           // (x, y-1)
        neighbors_y[31:24] = y - 8'd1;
        neighbors_x[39:32] = x;           // (x, y)
        neighbors_y[39:32] = y;
        neighbors_x[47:40] = x;           // (x, y+1)
        neighbors_y[47:40] = y + 8'd1;
        
        // Row 2: y+1 (wraps around)
        neighbors_x[55:48] = x + 8'd1;    // (x+1, y-1)
        neighbors_y[55:48] = y - 8'd1;
        neighbors_x[63:56] = x + 8'd1;    // (x+1, y)
        neighbors_y[63:56] = y;
        neighbors_x[71:64] = x + 8'd1;    // (x+1, y+1)
        neighbors_y[71:64] = y + 8'd1;
    end
    
endmodule