module WheelRotationSolver(
    input [1:0] wheel0 [0:7],
    input [1:0] wheel1 [0:7],
    input [1:0] wheel2 [0:7],
    output reg [4:0] result
);
    // Internal variables
    reg [3:0] min_cost;
    reg valid;
    reg [3:0] r0, r1, r2;
    reg [3:0] c0, c1, c2;
    reg [3:0] idx0, idx1, idx2;
    reg [3:0] cost;
    reg all_columns_valid;
    reg diff_01, diff_02, diff_12;
    integer j;
    
    always @(*) begin
        // Initialize
        min_cost = 4'd15; // Max possible cost is 12 (4+4+4)
        valid = 1'b0;
        result = 5'd31; // Default -1 (11111)
        
        // Try all rotation combinations
        for (r0 = 0; r0 < 8; r0 = r0 + 1) begin
            // Compute cost for r0
            c0 = (r0 <= 4) ? r0 : (8 - r0);
            
            for (r1 = 0; r1 < 8; r1 = r1 + 1) begin
                // Compute cost for r1
                c1 = (r1 <= 4) ? r1 : (8 - r1);
                
                for (r2 = 0; r2 < 8; r2 = r2 + 1) begin
                    // Compute cost for r2
                    c2 = (r2 <= 4) ? r2 : (8 - r2);
                    
                    // Total cost for this rotation combination
                    cost = c0 + c1 + c2;
                    
                    // Check all 8 columns
                    all_columns_valid = 1'b1;
                    
                    for (j = 0; j < 8; j = j + 1) begin
                        // Compute rotated indices
                        idx0 = (j + r0) % 8;
                        idx1 = (j + r1) % 8;
                        idx2 = (j + r2) % 8;
                        
                        // Check if all three letters are different
                        // A=00, B=01, C=10
                        // All different if no two are equal
                        diff_01 = (wheel0[idx0] != wheel1[idx1]);
                        diff_02 = (wheel0[idx0] != wheel2[idx2]);
                        diff_12 = (wheel1[idx1] != wheel2[idx2]);
                        
                        if (!(diff_01 && diff_02 && diff_12)) begin
                            all_columns_valid = 1'b0;
                        end
                    end
                    
                    // If all columns are valid and cost is lower than current minimum
                    if (all_columns_valid) begin
                        if (!valid || cost < min_cost) begin
                            min_cost = cost;
                            valid = 1'b1;
                        end
                    end
                end
            end
        end
        
        // Set output result
        if (valid) begin
            result = {1'b0, min_cost}; // Extend to 5 bits (unsigned)
        end else begin
            result = 5'b11111; // -1 for impossible
        end
    end
endmodule