module three_equal_counter (
    input wire [7:0] x,    // First number (signed)
    input wire [7:0] y,    // Second number (signed)
    input wire [7:0] z,    // Third number (signed)
    output reg [2:0] result // 0, 2, or 3
);

    // Combinational logic to count equal numbers
    // Returns:
    // - 0 if all three are different
    // - 2 if exactly two are equal
    // - 3 if all three are equal
    
    wire eq_xy;  // x == y
    wire eq_xz;  // x == z
    wire eq_yz;  // y == z
    
    assign eq_xy = (x == y);
    assign eq_xz = (x == z);
    assign eq_yz = (y == z);
    
    always @(*) begin
        // Count based on equalities
        // If all three equal: eq_xy, eq_xz, eq_yz are all 1
        // If two equal: exactly one of them is 0, two are 1
        // If all different: all three are 0
        
        if (eq_xy && eq_xz && eq_yz) begin
            result = 3'd3;
        end else if (eq_xy || eq_xz || eq_yz) begin
            result = 3'd2;
        end else begin
            result = 3'd0;
        end
    end

endmodule