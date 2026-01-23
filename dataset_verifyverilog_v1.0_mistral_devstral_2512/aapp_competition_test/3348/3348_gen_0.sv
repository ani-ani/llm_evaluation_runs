module bonbon_arrangement(
    input [4:0] a, b, c,
    output valid,
    output wire [1:0] grid [0:3][0:3]
);

// Check if counts are permutation of (6,5,5)
wire cond1 = (a == 5'd5 && b == 5'd5 && c == 5'd6);
wire cond2 = (a == 5'd5 && b == 5'd6 && c == 5'd5);
wire cond3 = (a == 5'd6 && b == 5'd5 && c == 5'd5);
assign valid = cond1 || cond2 || cond3;

// Determine which color has count 6
wire color0_is_A = (a == 5'd6);
wire color0_is_B = (b == 5'd6);
wire color0_is_C = (c == 5'd6);

// Color mappings
wire [1:0] color0 = color0_is_A ? 2'b00 : (color0_is_B ? 2'b01 : 2'b10);
wire [1:0] color1 = color0_is_A ? 2'b01 : (color0_is_B ? 2'b00 : 2'b00);
wire [1:0] color2 = color0_is_A ? 2'b10 : (color0_is_B ? 2'b10 : 2'b01);

// Generate grid
reg [1:0] grid_reg [0:3][0:3];
integer i, j;
always @(*) begin
    for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
            wire [2:0] sum = i + j;
            wire [1:0] r;
            assign r = (sum < 3) ? sum[1:0] : (sum < 6) ? (sum - 3) : (sum - 6);
            grid_reg[i][j] = valid ? 
                            (r == 2'b00 ? color0 : 
                             r == 2'b01 ? color1 : color2) 
                           : 2'b00;
        end
    end
end

assign grid[0][0] = grid_reg[0][0];
assign grid[0][1] = grid_reg[0][1];
assign grid[0][2] = grid_reg[0][2];
assign grid[0][3] = grid_reg[0][3];
assign grid[1][0] = grid_reg[1][0];
assign grid[1][1] = grid_reg[1][1];
assign grid[1][2] = grid_reg[1][2];
assign grid[1][3] = grid_reg[1][3];
assign grid[2][0] = grid_reg[2][0];
assign grid[2][1] = grid_reg[2][1];
assign grid[2][2] = grid_reg[2][2];
assign grid[2][3] = grid_reg[2][3];
assign grid[3][0] = grid_reg[3][0];
assign grid[3][1] = grid_reg[3][1];
assign grid[3][2] = grid_reg[3][2];
assign grid[3][3] = grid_reg[3][3];

endmodule