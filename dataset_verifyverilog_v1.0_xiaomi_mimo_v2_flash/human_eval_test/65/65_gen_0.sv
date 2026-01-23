module circular_shift(
    input [31:0] x,
    input [4:0] shift,
    output [31:0] result
);
    // Combinational circular right shift (rotate right)
    // For shift amount k: result = {x[k-1:0], x[31:k]}
    // Need to handle k=0 case separately to avoid negative index
    
    wire [31:0] shifted;
    
    // Generate rotated result
    assign shifted = {x[shift-1:0], x[31:shift]};
    
    // When shift=0, use original x (no shift)
    assign result = (shift == 5'd0) ? x : shifted;
    
endmodule