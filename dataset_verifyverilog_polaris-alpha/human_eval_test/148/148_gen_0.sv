module planet_orbits(
  input  [2:0] planet1,
  input  [2:0] planet2,
  output logic [2:0] planets [4:0],
  output logic [2:0] count,
  output logic       invalid
);

  logic [2:0] p_min, p_max;
  logic [2:0] diff;

  always_comb begin
    // Default outputs
    invalid = 1'b0;
    count   = 3'd0;
    planets[0] = 3'd0;
    planets[1] = 3'd0;
    planets[2] = 3'd0;
    planets[3] = 3'd0;
    planets[4] = 3'd0;

    // Check for invalid planet encodings (>7 are invalid, but 3-bit inputs ensure 0-7)
    if ((planet1 > 3'd7) || (planet2 > 3'd7)) begin
      invalid = 1'b1;
      // All other outputs remain zero
    end else begin
      // Determine ordered indices
      if (planet1 <= planet2) begin
        p_min = planet1;
        p_max = planet2;
      end else begin
        p_min = planet2;
        p_max = planet1;
      end

      diff = p_max - p_min;

      // If equal or adjacent, no planets in between
      if (diff <= 3'd1) begin
        count = 3'd0;
      end else begin
        // Number of planets strictly between
        count = diff - 3'd1;

        // Fill planets array with intermediate planets
        // planets[i] = p_min + i + 1 for i in [0, count-1]
        if (count > 3'd0) planets[0] = p_min + 3'd1;
        if (count > 3'd1) planets[1] = p_min + 3'd2;
        if (count > 3'd2) planets[2] = p_min + 3'd3;
        if (count > 3'd3) planets[3] = p_min + 3'd4;
        if (count > 3'd4) planets[4] = p_min + 3'd5;
      end
    end
  end

endmodule