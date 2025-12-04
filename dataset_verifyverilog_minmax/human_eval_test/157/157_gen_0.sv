module right_angle_triangle(
    input [7:0] a, b, c,
    output reg is_right
);
    
    // Calculate squares (16-bit)
    wire [15:0] a_sq, b_sq, c_sq;
    assign a_sq = a * a;
    assign b_sq = b * b;
    assign c_sq = c * c;
    
    // Calculate sums (17-bit to prevent overflow)
    wire [16:0] ab_sum, ac_sum, bc_sum;
    assign ab_sum = a_sq + b_sq;
    assign ac_sum = a_sq + c_sq;
    assign bc_sum = b_sq + c_sq;
    
    // Check Pythagorean theorem
    always @(*) begin
        is_right = (ab_sum == c_sq) || (ac_sum == b_sq) || (bc_sum == a_sq);
    end
    
endmodule