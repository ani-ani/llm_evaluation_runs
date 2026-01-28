module car_race_collision(
    input [7:0] n,
    output [7:0] collisions
);
    assign collisions = n * n;
endmodule