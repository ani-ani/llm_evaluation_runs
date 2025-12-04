module magic_checkerboard_validator(
  input [11:0] grid [0:3][0:3],
  output reg valid
);
  always_comb begin
    logic rows_ok, cols_ok, diag_ok, no_zero;
    rows_ok = 1'b1;
    for (int i=0; i<4; i++) begin
      for (int j=0; j<3; j++) begin
        rows_ok = rows_ok && (grid[i][j] < grid[i][j+1]);
      end
    end
    cols_ok = 1'b1;
    for (int j=0; j<4; j++) begin
      for (int i=0; i<3; i++) begin
        cols_ok = cols_ok && (grid[i][j] < grid[i+1][j]);
      end
    end
    no_zero = 1'b1;
    for (int i=0; i<4; i++) begin
      for (int j=0; j<4; j++) begin
        no_zero = no_zero && (grid[i][j] != '0);
      end
    end
    diag_ok = 1'b1;
    for (int i=0; i<3; i++) begin
      for (int j=0; j<3; j++) begin
        diag_ok = diag_ok && (grid[i][j][0] ^ grid[i+1][j+1][0]);
      end
    end
    for (int i=0; i<3; i++) begin
      for (int j=1; j<4; j++) begin
        diag_ok = diag_ok && (grid[i][j][0] ^ grid[i+1][j-1][0]);
      end
    end
    valid = rows_ok && cols_ok && diag_ok && no_zero;
  end
endmodule