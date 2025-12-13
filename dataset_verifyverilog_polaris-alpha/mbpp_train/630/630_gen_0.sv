module adjacent_coordinates(
  input  [3:0] x,
  input  [3:0] y,
  output [71:0] out
);

  wire [3:0] x_m1, x_0, x_p1;
  wire [3:0] y_m1, y_0, y_p1;

  assign x_m1 = (x == 4'd0)  ? 4'd0  : (x - 4'd1);
  assign x_0  = x;
  assign x_p1 = (x == 4'd15) ? 4'd15 : (x + 4'd1);

  assign y_m1 = (y == 4'd0)  ? 4'd0  : (y - 4'd1);
  assign y_0  = y;
  assign y_p1 = (y == 4'd15) ? 4'd15 : (y + 4'd1);

  // Order:
  // [x-1,y-1], [x-1,y], [x-1,y+1],
  // [x,  y-1], [x,  y], [x,  y+1],
  // [x+1,y-1], [x+1,y], [x+1,y+1]

  assign out = {
    x_p1, y_p1, // [x+1,y+1]
    x_p1, y_0,  // [x+1,y]
    x_p1, y_m1, // [x+1,y-1]
    x_0,  y_p1, // [x,  y+1]
    x_0,  y_0,  // [x,  y]
    x_0,  y_m1, // [x,  y-1]
    x_m1, y_p1, // [x-1,y+1]
    x_m1, y_0,  // [x-1,y]
    x_m1, y_m1  // [x-1,y-1]
  };

endmodule