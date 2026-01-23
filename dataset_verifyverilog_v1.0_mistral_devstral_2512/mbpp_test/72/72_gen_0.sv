module dif_square (
    input [7:0] n,
    output result
);

// A number can be represented as the difference of two squares if and only if
// it is NOT congruent to 2 modulo 4 (i.e., n % 4 != 2)
// This is because: n = a^2 - b^2 = (a+b)(a-b)
// For integer a,b, the product (a+b)(a-b) will never equal 2 mod 4

// Combinational logic: result = 1 if n[1:0] != 2'b10
// n % 4 is equivalent to n[1:0] (the 2 least significant bits)
// n % 4 == 2 means n[1:0] == 2'b10

assign result = (n[1:0] != 2'b10);

endmodule