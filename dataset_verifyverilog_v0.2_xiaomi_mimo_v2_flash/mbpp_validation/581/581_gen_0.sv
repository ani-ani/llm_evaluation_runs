module pyramid_area (
    input  [31:0] base_edge,
    input  [31:0] slant_height,
    output [31:0] surface_area
);

    // Internal wires for intermediate products
    // Multiplication of two Q16.16 numbers results in Q32.32
    wire [63:0] base_squared_raw; // = base_edge * base_edge
    wire [63:0] base_slant_raw;   // = base_edge * slant_height

    // Step 1: base_squared = base_edge * base_edge
    // Result is Q32.32. We need Q16.16, so we shift right by 16 bits (discard lower 16 fractional bits)
    assign base_squared_raw = base_edge * base_edge;
    wire [31:0] base_squared = base_squared_raw[47:16];

    // Step 2: lateral_area = 2 * base_edge * slant_height
    // Compute base_edge * slant_height first -> Q32.32
    // We need to shift right by 16 to get Q16.16.
    // Then multiply by 2 (simple left shift by 1).
    assign base_slant_raw = base_edge * slant_height;
    wire [31:0] base_slant_shifted = base_slant_raw[47:16];
    wire [31:0] lateral_area = base_slant_shifted << 1;

    // Step 3: surface_area = lateral_area + base_squared
    assign surface_area = lateral_area + base_squared;

endmodule