module compare_arrays(
    input [7:0] score [0:7],
    input [7:0] guess [0:7],
    output [7:0] result [0:7]
);

    // Compute element-wise absolute difference
    // Each element is computed independently in always_comb block
    
    always_comb begin
        integer i;
        reg signed [8:0] diff;  // Extended to 9 bits to prevent overflow
        reg signed [8:0] abs_diff;
        
        for (i = 0; i < 8; i = i + 1) begin
            // Compute signed difference (extended to 9 bits)
            diff = {score[i][7], score[i]} - {guess[i][7], guess[i]};
            
            // Compute absolute value
            if (diff == 9'sd0) begin
                result[i] = 8'd0;
            end else if (diff[8]) begin
                // Negative: negate (two's complement)
                abs_diff = -diff;
                result[i] = abs_diff[7:0];  // Clamp to 8 bits (max 255)
            end else begin
                // Positive
                result[i] = diff[7:0];  // Direct assignment
            end
        end
    end

endmodule