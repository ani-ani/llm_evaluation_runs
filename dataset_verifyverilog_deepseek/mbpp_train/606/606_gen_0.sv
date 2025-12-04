module degree_to_radian(input reg [15:0] degree, output [31:0] radian);
  assign radian = degree * 32'h00000478;
endmodule