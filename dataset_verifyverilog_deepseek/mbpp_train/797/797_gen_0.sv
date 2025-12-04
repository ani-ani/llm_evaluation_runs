module sum_odds_range (
    input [7:0] l,
    input [7:0] r,
    output [15:0] sum
);

    wire [8:0] r_plus1 = {1'b0, r} + 9'd1;
    wire [7:0] half_r = r_plus1[8:1];
    wire [15:0] r_sum = half_r * half_r;
    
    wire [7:0] half_l = l >> 1;
    wire [15:0] l_sum = half_l * half_l;
    
    wire l_odd = l[0];
    
    assign sum = r_sum - l_sum + l_odd;
    
endmodule