module check_sum_condition (
    input signed [15:0] x,
    input signed [15:0] y,
    input signed [15:0] z,
    output reg result
);

    // Extract fractional parts (bits 7:0)
    wire [7:0] frac_x = x[7:0];
    wire [7:0] frac_y = y[7:0];
    wire [7:0] frac_z = z[7:0];
    
    // Check if all inputs are integers (fractional part == 0)
    wire all_integers = (frac_x == 8'd0) && (frac_y == 8'd0) && (frac_z == 8'd0);
    
    // Perform additions with 16-bit signed arithmetic
    // Overflow detection: For signed addition, overflow occurs when:
    //   Adding two positives gives negative, or adding two negatives gives positive
    wire signed [15:0] y_plus_z = y + z;
    wire signed [15:0] x_plus_z = x + z;
    wire signed [15:0] x_plus_y = x + y;
    
    // Overflow detection for each addition
    wire y_plus_z_overflow = ((~y[15] & ~z[15] & y_plus_z[15]) || (y[15] & z[15] & ~y_plus_z[15]));
    wire x_plus_z_overflow = ((~x[15] & ~z[15] & x_plus_z[15]) || (x[15] & z[15] & ~x_plus_z[15]));
    wire x_plus_y_overflow = ((~x[15] & ~y[15] & x_plus_y[15]) || (x[15] & y[15] & ~x_plus_y[15]));
    
    // Check each condition (only valid if no overflow)
    wire cond_x_equals = (x == y_plus_z) && !y_plus_z_overflow;
    wire cond_y_equals = (y == x_plus_z) && !x_plus_z_overflow;
    wire cond_z_equals = (z == x_plus_y) && !x_plus_y_overflow;
    
    // True if all inputs are integers AND exactly one condition is true
    wire sum_match = (cond_x_equals && !cond_y_equals && !cond_z_equals) ||
                     (!cond_x_equals && cond_y_equals && !cond_z_equals) ||
                     (!cond_x_equals && !cond_y_equals && cond_z_equals);
    
    // Combinational output
    always @(*) begin
        if (all_integers && sum_match) begin
            result = 1'b1;
        end else begin
            result = 1'b0;
        end
    end

endmodule