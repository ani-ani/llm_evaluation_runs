module max_fill_grid(
  input  [15:0] grid,
  input  [3:0]  capacity,
  output [4:0]  total_trips
);

  // Row segments
  wire [3:0] row0 = grid[15:12];
  wire [3:0] row1 = grid[11:8];
  wire [3:0] row2 = grid[7:4];
  wire [3:0] row3 = grid[3:0];

  // Popcount for each 4-bit row
  wire [2:0] cnt0 = row0[0] + row0[1] + row0[2] + row0[3];
  wire [2:0] cnt1 = row1[0] + row1[1] + row1[2] + row1[3];
  wire [2:0] cnt2 = row2[0] + row2[1] + row2[2] + row2[3];
  wire [2:0] cnt3 = row3[0] + row3[1] + row3[2] + row3[3];

  // Extend counts to avoid overflow in addition with capacity
  wire [4:0] cnt0_ext = {2'b00, cnt0};
  wire [4:0] cnt1_ext = {2'b00, cnt1};
  wire [4:0] cnt2_ext = {2'b00, cnt2};
  wire [4:0] cnt3_ext = {2'b00, cnt3};

  // Extended capacity for arithmetic
  wire [4:0] cap_ext = {1'b0, capacity};

  // Trips per row using ceil(a/b) = (a + b - 1)/b, with zero-check
  wire [4:0] adj0 = (cnt0_ext == 5'd0) ? 5'd0 : (cnt0_ext + cap_ext - 5'd1);
  wire [4:0] adj1 = (cnt1_ext == 5'd0) ? 5'd0 : (cnt1_ext + cap_ext - 5'd1);
  wire [4:0] adj2 = (cnt2_ext == 5'd0) ? 5'd0 : (cnt2_ext + cap_ext - 5'd1);
  wire [4:0] adj3 = (cnt3_ext == 5'd0) ? 5'd0 : (cnt3_ext + cap_ext - 5'd1);

  wire [4:0] trips0 = (cnt0_ext == 5'd0) ? 5'd0 : (adj0 / cap_ext);
  wire [4:0] trips1 = (cnt1_ext == 5'd0) ? 5'd0 : (adj1 / cap_ext);
  wire [4:0] trips2 = (cnt2_ext == 5'd0) ? 5'd0 : (adj2 / cap_ext);
  wire [4:0] trips3 = (cnt3_ext == 5'd0) ? 5'd0 : (adj3 / cap_ext);

  // Sum of trips for all rows
  assign total_trips = trips0 + trips1 + trips2 + trips3;

endmodule