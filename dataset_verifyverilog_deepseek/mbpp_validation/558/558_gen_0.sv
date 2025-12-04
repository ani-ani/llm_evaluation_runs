module digit_distance (input [15:0] n1, input [15:0] n2, output [5:0] result);
  wire [16:0] sub1 = {1'b0, n1} - {1'b0, n2};
  wire [16:0] sub2 = {1'b0, n2} - {1'b0, n1};
  wire [16:0] abs_diff = (n1 >= n2) ? sub1 : sub2;
  wire [3:0] digit0 = abs_diff % 10;
  wire [3:0] digit1 = (abs_diff / 10) % 10;
  wire [3:0] digit2 = (abs_diff / 100) % 10;
  wire [3:0] digit3 = (abs_diff / 1000) % 10;
  wire [3:0] digit4 = (abs_diff / 10000) % 10;
  wire [3:0] digit5 = (abs_diff / 100000) % 10;
  assign result = digit0 + digit1 + digit2 + digit3 + digit4 + digit5;
endmodule