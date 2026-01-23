module luka_border_solver (
   input [7:0] num0, num1, num2, num3,
   output [7:0] m0, m1, m2, m3, m4, m5, m6, m7
);

// Function declarations
function [7:0] gcd2;
   input [7:0] a, b;
   reg [7:0] x, y;
   x = a;
   y = b;
   while (y != 0) begin
      {x, y} = {y, x % y};
   end
   gcd2 = x;
endfunction

function [7:0] get_divisor;
   input [7:0] n;
   input [2:0] idx;
   reg [7:0] d, i, count;
   count = 0;
   i = 2;
   while (i <= n) begin
      if (n % i == 0) begin
         if (count == idx) begin
            d = i;
         end
         count = count + 1;
      end
      i = i + 1;
   end
   get_divisor = (count > idx) ? i : 0;
endfunction

// Compute differences
wire [7:0] diff0, diff1, diff2;
assign diff0 = (num0 >= num1) ? (num0 - num1) : (num1 - num0);
assign diff1 = (num0 >= num2) ? (num0 - num2) : (num2 - num0);
assign diff2 = (num0 >= num3) ? (num0 - num3) : (num3 - num0);

// Compute overall GCD
wire [7:0] temp_gcd;
temp_gcd = gcd2(diff0, diff1);
wire [7:0] overall_gcd;
overall_gcd = gcd2(temp_gcd, diff2);

// Assign outputs
assign m0 = get_divisor(overall_gcd, 0);
assign m1 = get_divisor(overall_gcd, 1);
assign m2 = get_divisor(overall_gcd, 2);
assign m3 = get_divisor(overall_gcd, 3);
assign m4 = get_divisor(overall_gcd, 4);
assign m5 = get_divisor(overall_gcd, 5);
assign m6 = get_divisor(overall_gcd, 6);
assign m7 = get_divisor(overall_gcd, 7);

endmodule