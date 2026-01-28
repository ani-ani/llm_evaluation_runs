module car_race_collision(
    input [7:0] n,
    output [7:0] collisions
);

    // Combinational multiplier: collisions = n * n
    // Since n <= 15, n*n <= 225, fits in 8 bits
    assign collisions = n * n;

endmodule