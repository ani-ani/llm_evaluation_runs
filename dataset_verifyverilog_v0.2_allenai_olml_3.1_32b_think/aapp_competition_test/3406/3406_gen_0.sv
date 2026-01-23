module castle_danger_checker (input signed [31:0] n1_x, n1_y, n2_x, n2_y, n3_x, n3_y, n4_x, n4_y, input signed [31:0] c1_x, c1_y, c2_x, c2_y, c3_x, c3_y, c4_x, c4_y, output reg [3:0] danger);
function automatic bit check_castle (input signed [31:0] n1_x, n1_y, n2_x, n2_y, n3_x, n3_y, n4_x, n4_y, input signed [31:0] cx, cy);
integer cross1, cross2, cross3, cross4;
cross1 = (n2_x - n1_x) * (cy - n1_y) - (n2_y - n1_y) * (cx - n1_x);
cross2 = (n3_x - n2_x) * (cy - n2_y) - (n3_y - n2_y) * (cx - n2_x);
cross3 = (n4_x - n3_x) * (cy - n3_y) - (n4_y - n3_y) * (cx - n3_x);
cross4 = (n1_x - n4_x) * (cy - n4_y) - (n1_y - n4_y) * (cx - n4_x);
if (cross1 >=0 && cross2 >=0 && cross3 >=0 && cross4 >=0) return 1;
if (cross1 <=0 && cross2 <=0 && cross3 <=0 && cross4 <=0) return 1;
return 0;
endfunction
assign danger[0] = check_castle(n1_x, n1_y, n2_x, n2_y, n3_x, n3_y, n4_x, n4_y, c1_x, c1_y);
assign danger[1] = check_castle(n1_x, n1_y, n2_x, n2_y, n3_x, n3_y, n4_x, n4_y, c2_x, c2_y);
assign danger[2] = check_castle(n1_x, n1_y, n2_x, n2_y, n3_x, n3_y, n4_x, n4_y, c3_x, c3_y);
assign danger[3] = check_castle(n1_x, n1_y, n2_x, n2_y, n3_x, n3_y, n4_x, n4_y, c4_x, c4_y);
endmodule