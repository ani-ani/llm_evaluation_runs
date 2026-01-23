module bomb_disarm(
    input [7:0][7:0] grid,
    output [6:0] max_disarmed
);
wire [3:0] row_counts [0:7];
wire [3:0] col_counts [0:7];
wire [6:0] total_bombs, isolated_count;

assign row_counts[0] = grid[0][0] + grid[0][1] + grid[0][2] + grid[0][3] + grid[0][4] + grid[0][5] + grid[0][6] + grid[0][7];
assign row_counts[1] = grid[1][0] + grid[1][1] + grid[1][2] + grid[1][3] + grid[1][4] + grid[1][5] + grid[1][6] + grid[1][7];
assign row_counts[2] = grid[2][0] + grid[2][1] + grid[2][2] + grid[2][3] + grid[2][4] + grid[2][5] + grid[2][6] + grid[2][7];
assign row_counts[3] = grid[3][0] + grid[3][1] + grid[3][2] + grid[3][3] + grid[3][4] + grid[3][5] + grid[3][6] + grid[3][7];
assign row_counts[4] = grid[4][0] + grid[4][1] + grid[4][2] + grid[4][3] + grid[4][4] + grid[4][5] + grid[4][6] + grid[4][7];
assign row_counts[5] = grid[5][0] + grid[5][1] + grid[5][2] + grid[5][3] + grid[5][4] + grid[5][5] + grid[5][6] + grid[5][7];
assign row_counts[6] = grid[6][0] + grid[6][1] + grid[6][2] + grid[6][3] + grid[6][4] + grid[6][5] + grid[6][6] + grid[6][7];
assign row_counts[7] = grid[7][0] + grid[7][1] + grid[7][2] + grid[7][3] + grid[7][4] + grid[7][5] + grid[7][6] + grid[7][7];

assign col_counts[0] = grid[0][0] + grid[1][0] + grid[2][0] + grid[3][0] + grid[4][0] + grid[5][0] + grid[6][0] + grid[7][0];
assign col_counts[1] = grid[0][1] + grid[1][1] + grid[2][1] + grid[3][1] + grid[4][1] + grid[5][1] + grid[6][1] + grid[7][1];
assign col_counts[2] = grid[0][2] + grid[1][2] + grid[2][2] + grid[3][2] + grid[4][2] + grid[5][2] + grid[6][2] + grid[7][2];
assign col_counts[3] = grid[0][3] + grid[1][3] + grid[2][3] + grid[3][3] + grid[4][3] + grid[5][3] + grid[6][3] + grid[7][3];
assign col_counts[4] = grid[0][4] + grid[1][4] + grid[2][4] + grid[3][4] + grid[4][4] + grid[5][4] + grid[6][4] + grid[7][4];
assign col_counts[5] = grid[0][5] + grid[1][5] + grid[2][5] + grid[3][5] + grid[4][5] + grid[5][5] + grid[6][5] + grid[7][5];
assign col_counts[6] = grid[0][6] + grid[1][6] + grid[2][6] + grid[3][6] + grid[4][6] + grid[5][6] + grid[6][6] + grid[7][6];
assign col_counts[7] = grid[0][7] + grid[1][7] + grid[2][7] + grid[3][7] + grid[4][7] + grid[5][7] + grid[6][7] + grid[7][7];

assign total_bombs = row_counts[0] + row_counts[1] + row_counts[2] + row_counts[3] + row_counts[4] + row_counts[5] + row_counts[6] + row_counts[7];

