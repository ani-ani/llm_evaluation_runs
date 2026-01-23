module cone_volume(
    input [31:0] radius,
    input [31:0] height,
    output [31:0] volume
);

    // Constants in Q16.16 format
    // pi = 0x0003243F (3.14159)
    // one_third = 0x00005555 (0.33333)
    wire [31:0] PI = 32'h0003243F;
    wire [31:0] ONE_THIRD = 32'h00005555;

    // Intermediate results (combinational registers)
    reg [63:0] r_sq_mult;      // r * r (64-bit result)
    reg [31:0] r_sq;           // r^2 in Q16.16 (upper 32 bits)
    
    reg [63:0] r_sq_h_mult;    // r^2 * h (64-bit result)
    reg [31:0] r_sq_h;         // r^2 * h in Q16.16 (upper 32 bits)
    
    reg [63:0] vol_pi_mult;    // (r^2 * h) * pi (64-bit result)
    reg [31:0] vol_pi;         // (r^2 * h) * pi in Q16.16 (upper 32 bits)
    
    reg [63:0] vol_final_mult; // (r^2 * h * pi) * (1/3) (64-bit result)
    reg [31:0] vol_final;      // final result in Q16.16 (upper 32 bits)

    always @(*) begin
        // Step 1: r² = r * r
        r_sq_mult = radius * radius;
        r_sq = r_sq_mult[63:32];
        
        // Step 2: r² * h
        r_sq_h_mult = r_sq * height;
        r_sq_h = r_sq_h_mult[63:32];
        
        // Step 3: multiply by π
        vol_pi_mult = r_sq_h * PI;
        vol_pi = vol_pi_mult[63:32];
        
        // Step 4: multiply by 1/3
        vol_final_mult = vol_pi * ONE_THIRD;
        vol_final = vol_final_mult[63:32];
    end

    assign volume = vol_final;

endmodule