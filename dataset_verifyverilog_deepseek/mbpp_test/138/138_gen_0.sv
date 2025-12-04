module check_power_sum(input reg [7:0] n, output result);
  assign result = (n[0] == 0) ? 1'b1 : 1'b0;
endmodule