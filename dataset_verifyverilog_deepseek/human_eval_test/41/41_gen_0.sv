module car_race_collision(
  input [7:0] n,
  output [15:0] collision_count
);
  assign collision_count = n * n;
endmodule