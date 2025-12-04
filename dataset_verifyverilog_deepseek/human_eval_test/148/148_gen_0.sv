module planet_orbits (
    input [2:0] planet1, planet2,
    output reg [2:0] planets [0:4],
    output reg [2:0] count,
    output reg invalid
);

    always_comb begin
        invalid = (planet1 > 3'd7) || (planet2 > 3'd7);
        count = 3'd0;
        for (int i=0; i<5; i++) begin
            planets[i] = 3'b0;
        end

        if (!invalid) begin
            logic [2:0] lower, upper;
            lower = (planet1 < planet2) ? planet1 : planet2;
            upper = (planet1 < planet2) ? planet2 : planet1;

            logic [2:0] num_planets;
            num_planets = upper - lower - 1'd1;

            if (upper - lower > 1) begin
                count = (num_planets > 3'd5) ? 3'd5 : num_planets;

                for (int i=0; i<5; i++) begin
                    if (i < num_planets) begin
                        planets[i] = lower + 3'(i) + 1'd1;
                    end else begin
                        planets[i] = 3'b0;
                    end
                end
            end
        end
    end
endmodule