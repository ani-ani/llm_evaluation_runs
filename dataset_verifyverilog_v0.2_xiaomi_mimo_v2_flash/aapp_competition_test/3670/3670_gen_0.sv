module luka_border_solver(
    input [7:0] num0,
    input [7:0] num1,
    input [7:0] num2,
    input [7:0] num3,
    output [7:0] m0,
    output [7:0] m1,
    output [7:0] m2,
    output [7:0] m3,
    output [7:0] m4,
    output [7:0] m5,
    output [7:0] m6,
    output [7:0] m7
);

    // Internal signals for differences and gcd calculation
    reg [7:0] diff0;
    reg [7:0] diff1;
    reg [7:0] diff2;
    reg [7:0] diff3;
    reg [7:0] diff4;
    reg [7:0] diff5;
    
    reg [7:0] gcd1;
    reg [7:0] gcd2;
    reg [7:0] gcd3;
    reg [7:0] gcd4;
    reg [7:0] gcd5;
    
    reg [7:0] final_gcd;
    
    // Combinational logic for GCD of 2 numbers using Euclidean algorithm
    function [7:0] gcd2fun;
        input [7:0] a;
        input [7:0] b;
        reg [7:0] x;
        reg [7:0] y;
        reg [7:0] temp;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                temp = y;
                y = x % y;
                x = temp;
            end
            gcd2fun = x;
        end
    endfunction

    // Combinational logic to find divisors
    reg [7:0] divs [0:7];
    integer i, j;

    always @(*) begin
        // Step 1: Calculate absolute differences
        if (num0 > num1) diff0 = num0 - num1; else diff0 = num1 - num0;
        if (num0 > num2) diff1 = num0 - num2; else diff1 = num2 - num0;
        if (num0 > num3) diff2 = num0 - num3; else diff2 = num3 - num0;
        if (num1 > num2) diff3 = num1 - num2; else diff3 = num2 - num1;
        if (num1 > num3) diff4 = num1 - num3; else diff4 = num3 - num1;
        if (num2 > num3) diff5 = num2 - num3; else diff5 = num3 - num2;
        
        // Step 2: Calculate GCD of all differences
        // Start with gcd of first two
        gcd1 = gcd2fun(diff0, diff1);
        // Add third diff
        gcd2 = gcd2fun(gcd1, diff2);
        // Add fourth diff
        gcd3 = gcd2fun(gcd2, diff3);
        // Add fifth diff
        gcd4 = gcd2fun(gcd3, diff4);
        // Add sixth diff
        gcd5 = gcd2fun(gcd4, diff5);
        
        final_gcd = gcd5;
        
        // Step 3: Find all divisors of final_gcd that are > 1
        // Initialize outputs to 0
        for (i = 0; i < 8; i = i + 1) begin
            divs[i] = 8'h00;
        end
        
        j = 0;
        // If final_gcd is 0 or 1, no valid M > 1
        if (final_gcd > 1) begin
            for (i = 2; i <= 255; i = i + 1) begin
                if (j < 8) begin
                    if ((final_gcd % i) == 0) begin
                        divs[j] = i[7:0];
                        j = j + 1;
                    end
                end
            end
        end
    end

    // Assign outputs from the divs array
    assign m0 = divs[0];
    assign m1 = divs[1];
    assign m2 = divs[2];
    assign m3 = divs[3];
    assign m4 = divs[4];
    assign m5 = divs[5];
    assign m6 = divs[6];
    assign m7 = divs[7];

endmodule
