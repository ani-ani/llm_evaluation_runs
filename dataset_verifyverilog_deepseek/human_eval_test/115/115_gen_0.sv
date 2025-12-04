module max_fill_grid(
  input [15:0] grid,
  input [3:0] capacity,
  output [4:0] total_trips
);

  wire [3:0] row3 = grid[15:12];
  wire [3:0] row2 = grid[11:8];
  wire [3:0] row1 = grid[7:4];
  wire [3:0] row0 = grid[3:0];

  wire [3:0] count3 = row3[3] + row3[2] + row3[1] + row3[0];
  wire [3:0] count2 = row2[3] + row2[2] + row2[1] + row2[0];
  wire [3:0] count1 = row1[3] + row1[2] + row1[1] + row1[0];
  wire [3:0] count0 = row0[3] + row0[2] + row0[1] + row0[0];

  wire [3:0] sum3 = count3 + capacity - 4'd1;
  wire [3:0] sum2 = count2 + capacity - 4'd1;
  wire [3:0] sum1 = count1 + capacity - 4'd1;
  wire [3:0] sum0 = count0 + capacity - 4'd1;

  wire [3:0] trips3 = (count3 == 4'd0) ? 4'd0 : sum3 / capacity;
  wire [3:0] trips2 = (count2 == 4'd0) ? 4'd0 : sum2 / capacity;
  wire [3:0] trips1 = (count1 == 4'd0) ? 4'd0 : sum1 / capacity;
  wire [3:0] trips0 = (count0 == 4'd0) ? 4'd0 : sum0 / capacity;

  assign total_trips = {1'b0, trips3} + {1'b0, trips2} + {1'b0, trips1} + {1'b0, trips0};

endmodule