module car_race_collision(
  input  reg [7:0] n,
  output  reg [15:0] collision_count
);

  // Combinational squaring: collision_count = n * n
  always_comb begin
    collision_count = n * n;
  end

endmodule