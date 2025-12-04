module count_trues(input reg [7:0] lst, output reg [3:0] count);
  wire [1:0] sum01 = lst[0] + lst[1];
  wire [1:0] sum23 = lst[2] + lst[3];
  wire [1:0] sum45 = lst[4] + lst[5];
  wire [1:0] sum67 = lst[6] + lst[7];
  wire [2:0] sum0123 = sum01 + sum23;
  wire [2:0] sum4567 = sum45 + sum67;
  assign count = sum0123 + sum4567;
endmodule