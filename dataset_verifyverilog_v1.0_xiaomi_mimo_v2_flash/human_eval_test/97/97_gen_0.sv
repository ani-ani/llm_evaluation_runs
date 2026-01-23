module unit_digit_multiply(
    input signed [15:0] a,
    input signed [15:0] b,
    output reg [7:0] result
);
    // Internal signals for absolute values and unit digits
    reg [15:0] abs_a;
    reg [15:0] abs_b;
    reg [7:0] unit_a;
    reg [7:0] unit_b;
    reg [7:0] product;

    // Extract absolute values (ignore sign)
    always @(*) begin
        if (a[15]) begin
            // Two's complement: invert bits and add 1
            abs_a = (~a) + 16'd1;
        end else begin
            abs_a = a;
        end

        if (b[15]) begin
            abs_b = (~b) + 16'd1;
        end else begin
            abs_b = b;
        end
    end

    // Extract unit digits using modulo operator
    always @(*) begin
        unit_a = abs_a % 8'd10;  // Unit digit of first number
        unit_b = abs_b % 8'd10;  // Unit digit of second number
    end

    // Multiply unit digits
    always @(*) begin
        product = unit_a * unit_b;  // Max 9*9 = 81, fits in 8 bits
    end

    // Assign output
    always @(*) begin
        result = product;
    end

endmodule