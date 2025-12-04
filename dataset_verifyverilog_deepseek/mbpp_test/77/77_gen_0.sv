module divisible_by_11(input [15:0] n, output logic is_divisible);
  logic [3:0] d0, d1, d2, d3, d4;
  assign d0 = n % 10;
  assign d1 = (n / 10) % 10;
  assign d2 = (n / 100) % 10;
  assign d3 = (n / 1000) % 10;
  assign d4 = (n / 10000) % 10;
  logic signed [5:0] alt_sum;
  assign alt_sum = $signed(d0) - $signed(d1) + $signed(d2) - $signed(d3) + $signed(d4);
  logic [4:0] abs_sum;
  assign abs_sum = (alt_sum < 0) ? -alt_sum : alt_sum;
  assign is_divisible = (abs_sum == 0) || (abs_sum == 11);
endmodule