module array_subtractor_3x8bit (
    // Input arrays: 3 elements each, 8-bit signed
    input signed [7:0] a_0,
    input signed [7:0] a_1,
    input signed [7:0] a_2,
    input signed [7:0] b_0,
    input signed [7:0] b_1,
    input signed [7:0] b_2,
    // Output array: 3 elements each, 8-bit signed
    output reg signed [7:0] result_0,
    output reg signed [7:0] result_1,
    output reg signed [7:0] result_2
);

    // Element-wise subtraction: result[i] = a[i] - b[i]
    // Using combinational logic (no clock/reset needed)
    // Each operation is 8-bit signed with wrap-around overflow
    
    always @(*) begin
        // Subtract element 0
        result_0 = a_0 - b_0;
        
        // Subtract element 1
        result_1 = a_1 - b_1;
        
        // Subtract element 2
        result_2 = a_2 - b_2;
    end

endmodule