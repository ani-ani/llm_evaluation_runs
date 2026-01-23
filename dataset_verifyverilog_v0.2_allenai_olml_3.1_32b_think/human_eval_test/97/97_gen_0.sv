module multiply_unit_digits(input signed [7:0] a, input signed [7:0] b, output [7:0] result);
assign abs_a = a < 0 ? (~a + 1) : a;
assign abs_b = b < 0 ? (~b + 1) : b;
assign digit_a = abs_a % 10;
assign digit_b = abs_b % 10;
assign result = digit_a * digit_b;
endmodule