module magic_checkerboard_validator(
  input  [11:0] grid [0:3][0:3],
  output reg    valid
);

  integer i, j;
  reg rows_ok;
  reg cols_ok;
  reg diag_parity_ok;
  reg positive_ok;

  always @* begin
    rows_ok        = 1'b1;
    cols_ok        = 1'b1;
    diag_parity_ok = 1'b1;
    positive_ok    = 1'b1;

    // Check positivity of all cells
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        if (grid[i][j] == 12'd0)
          positive_ok = 1'b0;
      end
    end

    // Check rows strictly increasing left-to-right
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 3; j = j + 1) begin
        if (!(grid[i][j] < grid[i][j+1]))
          rows_ok = 1'b0;
      end
    end

    // Check columns strictly increasing top-to-bottom
    for (j = 0; j < 4; j = j + 1) begin
      for (i = 0; i < 3; i = i + 1) begin
        if (!(grid[i][j] < grid[i+1][j]))
          cols_ok = 1'b0;
      end
    end

    // Check diagonal neighbors (only-corner-sharing) have opposite parity
    for (i = 0; i < 3; i = i + 1) begin
      for (j = 0; j < 3; j = j + 1) begin
        // (i,j) with (i+1,j+1)
        if ( ((grid[i][j]     ^ grid[i+1][j+1]) & 12'd1) == 1'b0 )
          diag_parity_ok = 1'b0;
        // (i,j+1) with (i+1,j)
        if ( ((grid[i][j+1]   ^ grid[i+1][j])   & 12'd1) == 1'b0 )
          diag_parity_ok = 1'b0;
      end
    end

    valid = rows_ok & cols_ok & diag_parity_ok & positive_ok;
  end

endmodule