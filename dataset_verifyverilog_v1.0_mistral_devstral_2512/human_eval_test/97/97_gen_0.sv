module unit_digit_multiply(
    input signed [15:0] a,
    input signed [15:0] b,
    output [7:0] result
);
    
    wire signed [15:0] a_abs;
    wire signed [15:0] b_abs;
    wire [3:0] a_unit;
    wire [3:0] b_unit;
    
    // Compute absolute values
    assign a_abs = (a[15] == 1'b1) ? -a : a;
    assign b_abs = (b[15] == 1'b1) ? -b : b;
    
    // Extract unit digits (mod 10)
    assign a_unit = a_abs % 4'd10;
    assign b_unit = b_abs % 4'd10;
    
    // Multiply unit digits
    assign result = a_unit * b_unit;
    
endmodule