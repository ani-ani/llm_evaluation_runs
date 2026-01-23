module planet_orbits (
  input [63:0] planet1,
  input [63:0] planet2,
  output [7:0] result_valid,
  output [2:0] result_count,
  output invalid
);

  // Planet name constants (8-byte ASCII, space-padded)
  localparam [63:0] MERCURY = 64'h4d65726375727920;
  localparam [63:0] VENUS   = 64'h56656e7573202020;
  localparam [63:0] EARTH   = 64'h4561727468202020;
  localparam [63:0] MARS    = 64'h4d61727320202020;
  localparam [63:0] JUPITER = 64'h4a75706974657220;
  localparam [63:0] SATURN  = 64'h53617475726e2020;
  localparam [63:0] URANUS  = 64'h5572616e75732020;
  localparam [63:0] NEPTUNE = 64'h4e657074756e6520;

  reg [2:0] idx1, idx2;
  reg [2:0] min_idx, max_idx;
  reg [7:0] valid_mask;
  reg [2:0] count;

  always @(*) begin
    // Default values
    invalid = 1'b0;
    result_valid = 8'b0;
    result_count = 3'b0;

    // Match planet1
    casex (planet1)
      MERCURY: idx1 = 3'b000;
      VENUS:   idx1 = 3'b001;
      EARTH:   idx1 = 3'b010;
      MARS:    idx1 = 3'b011;
      JUPITER: idx1 = 3'b100;
      SATURN:  idx1 = 3'b101;
      URANUS:  idx1 = 3'b110;
      NEPTUNE: idx1 = 3'b111;
      default: invalid = 1'b1;
    endcase

    // Match planet2
    casex (planet2)
      MERCURY: idx2 = 3'b000;
      VENUS:   idx2 = 3'b001;
      EARTH:   idx2 = 3'b010;
      MARS:    idx2 = 3'b011;
      JUPITER: idx2 = 3'b100;
      SATURN:  idx2 = 3'b101;
      URANUS:  idx2 = 3'b110;
      NEPTUNE: idx2 = 3'b111;
      default: invalid = 1'b1;
    endcase

    // If either input is invalid, set outputs to default
    if (invalid) begin
      result_valid = 8'b0;
      result_count = 3'b0;
    end
    else begin
      // Determine min and max indices
      min_idx = (idx1 < idx2) ? idx1 : idx2;
      max_idx = (idx1 > idx2) ? idx1 : idx2;

      // Generate result_valid mask
      valid_mask = 8'b0;
      for (int i = 0; i < 8; i = i + 1) begin
        if (i > min_idx && i < max_idx) begin
          valid_mask[i] = 1'b1;
        end
      end

      // Count number of valid planets
      count = 0;
      for (int i = 0; i < 8; i = i + 1) begin
        if (valid_mask[i]) begin
          count = count + 1;
        end
      end

      result_valid = valid_mask;
      result_count = count;
    end
  end

endmodule