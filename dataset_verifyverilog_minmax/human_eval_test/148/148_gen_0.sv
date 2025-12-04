module planet_orbits(
  input [2:0] planet1,  // 000=Mercury, 001=Venus, 010=Earth, 011=Mars, 100=Jupiter, 101=Saturn, 110=Uranus, 111=Neptune
  input [2:0] planet2,  // Same encoding as above
  output reg [2:0] planets [4:0], // Array of up to 5 planets
  output reg [2:0] count,         // Number of valid planets in output
  output reg invalid              // High if inputs are invalid (>7)
);

  // Parameter encodings for clarity (do not rely on numeric order)
  parameter MERCURY = 3'b000;
  parameter VENUS   = 3'b001;
  parameter EARTH   = 3'b010;
  parameter MARS    = 3'b011;
  parameter JUPITER = 3'b100;
  parameter SATURN  = 3'b101;
  parameter URANUS  = 3'b110;
  parameter NEPTUNE = 3'b111;

  integer i;

  always @(*) begin
    // Default outputs
    invalid = 1'b0;
    for (i = 0; i < 5; i = i + 1) planets[i] = 3'b000;
    count = 3'b000;

    // Input validation: values must be in [0..7]
    if ((planet1 > 3'b111) || (planet2 > 3'b111)) begin
      invalid = 1'b1;
    end else begin
      // Convert encodings to order indices: Mercury=0, Venus=1, Earth=2, Mars=3, Jupiter=4, Saturn=5, Uranus=6, Neptune=7
      // Compute indices via equality checks against constant encodings
      begin
        reg [2:0] idx1, idx2, low, high;
        reg [3:0] tmp_count;
        // planet1 index
        idx1 = (planet1 == MERCURY) ? 3'd0 :
               (planet1 == VENUS)   ? 3'd1 :
               (planet1 == EARTH)   ? 3'd2 :
               (planet1 == MARS)    ? 3'd3 :
               (planet1 == JUPITER) ? 3'd4 :
               (planet1 == SATURN)  ? 3'd5 :
               (planet1 == URANUS)  ? 3'd6 : 3'd7; // NEPTUNE
        // planet2 index
        idx2 = (planet2 == MERCURY) ? 3'd0 :
               (planet2 == VENUS)   ? 3'd1 :
               (planet2 == EARTH)   ? 3'd2 :
               (planet2 == MARS)    ? 3'd3 :
               (planet2 == JUPITER) ? 3'd4 :
               (planet2 == SATURN)  ? 3'd5 :
               (planet2 == URANUS)  ? 3'd6 : 3'd7; // NEPTUNE

        // Swap to ensure idx1 <= idx2
        if (idx1 > idx2) begin
          low  = idx2;
          high = idx1;
        end else begin
          low  = idx1;
          high = idx2;
        end

        // Output all planets with indices strictly between low and high
        // Planets are contiguous, so maximum count is 5 (between 0..7)
        tmp_count = 4'd0;
        for (i = 0; i < 5; i = i + 1) begin
          if ((low + 1 + i) < high) begin
            // Map index to encoding
            case (low + 1 + i)
              3'd0: planets[i] = MERCURY;
              3'd1: planets[i] = VENUS;
              3'd2: planets[i] = EARTH;
              3'd3: planets[i] = MARS;
              3'd4: planets[i] = JUPITER;
              3'd5: planets[i] = SATURN;
              3'd6: planets[i] = URANUS;
              3'd7: planets[i] = NEPTUNE;
              default: planets[i] = 3'b000; // Should not occur for valid low/high
            endcase
            tmp_count = tmp_count + 1;
          end else begin
            planets[i] = 3'b000;
          end
        end
        count = tmp_count[2:0];
      end
    end
  end

endmodule