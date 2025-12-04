module adjacent_coordinates(input [3:0] x, input [3:0] y, output [71:0] out);
  wire [3:0] x_prev = (x == 4'b0) ? 4'b0 : (x - 1);
  wire [3:0] x_next = (x == 4'b1111) ? 4'b1111 : (x + 1);
  wire [3:0] y_prev = (y == 4'b0) ? 4'b0 : (y - 1);
  wire [3:0] y_next = (y == 4'b1111) ? 4'b1111 : (y + 1);
  assign out = { {x_next,y_next}, {x_next,y}, {x_next,y_prev}, {x,y_next}, {x,y}, {x,y_prev}, {x_prev,y_next}, {x_prev,y}, {x_prev,y_prev} };
endmodule