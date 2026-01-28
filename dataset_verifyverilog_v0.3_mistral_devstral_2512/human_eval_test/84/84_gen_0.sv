module digit_sum_binary(
    input [9:0] N,
    output [4:0] binary_sum
);
    
    wire [9:0] hundreds = N / 100;
    wire [9:0] tens = (N % 100) / 10;
    wire [9:0] ones = N % 10;
    
    wire [9:0] digit_sum = hundreds + tens + ones;
    
    assign binary_sum = digit_sum[4:0];
    
endmodule