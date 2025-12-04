module odd_position_checker (
    input reg [7:0] nums [8],  // 8 elements of 8 bits each
    output reg is_correct       // 1-bit output
);
    
    always_comb begin
        is_correct = 1'b1;  // Initialize to 1 (assume correct)
        
        for (int i = 0; i < 8; i++) begin
            if (i % 2 == 0) begin  // Even index
                // Check LSB is 0 (even number)
                if (nums[i][0] != 1'b0) begin
                    is_correct = 1'b0;
                end
            end else begin  // Odd index
                // Check LSB is 1 (odd number)
                if (nums[i][0] != 1'b1) begin
                    is_correct = 1'b0;
                end
            end
        end
    end
endmodule