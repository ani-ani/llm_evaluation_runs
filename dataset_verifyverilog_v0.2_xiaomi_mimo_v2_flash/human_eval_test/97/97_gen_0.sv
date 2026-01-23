module multiply_unit_digits (
    input signed [7:0] a,
    input signed [7:0] b,
    output [7:0] result
);

    wire [7:0] abs_a;
    wire [7:0] abs_b;
    wire [7:0] digit_a;
    wire [7:0] digit_b;

    // Compute absolute values
    // For signed 8-bit input, -128 (10000000) is a special case.
    // neg_a is 1 when a is negative.
    // If a is -128, abs_a becomes 128 (10000000), which wraps to 0 in 8 bits.
    // However, unit digit of 128 is 8, and 0 is treated as 0 in this logic.
    // To strictly follow the request for efficient combinational logic, 
    // we use ternary operator for abs. 
    // Note: The specific case of -128 results in 128, and 128 % 10 = 8.
    // Without an extra bit, -128 abs is 0. If 0 % 10 = 0 is acceptable for this edge case,
    // we proceed. If strict correctness for -128 is needed, we need 9 bits.
    // Given the constraints and 'efficient' nature, we stick to the width provided.
    assign abs_a = (a[7] && (a != -8'sd128)) ? -a : a;
    assign abs_b = (b[7] && (b != -8'sd128)) ? -b : b;

    // Extract unit digits
    // Since we are dealing with 0-9 indices, we can use a lookup table (LUT) or subtraction loop.
    // Subtraction is efficient for combinational logic.
    // Logic: digit = num - (num/10)*10.
    // Since num <= 128, num/10 <= 12. We can iterate up to 12 times or use a fixed subtraction loop.
    // Unrolling a loop of subtractions is standard for small numbers.
    
    // Optimized Unit Digit Extraction for max 128:
    // Check multiples of 10: 100 (not needed as 128<100 is false, 128>=100 is true), 90, 80, 70, 60, 50, 40, 30, 20, 10.
    // Wait, max is 128. So 100 is a possibility.
    // Correct logic: Subtract 100, 90, 80... 10.
    
    // Unrolled subtraction for digit_a
    wire [7:0] t0_a = (abs_a >= 100) ? (abs_a - 100) : abs_a;
    wire [7:0] t1_a = (t0_a >= 90) ? (t0_a - 90) : t0_a;
    wire [7:0] t2_a = (t1_a >= 80) ? (t1_a - 80) : t1_a;
    wire [7:0] t3_a = (t2_a >= 70) ? (t2_a - 70) : t2_a;
    wire [7:0] t4_a = (t3_a >= 60) ? (t3_a - 60) : t3_a;
    wire [7:0] t5_a = (t4_a >= 50) ? (t4_a - 50) : t4_a;
    wire [7:0] t6_a = (t5_a >= 40) ? (t5_a - 40) : t5_a;
    wire [7:0] t7_a = (t6_a >= 30) ? (t6_a - 30) : t6_a;
    wire [7:0] t8_a = (t7_a >= 20) ? (t7_a - 20) : t7_a;
    wire [7:0] t9_a = (t8_a >= 10) ? (t8_a - 10) : t8_a;
    assign digit_a = t9_a;

    // Unrolled subtraction for digit_b
    wire [7:0] t0_b = (abs_b >= 100) ? (abs_b - 100) : abs_b;
    wire [7:0] t1_b = (t0_b >= 90) ? (t0_b - 90) : t0_b;
    wire [7:0] t2_b = (t1_b >= 80) ? (t1_b - 80) : t1_b;
    wire [7:0] t3_b = (t2_b >= 70) ? (t2_b - 70) : t2_b;
    wire [7:0] t4_b = (t3_b >= 60) ? (t3_b - 60) : t3_b;
    wire [7:0] t5_b = (t4_b >= 50) ? (t4_b - 50) : t4_b;
    wire [7:0] t6_b = (t5_b >= 40) ? (t5_b - 40) : t5_b;
    wire [7:0] t7_b = (t6_b >= 30) ? (t6_b - 30) : t6_b;
    wire [7:0] t8_b = (t7_b >= 20) ? (t7_b - 20) : t7_b;
    wire [7:0] t9_b = (t8_b >= 10) ? (t8_b - 10) : t8_b;
    assign digit_b = t9_b;

    // Multiply
    // Result max 9*9=81. Fits in 7 bits.
    assign result = digit_a * digit_b;

endmodule