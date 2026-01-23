module array_sum_even_odd(
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg [15:0] result
);

    integer i;
    
    always @(*) begin
        // Initialize result to zero
        result = 16'd0;
        
        // Iterate through all 8 possible indices
        for (i = 0; i < 8; i = i + 1) begin
            // Check if index is within valid range (based on len)
            // and if index is odd (index % 2 == 1)
            // and if element is even (LSB == 0)
            if ((i < len) && i[0] && !arr[i][0]) begin
                result = result + arr[i];
            end
        end
    end

endmodule