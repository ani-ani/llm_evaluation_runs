module odd_fourth_power_sum (
  input [3:0] n,
  output [31:0] sum
);

  // Precompute all possible sums for n=1 to 8
  // n=1: 1^4 = 1
  // n=2: 1 + 81 = 82
  // n=3: 82 + 625 = 707
  // n=4: 707 + 2401 = 3108
  // n=5: 3108 + 6561 = 9669
  // n=6: 9669 + 14641 = 24310
  // n=7: 24310 + 28561 = 52871
  // n=8: 52871 + 4096 = 56967

  always_comb begin
    case (n)
      4'd1: sum = 32'd1;
      4'd2: sum = 32'd82;
      4'd3: sum = 32'd707;
      4'd4: sum = 32'd3108;
      4'd5: sum = 32'd9669;
      4'd6: sum = 32'd24310;
      4'd7: sum = 32'd52871;
      4'd8: sum = 32'd56967;
      default: sum = 32'd0; // For n=0 or invalid values
    endcase
  end

endmodule