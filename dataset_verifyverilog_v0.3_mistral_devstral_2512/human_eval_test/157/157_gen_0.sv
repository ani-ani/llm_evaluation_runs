module right_angle_triangle(
    input [7:0] side_a,
    input [7:0] side_b,
    input [7:0] side_c,
    output result
);
    wire [15:0] sq_a;
    wire [15:0] sq_b;
    wire [15:0] sq_c;
    wire [15:0] sum_ab;
    wire [15:0] sum_ac;
    wire [15:0] sum_bc;
    
    assign sq_a = side_a * side_a;
    assign sq_b = side_b * side_b;
    assign sq_c = side_c * side_c;
    
    assign sum_ab = sq_a + sq_b;
    assign sum_ac = sq_a + sq_c;
    assign sum_bc = sq_b + sq_c;
    
    assign result = (sq_c == sum_ab) || (sq_b == sum_ac) || (sq_a == sum_bc);
endmodule