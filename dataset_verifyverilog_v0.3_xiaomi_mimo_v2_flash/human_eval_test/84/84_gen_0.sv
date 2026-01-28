module digit_sum_binary (
    input [9:0] N,
    output [4:0] binary_sum
);
    // Extract hundreds digit: N / 100
    wire [9:0] hundreds_wire;
    assign hundreds_wire = N / 10'd100;
    
    // Extract tens digit: (N % 100) / 10
    wire [9:0] remainder_tens;
    wire [9:0] tens_wire;
    assign remainder_tens = N % 10'd100;
    assign tens_wire = remainder_tens / 10'd10;
    
    // Extract ones digit: N % 10
    wire [9:0] ones_wire;
    assign ones_wire = N % 10'd10;
    
    // Sum the digits (max 27, fits in 5 bits)
    wire [4:0] sum_wire;
    assign sum_wire = hundreds_wire[4:0] + tens_wire[4:0] + ones_wire[4:0];
    
    // Output is the 5-bit binary sum
    assign binary_sum = sum_wire;
endmodule