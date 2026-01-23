module interval_intersection(
    input [15:0] start1,
    input [15:0] end1,
    input [15:0] start2,
    input [15:0] end2,
    output reg result
);

    // Intermediate signals
    reg [15:0] int_start;
    reg [15:0] int_end;
    reg [15:0] length;
    reg [7:0] length_idx;
    reg is_prime;

    // Prime number lookup table (1 = prime, 0 = not prime)
    reg [0:255] prime_lut;

    // Initialize LUT in combinational block
    integer i;
    always @(*) begin
        // Default all to 0 (not prime)
        for (i = 0; i < 256; i = i + 1) begin
            prime_lut[i] = 1'b0;
        end
        
        // Set primes to 1
        prime_lut[2] = 1'b1;
        prime_lut[3] = 1'b1;
        prime_lut[5] = 1'b1;
        prime_lut[7] = 1'b1;
        prime_lut[11] = 1'b1;
        prime_lut[13] = 1'b1;
        prime_lut[17] = 1'b1;
        prime_lut[19] = 1'b1;
        prime_lut[23] = 1'b1;
        prime_lut[29] = 1'b1;
        prime_lut[31] = 1'b1;
        prime_lut[37] = 1'b1;
        prime_lut[41] = 1'b1;
        prime_lut[43] = 1'b1;
        prime_lut[47] = 1'b1;
        prime_lut[53] = 1'b1;
        prime_lut[59] = 1'b1;
        prime_lut[61] = 1'b1;
        prime_lut[67] = 1'b1;
        prime_lut[71] = 1'b1;
        prime_lut[73] = 1'b1;
        prime_lut[79] = 1'b1;
        prime_lut[83] = 1'b1;
        prime_lut[89] = 1'b1;
        prime_lut[97] = 1'b1;
        prime_lut[101] = 1'b1;
        prime_lut[103] = 1'b1;
        prime_lut[107] = 1'b1;
        prime_lut[109] = 1'b1;
        prime_lut[113] = 1'b1;
        prime_lut[127] = 1'b1;
        prime_lut[131] = 1'b1;
        prime_lut[137] = 1'b1;
        prime_lut[139] = 1'b1;
        prime_lut[149] = 1'b1;
        prime_lut[151] = 1'b1;
        prime_lut[157] = 1'b1;
        prime_lut[163] = 1'b1;
        prime_lut[167] = 1'b1;
        prime_lut[173] = 1'b1;
        prime_lut[179] = 1'b1;
        prime_lut[181] = 1'b1;
        prime_lut[191] = 1'b1;
        prime_lut[193] = 1'b1;
        prime_lut[197] = 1'b1;
        prime_lut[199] = 1'b1;
        prime_lut[211] = 1'b1;
        prime_lut[223] = 1'b1;
        prime_lut[227] = 1'b1;
        prime_lut[229] = 1'b1;
        prime_lut[233] = 1'b1;
        prime_lut[239] = 1'b1;
        prime_lut[241] = 1'b1;
        prime_lut[251] = 1'b1;
        // Note: primes above 255 not in lookup
    end

    // Combinational logic
    always @(*) begin
        // Step 1: Compute intersection start and end
        if (start1 > start2) begin
            int_start = start1;
        end else begin
            int_start = start2;
        end

        if (end1 < end2) begin
            int_end = end1;
        end else begin
            int_end = end2;
        end

        // Step 2: Compute length
        if (int_end >= int_start) begin
            length = int_end - int_start;
        end else begin
            length = 16'hFFFF; // Invalid
        end

        // Step 3: Check if intersection exists and length is prime
        // Note: We only check prime for lengths 0-255, others are not prime
        if (int_end >= int_start && length <= 16'd255) begin
            length_idx = length[7:0];
            is_prime = prime_lut[length_idx];
        end else begin
            is_prime = 1'b0;
        end

        // Step 4: Assign output
        result = is_prime;
    end

endmodule