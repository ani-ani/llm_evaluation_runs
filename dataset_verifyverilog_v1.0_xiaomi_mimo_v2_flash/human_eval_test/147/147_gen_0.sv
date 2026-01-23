module max_triples(
    input [5:0] n,
    output reg [31:0] result
);
    // Count of elements with remainder 1 (C1) and remainder 0 (C0)
    reg [6:0] c0;  // Max 60
    reg [6:0] c1;  // Max 60
    
    // Variables for combination calculation
    reg [31:0] comb_c0;  // C0 choose 3
    reg [31:0] comb_c1;  // C1 choose 3
    
    // Intermediate calculations for combinations
    reg [31:0] temp0, temp1, temp2, temp3, temp4, temp5;
    reg [31:0] div0, div1;
    
    // Calculate C0 and C1
    // Pattern: 5 ones, 1 zero per block of 6
    // C0 = (n + 5) / 6
    // C1 = n - C0
    always @(*) begin
        // Calculate C0: ceil(n/6) = (n+5)/6
        c0 = (n + 6'd5) / 6'd6;
        
        // Calculate C1: total - C0
        c1 = n - c0;
        
        // Calculate C0 choose 3 = C0 * (C0-1) * (C0-2) / 6
        if (c0 >= 3) begin
            temp0 = c0;
            temp1 = c0 - 6'd1;
            temp2 = c0 - 6'd2;
            temp3 = temp0 * temp1;
            temp4 = temp3 * temp2;
            // Division by 6: (temp4 / 2) / 3
            div0 = temp4 / 6'd2;
            comb_c0 = div0 / 6'd3;
        end else begin
            comb_c0 = 32'd0;
        end
        
        // Calculate C1 choose 3 = C1 * (C1-1) * (C1-2) / 6
        if (c1 >= 3) begin
            temp0 = c1;
            temp1 = c1 - 6'd1;
            temp2 = c1 - 6'd2;
            temp3 = temp0 * temp1;
            temp4 = temp3 * temp2;
            // Division by 6: (temp4 / 2) / 3
            div1 = temp4 / 6'd2;
            comb_c1 = div1 / 6'd3;
        end else begin
            comb_c1 = 32'd0;
        end
        
        // Result = C0C3 + C1C3
        result = comb_c0 + comb_c1;
    end
endmodule