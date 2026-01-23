module opposite_signs(input signed [7:0] x, input signed [7:0] y, output opposite);
assign opposite = (x ^ y)[7];
endmodule