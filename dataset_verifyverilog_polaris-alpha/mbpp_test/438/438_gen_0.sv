module bidirectional_counter(
  input  [15:0] tuples [0:7],
  output reg [4:0] count
);

  always @* begin
    count = 5'd0;

    // (0,1)
    if ((tuples[0][15:8] == tuples[1][7:0]) && (tuples[0][7:0] == tuples[1][15:8]))
      count = count + 5'd1;
    // (0,2)
    if ((tuples[0][15:8] == tuples[2][7:0]) && (tuples[0][7:0] == tuples[2][15:8]))
      count = count + 5'd1;
    // (0,3)
    if ((tuples[0][15:8] == tuples[3][7:0]) && (tuples[0][7:0] == tuples[3][15:8]))
      count = count + 5'd1;
    // (0,4)
    if ((tuples[0][15:8] == tuples[4][7:0]) && (tuples[0][7:0] == tuples[4][15:8]))
      count = count + 5'd1;
    // (0,5)
    if ((tuples[0][15:8] == tuples[5][7:0]) && (tuples[0][7:0] == tuples[5][15:8]))
      count = count + 5'd1;
    // (0,6)
    if ((tuples[0][15:8] == tuples[6][7:0]) && (tuples[0][7:0] == tuples[6][15:8]))
      count = count + 5'd1;
    // (0,7)
    if ((tuples[0][15:8] == tuples[7][7:0]) && (tuples[0][7:0] == tuples[7][15:8]))
      count = count + 5'd1;

    // (1,2)
    if ((tuples[1][15:8] == tuples[2][7:0]) && (tuples[1][7:0] == tuples[2][15:8]))
      count = count + 5'd1;
    // (1,3)
    if ((tuples[1][15:8] == tuples[3][7:0]) && (tuples[1][7:0] == tuples[3][15:8]))
      count = count + 5'd1;
    // (1,4)
    if ((tuples[1][15:8] == tuples[4][7:0]) && (tuples[1][7:0] == tuples[4][15:8]))
      count = count + 5'd1;
    // (1,5)
    if ((tuples[1][15:8] == tuples[5][7:0]) && (tuples[1][7:0] == tuples[5][15:8]))
      count = count + 5'd1;
    // (1,6)
    if ((tuples[1][15:8] == tuples[6][7:0]) && (tuples[1][7:0] == tuples[6][15:8]))
      count = count + 5'd1;
    // (1,7)
    if ((tuples[1][15:8] == tuples[7][7:0]) && (tuples[1][7:0] == tuples[7][15:8]))
      count = count + 5'd1;

    // (2,3)
    if ((tuples[2][15:8] == tuples[3][7:0]) && (tuples[2][7:0] == tuples[3][15:8]))
      count = count + 5'd1;
    // (2,4)
    if ((tuples[2][15:8] == tuples[4][7:0]) && (tuples[2][7:0] == tuples[4][15:8]))
      count = count + 5'd1;
    // (2,5)
    if ((tuples[2][15:8] == tuples[5][7:0]) && (tuples[2][7:0] == tuples[5][15:8]))
      count = count + 5'd1;
    // (2,6)
    if ((tuples[2][15:8] == tuples[6][7:0]) && (tuples[2][7:0] == tuples[6][15:8]))
      count = count + 5'd1;
    // (2,7)
    if ((tuples[2][15:8] == tuples[7][7:0]) && (tuples[2][7:0] == tuples[7][15:8]))
      count = count + 5'd1;

    // (3,4)
    if ((tuples[3][15:8] == tuples[4][7:0]) && (tuples[3][7:0] == tuples[4][15:8]))
      count = count + 5'd1;
    // (3,5)
    if ((tuples[3][15:8] == tuples[5][7:0]) && (tuples[3][7:0] == tuples[5][15:8]))
      count = count + 5'd1;
    // (3,6)
    if ((tuples[3][15:8] == tuples[6][7:0]) && (tuples[3][7:0] == tuples[6][15:8]))
      count = count + 5'd1;
    // (3,7)
    if ((tuples[3][15:8] == tuples[7][7:0]) && (tuples[3][7:0] == tuples[7][15:8]))
      count = count + 5'd1;

    // (4,5)
    if ((tuples[4][15:8] == tuples[5][7:0]) && (tuples[4][7:0] == tuples[5][15:8]))
      count = count + 5'd1;
    // (4,6)
    if ((tuples[4][15:8] == tuples[6][7:0]) && (tuples[4][7:0] == tuples[6][15:8]))
      count = count + 5'd1;
    // (4,7)
    if ((tuples[4][15:8] == tuples[7][7:0]) && (tuples[4][7:0] == tuples[7][15:8]))
      count = count + 5'd1;

    // (5,6)
    if ((tuples[5][15:8] == tuples[6][7:0]) && (tuples[5][7:0] == tuples[6][15:8]))
      count = count + 5'd1;
    // (5,7)
    if ((tuples[5][15:8] == tuples[7][7:0]) && (tuples[5][7:0] == tuples[7][15:8]))
      count = count + 5'd1;

    // (6,7)
    if ((tuples[6][15:8] == tuples[7][7:0]) && (tuples[6][7:0] == tuples[7][15:8]))
      count = count + 5'd1;
  end

endmodule