module max_perimeter_rectangle (
    input [7:0] grid [0:7],
    output reg [6:0] max_perimeter
);

    integer r1, c1, r2, c2;
    reg [6:0] current_perimeter;
    reg valid;
    integer w, h;

    always @(*) begin
        max_perimeter = 0;
        
        // Iterate through all possible top-left corners
        for (r1 = 0; r1 < 8; r1 = r1 + 1) begin
            for (c1 = 0; c1 < 8; c1 = c1 + 1) begin
                // If top-left is blocked, skip
                if (grid[r1][c1] == 1'b1) continue;
                
                // Iterate through all possible bottom-right corners
                for (r2 = r1; r2 < 8; r2 = r2 + 1) begin
                    for (c2 = c1; c2 < 8; c2 = c2 + 1) begin
                        // Check if current rectangle is valid (all 0s)
                        valid = 1'b1;
                        
                        // Check the rectangle defined by (r1,c1) to (r2,c2)
                        // Check all rows from r1 to r2
                        // Optimization: if we encounter a blocked cell, mark invalid
                        if (valid) begin
                            // Check rows
                            for (int k = r1; k <= r2; k = k + 1) begin
                                // Check columns
                                for (int l = c1; l <= c2; l = l + 1) begin
                                    if (grid[k][l] == 1'b1) valid = 1'b0;
                                end
                            end
                        end
                        
                        // If valid, calculate perimeter
                        if (valid) begin
                            w = c2 - c1 + 1;
                            h = r2 - r1 + 1;
                            current_perimeter = 2 * (w + h);
                            if (current_perimeter > max_perimeter) begin
                                max_perimeter = current_perimeter;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule