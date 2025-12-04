module parabola_directrix (
    input wire signed [15:0] a,
    input wire signed [15:0] b,
    input wire signed [15:0] c,
    output wire signed [15:0] directrix
);

    // Compute b*b: 16*16 = 32 bits
    wire signed [31:0] b_sq = b * b;
    
    // Compute (b*b + 1): 32 bits + 1
    wire signed [31:0] b_sq_plus_one = b_sq + 1;
    
    // Compute 4*a: 16*4 = 18 bits, sign-extend to 50 bits for multiplication
    wire signed [49:0] a_times_4 = {34'b0, a} <<< 2;
    
    // Compute (b*b + 1) * 4*a: 32*18 = 50 bits
    wire signed [49:0] term = b_sq_plus_one * a_times_4;
    
    // Compute c - term: 16-bit c sign-extended to 50 bits
    wire signed [49:0] result = {34'b0, c} - term;
    
    // Truncate to 16 bits
    assign directrix = result[15:0];
    
endmodule