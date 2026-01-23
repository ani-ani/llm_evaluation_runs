module common_divisors_sum (
    input [15:0] a,
    input [15:0] b,
    output [15:0] sum
);

    // Intermediate signals for each divisor check
    wire [15:0] divisor_sum;

    // Combinational logic to check divisors 1 to 15 in parallel
    // Each bit represents whether the divisor is a common divisor
    assign divisor_sum[0] = 1'b0; // divisor 0 is not checked
    
    assign divisor_sum[1] = ((a % 16'd1) == 16'd0) && ((b % 16'd1) == 16'd0) ? 16'd1 : 16'd0;
    assign divisor_sum[2] = ((a % 16'd2) == 16'd0) && ((b % 16'd2) == 16'd0) ? 16'd2 : 16'd0;
    assign divisor_sum[3] = ((a % 16'd3) == 16'd0) && ((b % 16'd3) == 16'd0) ? 16'd3 : 16'd0;
    assign divisor_sum[4] = ((a % 16'd4) == 16'd0) && ((b % 16'd4) == 16'd0) ? 16'd4 : 16'd0;
    assign divisor_sum[5] = ((a % 16'd5) == 16'd0) && ((b % 16'd5) == 16'd0) ? 16'd5 : 16'd0;
    assign divisor_sum[6] = ((a % 16'd6) == 16'd0) && ((b % 16'd6) == 16'd0) ? 16'd6 : 16'd0;
    assign divisor_sum[7] = ((a % 16'd7) == 16'd0) && ((b % 16'd7) == 16'd0) ? 16'd7 : 16'd0;
    assign divisor_sum[8] = ((a % 16'd8) == 16'd0) && ((b % 16'd8) == 16'd0) ? 16'd8 : 16'd0;
    assign divisor_sum[9] = ((a % 16'd9) == 16'd0) && ((b % 16'd9) == 16'd0) ? 16'd9 : 16'd0;
    assign divisor_sum[10] = ((a % 16'd10) == 16'd0) && ((b % 16'd10) == 16'd0) ? 16'd10 : 16'd0;
    assign divisor_sum[11] = ((a % 16'd11) == 16'd0) && ((b % 16'd11) == 16'd0) ? 16'd11 : 16'd0;
    assign divisor_sum[12] = ((a % 16'd12) == 16'd0) && ((b % 16'd12) == 16'd0) ? 16'd12 : 16'd0;
    assign divisor_sum[13] = ((a % 16'd13) == 16'd0) && ((b % 16'd13) == 16'd0) ? 16'd13 : 16'd0;
    assign divisor_sum[14] = ((a % 16'd14) == 16'd0) && ((b % 16'd14) == 16'd0) ? 16'd14 : 16'd0;
    assign divisor_sum[15] = ((a % 16'd15) == 16'd0) && ((b % 16'd15) == 16'd0) ? 16'd15 : 16'd0;

    // Sum all common divisors
    // Using adder tree for efficient combinational logic
    wire [15:0] sum_int;
    
    // First level of adders
    wire [15:0] sum_l1_0 = divisor_sum[0] + divisor_sum[1];
    wire [15:0] sum_l1_1 = divisor_sum[2] + divisor_sum[3];
    wire [15:0] sum_l1_2 = divisor_sum[4] + divisor_sum[5];
    wire [15:0] sum_l1_3 = divisor_sum[6] + divisor_sum[7];
    wire [15:0] sum_l1_4 = divisor_sum[8] + divisor_sum[9];
    wire [15:0] sum_l1_5 = divisor_sum[10] + divisor_sum[11];
    wire [15:0] sum_l1_6 = divisor_sum[12] + divisor_sum[13];
    wire [15:0] sum_l1_7 = divisor_sum[14] + divisor_sum[15];
    
    // Second level of adders
    wire [15:0] sum_l2_0 = sum_l1_0 + sum_l1_1;
    wire [15:0] sum_l2_1 = sum_l1_2 + sum_l1_3;
    wire [15:0] sum_l2_2 = sum_l1_4 + sum_l1_5;
    wire [15:0] sum_l2_3 = sum_l1_6 + sum_l1_7;
    
    // Third level of adders
    wire [15:0] sum_l3_0 = sum_l2_0 + sum_l2_1;
    wire [15:0] sum_l3_1 = sum_l2_2 + sum_l2_3;
    
    // Final adder
    assign sum = sum_l3_0 + sum_l3_1;

endmodule