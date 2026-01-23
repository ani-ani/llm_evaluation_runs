module right_angle_triangle(
    input [7:0] side_a,
    input [7:0] side_b,
    input [7:0] side_c,
    output reg result
);
    // Calculate squares using 16-bit arithmetic to avoid overflow
    wire [15:0] sq_a;
    wire [15:0] sq_b;
    wire [15:0] sq_c;
    
    // 8x8 multiplication results in 16-bit product
    assign sq_a = side_a * side_a;
    assign sq_b = side_b * side_b;
    assign sq_c = side_c * side_c;
    
    // Check Pythagorean theorem conditions
    wire condition_a;  // a^2 == b^2 + c^2
    wire condition_b;  // b^2 == a^2 + c^2
    wire condition_c;  // c^2 == a^2 + b^2
    
    assign condition_a = (sq_a == (sq_b + sq_c));
    assign condition_b = (sq_b == (sq_a + sq_c));
    assign condition_c = (sq_c == (sq_a + sq_b));
    
    // Result is high if any condition is true
    always @(*) begin
        result = condition_a || condition_b || condition_c;
    end
    
endmodule