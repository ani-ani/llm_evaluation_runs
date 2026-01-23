module luka_border_solver (
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

    // Calculate absolute differences
    wire [7:0] diff0 = (num0 > num1) ? (num0 - num1) : (num1 - num0);
    wire [7:0] diff1 = (num0 > num2) ? (num0 - num2) : (num2 - num0);
    wire [7:0] diff2 = (num0 > num3) ? (num0 - num3) : (num3 - num0);
    wire [7:0] diff3 = (num1 > num2) ? (num1 - num2) : (num2 - num1);
    wire [7:0] diff4 = (num1 > num3) ? (num1 - num3) : (num3 - num1);
    wire [7:0] diff5 = (num2 > num3) ? (num2 - num3) : (num3 - num2);

    // Find GCD of all differences
    wire [7:0] gcd_val = compute_gcd(diff0, diff1, diff2, diff3, diff4, diff5);

    // Find all divisors of gcd_val > 1
    assign m0 = (gcd_val > 1 && gcd_val % 2 == 0) ? 2 : 0;
    assign m1 = (gcd_val > 1 && gcd_val % 3 == 0) ? 3 : 0;
    assign m2 = (gcd_val > 1 && gcd_val % 4 == 0) ? 4 : 0;
    assign m3 = (gcd_val > 1 && gcd_val % 5 == 0) ? 5 : 0;
    assign m4 = (gcd_val > 1 && gcd_val % 6 == 0) ? 6 : 0;
    assign m5 = (gcd_val > 1 && gcd_val % 7 == 0) ? 7 : 0;
    assign m6 = (gcd_val > 1 && gcd_val % 8 == 0) ? 8 : 0;
    assign m7 = (gcd_val > 1 && gcd_val % 9 == 0) ? 9 : 0;

    // GCD computation function
    function [7:0] compute_gcd;
        input [7:0] a, b, c, d, e, f;
        reg [7:0] gcd_temp;
        begin
            gcd_temp = gcd_two(a, b);
            gcd_temp = gcd_two(gcd_temp, c);
            gcd_temp = gcd_two(gcd_temp, d);
            gcd_temp = gcd_two(gcd_temp, e);
            gcd_temp = gcd_two(gcd_temp, f);
            compute_gcd = gcd_temp;
        end
    endfunction

    // Helper function for GCD of two numbers
    function [7:0] gcd_two;
        input [7:0] x, y;
        reg [7:0] a, b, temp;
        begin
            a = x;
            b = y;
            while (b != 0) begin
                temp = b;
                b = a % b;
                a = temp;
            end
            gcd_two = a;
        end
    endfunction

endmodule