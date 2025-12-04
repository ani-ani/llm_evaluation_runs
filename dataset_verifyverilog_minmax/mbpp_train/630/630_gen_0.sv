module adjacent_coordinates(
  input reg [3:0] x, y,
  output wire [71:0] out
);
  wire [3:0] x_m1 = (x == 4'h0) ? 4'h0 : x - 1;
  wire [3:0] x_p1 = (x == 4'hF) ? 4'hF : x + 1;
  wire [3:0] y_m1 = (y == 4'h0) ? 4'h0 : y - 1;
  wire [3:0] y_p1 = (y == 4'hF) ? 4'hF : y + 1;
  assign out = {
    {x_m1, y_m1},
    {x_m1, y},
    {x_m1, y_p1},
    {x, y_m1},
    {x, y},
    {x, y_p1},
    {x_p1, y_m1},
    {x_p1, y},
    {x_p1, y_p1}
  };
endmodule