module SumCheck(
    input signed [15:0] x,
    input signed [15:0] y,
    input signed [15:0] z,
    output reg result
);

    reg [15:0] sum_xy;
    reg [15:0] sum_xz;
    reg [15:0] sum_yz;
    reg overflow_xy;
    reg overflow_xz;
    reg overflow_yz;
    reg fractional_x;
    reg fractional_y;
    reg fractional_z;
    reg condition1;
    reg condition2;
    reg condition3;

    always @(*) begin
        // Check fractional parts (bits 7:0 must be 0 for integer)
        fractional_x = (x[7:0] != 8'd0);
        fractional_y = (y[7:0] != 8'd0);
        fractional_z = (z[7:0] != 8'd0);

        // If any input has fractional part, result is False
        if (fractional_x || fractional_y || fractional_z) begin
            result = 1'b0;
        end else begin
            // Perform signed additions with overflow detection
            // Overflow occurs if sign of sum != sign of both operands
            overflow_xy = ($signed(x[15]) == $signed(y[15])) && 
                         ($signed(sum_xy[15]) != $signed(x[15]));
            overflow_xz = ($signed(x[15]) == $signed(z[15])) && 
                         ($signed(sum_xz[15]) != $signed(x[15]));
            overflow_yz = ($signed(y[15]) == $signed(z[15])) && 
                         ($signed(sum_yz[15]) != $signed(y[15]));

            // Compute sums
            sum_xy = x + y;
            sum_xz = x + z;
            sum_yz = y + z;

            // Check each condition (only valid if no overflow)
            condition1 = !overflow_xy && (z == sum_xy);
            condition2 = !overflow_xz && (y == sum_xz);
            condition3 = !overflow_yz && (x == sum_yz);

            // Result is True if exactly one condition is true
            result = (condition1 ^ condition2 ^ condition3) && 
                    (condition1 || condition2 || condition3);
        end
    end
endmodule