assign isolated_count = (grid[0][0] & (row_counts[0] == 1) & (col_counts[0] == 1)) + (grid[0][1] & (row_counts[0] == 1) & (col_counts[1] == 1)) + (grid[0][2] & (row_counts[0] == 1) & (col_counts[2] == 1)) + (grid[0][3] & (row_counts[0] == 1) & (col_counts[3] == 1)) + (grid[0][4] & (row_counts[0] == 1) & (col_counts[4] == 1)) + (grid[0][5] & (row_counts[0] == 1) & (col_counts[5] == 1)) + (grid[0][6] & (row_counts[0] == 1) & (col_counts[6] == 1)) + (grid[0][7] & (row_counts[0] == 1) & (col_counts[7] == 1)) + (grid[1][0] & (row_counts[1] == 1) & (col_counts[0] == 1)) + (grid[1][1] & (row_counts[1] == 1) & (col_counts[1] == 1)) + (grid[1][2] & (row_counts[1] == 1) & (col_counts[2] == 1)) + (grid[1][3] & (row_counts[1] == 1) & (col_counts[3] == 1)) + (grid[1][4] & (row_counts[1] == 1) & (col_counts[4] == 1)) + (grid[1][5] & (row_counts[1] == 1) & (col_counts[5] == 1)) + (grid[1][6] & (row_counts[1] == 1) & (col_counts[6] == 1)) + (grid[1][7] & (row_counts[1] == 1) & (col_counts[7] == 1)) + (grid[2][0] & (row_counts[2] == 1) & (col_counts[0] == 1)) + (grid[2][1] & (row_counts[2] == 1) & (col_counts[1] == 1)) + (grid[2][2] & (row_counts[2] == 1) & (col_counts[2] == 1)) + (grid[2][3] & (row_counts[2] == 1) & (col_counts[3] == 1)) + (grid[2][4] & (row_counts[2] == 1) & (col_counts[4] == 1)) + (grid[2][5] & (row_counts[2] == 1) & (col_counts[5] == 1)) + (grid[2][6] & (row_counts[2] == 1) & (col_counts[6] == 1)) + (grid[2][7] & (row_counts[2] == 1) & (col_counts[7] == 1)) + (grid[3][0] & (row_counts[3] == 1) & (col_counts[0] == 1)) + (grid[3][1] & (row_counts[3] == 1) & (col_counts[1] == 1)) + (grid[3][2] & (row_counts[3] == 1) & (col_counts[2] == 1)) + (grid[3][3] & (row_counts[3] == 1) & (col_counts[3] == 1)) + (grid[3][4] & (row_counts[3] == 1) & (col_counts[4] == 1)) + (grid[3][5] & (row_counts[3] == 1) & (col_counts[5] == 1)) + (grid[3][6] & (row_counts[3] == 1) & (col_counts[6] == 1)) + (grid[3][7] & (row_counts[3] == 1) & (col_counts[7] == 1)) + (grid[4][0] & (row_counts[4] == 1) & (col_counts[0] == 1)) + (grid[4][1] & (row_counts[4] == 1) & (col_counts[1] == 1)) + (grid[4][2] & (row_counts[4] == 1) & (col_counts[2] == 1)) + (grid[4][3] & (row_counts[4] == 1) & (col_counts[3] == 1)) + (grid[4][4] & (row_counts[4] == 1) & (col_counts[4] == 1)) + (grid[4][5] & (row_counts[4] == 1) & (col_counts[5] == 1)) + (grid[4][6] & (row_counts[4] == 1) & (col_counts[6] == 1)) + (grid[4][7] & (row_counts[4] == 1) & (col_counts[7] == 1)) + (grid[5][0] & (row_counts[5] == 1) & (col_counts[0] == 1)) + (grid[5][1] & (row_counts[5] == 1) & (col_counts[1] == 1)) + (grid[5][2] & (row_counts[5] == 1) & (col_counts[2] == 1)) + (grid[5][3] & (row_counts[5] == 1) & (col_counts[3] == 1)) + (grid[5][4] & (row_counts[5] == 1) & (col_counts[4] == 1)) + (grid[5][5] & (row_counts[5] == 1) & (col_counts[5] == 1)) + (grid[5][6] & (row_counts[5] == 1) & (col_counts[6] == 1)) + (grid[5][7] & (row_counts[5] == 1) & (col_counts[7] == 1)) + (grid[6][0] & (row_counts[6] == 1) & (col_counts[0] == 1)) + (grid[6][1] & (row_counts[6] == 1) & (col_counts[1] == 1)) + (grid[6][2] & (row_counts[6] == 1) & (col_counts[2] == 1)) + (grid[6][3] & (row_counts[6] == 1) & (col_counts[3] == 1)) + (grid[6][4] & (row_counts[6] == 1) & (col_counts[4] == 1)) + (grid[6][5] & (row_counts[6] == 1) & (col_counts[5] == 1)) + (grid[6][6] & (row_counts[6] == 1) & (col_counts[6] == 1)) + (grid[6][7] & (row_counts[6] == 1) & (col_counts[7] == 1)) + (grid[7][0] & (row_counts[7] == 1) & (col_counts[0] == 1)) + (grid[7][1] & (row_counts[7] == 1) & (col_counts[1] == 1)) + (grid[7][2] & (row_counts[7] == 1) & (col_counts[2] == 1)) + (grid[7][3] & (row_counts[7] == 1) & (col_counts[3] == 1)) + (grid[7][4] & (row_counts[7] == 1) & (col_counts[4] == 1)) + (grid[7][5] & (row_counts[7] == 1) & (col_counts[5] == 1)) + (grid[7][6] & (row_counts[7] == 1) & (col_counts[6] == 1)) + (grid[7][7] & (row_counts[7] == 1) & (col_counts[7] == 1));

assign max_disarmed = total_bombs - isolated_count;

endmodule