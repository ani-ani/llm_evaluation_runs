module bomb_disarm (
  input [7:0] grid [0:7][0:7],
  output [6:0] max_disarmed
);

  wire [3:0] row_count [0:7];
  wire [3:0] col_count [0:7];
  wire [6:0] total_bombs;
  wire [6:0] isolated_singletons;
  wire [6:0] disarmable;

  integer i, j;

  // Count bombs per row
  for (i = 0; i < 8; i = i + 1) begin : row_counter
    wire [3:0] count = 0;
    for (j = 0; j < 8; j = j + 1) begin : row_bit_counter
      assign count = count + grid[i][j];
    end
    assign row_count[i] = count;
  end

  // Count bombs per column
  for (j = 0; j < 8; j = j + 1) begin : col_counter
    wire [3:0] count = 0;
    for (i = 0; i < 8; i = i + 1) begin : col_bit_counter
      assign count = count + grid[i][j];
    end
    assign col_count[j] = count;
  end

  // Count total bombs
  assign total_bombs = 0;
  for (i = 0; i < 8; i = i + 1) begin
    for (j = 0; j < 8; j = j + 1) begin
      assign total_bombs = total_bombs + grid[i][j];
    end
  end

  // Count isolated singletons (row_count == 1 AND col_count == 1)
  assign isolated_singletons = 0;
  for (i = 0; i < 8; i = i + 1) begin
    for (j = 0; j < 8; j = j + 1) begin
      assign isolated_singletons = isolated_singletons + 
        (grid[i][j] & (row_count[i] == 1) & (col_count[j] == 1));
    end
  end

  // Count disarmable buildings (row_count > 1 OR col_count > 1)
  assign disarmable = 0;
  for (i = 0; i < 8; i = i + 1) begin
    for (j = 0; j < 8; j = j + 1) begin
      assign disarmable = disarmable + 
        (grid[i][j] & ((row_count[i] > 1) | (col_count[j] > 1)));
    end
  end

  // Final output: total_bombs - isolated_singletons
  assign max_disarmed = total_bombs - isolated_singletons;

endmodule