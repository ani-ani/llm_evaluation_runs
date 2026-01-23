module right_angle_triangle(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output reg result
);

// Intermediate signals for squared values
wire [15:0] a_sq;
wire [15:0] b_sq;
wire [15:0] c_sq;
wire [15:0] sum_ab;
wire [15:0] sum_ac;
wire [15:0] sum_bc;

// Combinational logic for squaring
assign a_sq = a * a;
assign b_sq = b * b;
assign c_sq = c * c;

// Combinational logic for summing pairs
assign sum_ab = a_sq + b_sq;
assign sum_ac = a_sq + c_sq;
assign sum_bc = b_sq + c_sq;

// Check all three permutations for right angle condition
always @(*) begin
    // Also ensure sides are non-zero to avoid trivial cases
    if ((sum_ab == c_sq || sum_ac == b_sq || sum_bc == a_sq) && a > 0 && b > 0 && c > 0) begin
        result = 1'b1;
    end else begin
        result = 1'b0;
    end
end

endmodule