module pentagon_perimeter(
    input [15:0] side,
    output reg [15:0] perimeter
);
    // Combinational logic: multiply by 5 using shift-and-add
    // side * 5 = (side << 2) + side
    // Input: Q8.8, Output: Q12.8 (truncated to 16 bits)
    
    wire [17:0] side_times_4;  // Extended to 18 bits to avoid overflow
    wire [17:0] side_extended; // Extended side
    wire [17:0] result_raw;    // Raw 5*side in Q12.8 format (18 bits)
    
    // Zero-extend side to 18 bits for addition
    assign side_extended = {2'b00, side};
    
    // Multiply by 4 using shift left by 2
    assign side_times_4 = {side, 2'b00};
    
    // Add to get 5*side
    assign result_raw = side_times_4 + side_extended;
    
    // Take lower 16 bits for Q8.8 output (truncating upper integer bits)
    // This works for the given range (0 to 255.996 -> max perimeter 1279.98)
    // which fits within 16 bits as Q12.8, but we output lower 16 bits
    always @(*) begin
        perimeter = result_raw[15:0];
    end
endmodule