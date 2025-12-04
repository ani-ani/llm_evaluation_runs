module array_comparator(input [3:0] number, input [7:0][3:0] arr, output result);
  wire [3:0] max01 = (arr[0] > arr[1]) ? arr[0] : arr[1];
  wire [3:0] max23 = (arr[2] > arr[3]) ? arr[2] : arr[3];
  wire [3:0] max45 = (arr[4] > arr[5]) ? arr[4] : arr[5];
  wire [3:0] max67 = (arr[6] > arr[7]) ? arr[6] : arr[7];
  wire [3:0] max0123 = (max01 > max23) ? max01 : max23;
  wire [3:0] max4567 = (max45 > max67) ? max45 : max67;
  wire [3:0] max_arr = (max0123 > max4567) ? max0123 : max4567;
  assign result = (number > max_arr);
endmodule