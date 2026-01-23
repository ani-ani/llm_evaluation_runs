module powers_of_two_sum(input [15:0] num, output reg result);
assign result = (num != 0) && (num & (num - 1));
endmodule