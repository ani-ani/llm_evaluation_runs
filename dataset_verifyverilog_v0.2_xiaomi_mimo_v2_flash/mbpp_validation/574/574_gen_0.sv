module surfacearea_cylinder (
    input  [31:0] r,
    input  [31:0] h,
    output [31:0] result
);

    // Constant: 2 * pi in Q16.16 format (6.283 * 65536 = 411774)
    wire [31:0] two_pi = 32'h0006485E;

    // Internal signals
    wire [63:0] r_squared_raw; // 64-bit result of r * r
    wire [31:0] r_squared;     // Q16.16 result (upper 32 bits)

    wire [63:0] term1_raw;     // 64-bit result of two_pi * r_squared
    wire [31:0] term1;         // Q16.16 result (upper 32 bits)

    wire [63:0] r_h_raw;       // 64-bit result of r * h
    wire [31:0] r_h;           // Q16.16 result (upper 32 bits)

    wire [63:0] term2_raw;     // 64-bit result of two_pi * r_h
    wire [31:0] term2;         // Q16.16 result (upper 32 bits)

    // 1. Compute r_squared = r * r
    assign r_squared_raw = r * r;
    assign r_squared = r_squared_raw[63:32];

    // 2. Compute term1 = 2 * pi * r_squared
    assign term1_raw = two_pi * r_squared;
    assign term1 = term1_raw[63:32];

    // 3. Compute term2 = 2 * pi * r * h
    // Optimization: (2*pi * r) * h or r * h then (2*pi * result)
    // Here we follow the structure: (r * h) then (2*pi * result)
    assign r_h_raw = r * h;
    assign r_h = r_h_raw[63:32];

    assign term2_raw = two_pi * r_h;
    assign term2 = term2_raw[63:32];

    // 4. Sum terms
    assign result = term1 + term2;

endmodule
