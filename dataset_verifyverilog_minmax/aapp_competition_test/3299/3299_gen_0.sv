module magic_checkerboard_validator(
  input reg [11:0] grid [0:3][0:3],
  output reg valid
);

wire row0_ok = (grid[0][0] < grid[0][1]) && (grid[0][1] < grid[0][2]) && (grid[0][2] < grid[0][3]);
wire row1_ok = (grid[1][0] < grid[1][1]) && (grid[1][1] < grid[1][2]) && (grid[1][2] < grid[1][3]);
wire row2_ok = (grid[2][0] < grid[2][1]) && (grid[2][1] < grid[2][2]) && (grid[2][2] < grid[2][3]);
wire row3_ok = (grid[3][0] < grid[3][1]) && (grid[3][1] < grid[3][2]) && (grid[3][2] < grid[3][3]);
wire rows_ok = row0_ok && row1_ok && row2_ok && row3_ok;

wire col0_ok = (grid[0][0] < grid[1][0]) && (grid[1][0] < grid[2][0]) && (grid[2][0] < grid[3][0]);
wire col1_ok = (grid[0][1] < grid[1][1]) && (grid[1][1] < grid[2][1]) && (grid[2][1] < grid[3][1]);
wire col2_ok = (grid[0][2] < grid[1][2]) && (grid[1][2] < grid[2][2]) && (grid[2][2] < grid[3][2]);
wire col3_ok = (grid[0][3] < grid[1][3]) && (grid[1][3] < grid[2][3]) && (grid[2][3] < grid[3][3]);
wire cols_ok = col0_ok && col1_ok && col2_ok && col3_ok;

wire diag1_ok = (grid[0][0] != grid[1][1]) && 
                (grid[0][1] != grid[1][2]) && 
                (grid[0][2] != grid[1][3]) && 
                (grid[1][0] != grid[2][1]) && 
                (grid[1][1] != grid[2][2]) && 
                (grid[1][2] != grid[2][3]) && 
                (grid[2][0] != grid[3][1]) && 
                (grid[2][1] != grid[3][2]) && 
                (grid[2][2] != grid[3][3]);

wire diag2_ok = (grid[0][1] != grid[1][0]) && 
                (grid[0][2] != grid[1][1]) && 
                (grid[0][3] != grid[1][2]) && 
                (grid[1][1] != grid[2][0]) && 
                (grid[1][2] != grid[2][1]) && 
                (grid[1][3] != grid[2][2]) && 
                (grid[2][1] != grid[3][0]) && 
                (grid[2][2] != grid[3][1]) && 
                (grid[2][3] != grid[3][2]);

wire positive_ok = (grid[0][0] > 0) && (grid[0][1] > 0) && (grid[0][2] > 0) && (grid[0][3] > 0) &&
                   (grid[1][0] > 0) && (grid[1][1] > 0) && (grid[1][2] > 0) && (grid[1][3] > 0) &&
                   (grid[2][0] > 0) && (grid[2][1] > 0) && (grid[2][2] > 0) && (grid[2][3] > 0) &&
                   (grid[3][0] > 0) && (grid[3][1] > 0) && (grid[3][2] > 0) && (grid[3][3] > 0);

always @(*) begin
  valid = rows_ok && cols_ok && diag1_ok && diag2_ok && positive_ok;
end

endmodule