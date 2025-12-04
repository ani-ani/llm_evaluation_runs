module array_rotation_counter (input reg [3:0] arr0, arr1, arr2, arr3, arr4, arr5, arr6, arr7, input reg [2:0] array_size, output reg [2:0] rotation_count);
  wire drop_1 = (array_size > 1) && (arr1 < arr0);
  wire drop_2 = (array_size > 2) && (arr2 < arr1);
  wire drop_3 = (array_size > 3) && (arr3 < arr2);
  wire drop_4 = (array_size > 4) && (arr4 < arr3);
  wire drop_5 = (array_size > 5) && (arr5 < arr4);
  wire drop_6 = (array_size > 6) && (arr6 < arr5);
  wire drop_7 = (array_size > 7) && (arr7 < arr6);
  always_comb begin
    casez ({drop_7, drop_6, drop_5, drop_4, drop_3, drop_2, drop_1})
      7'b??????1: rotation_count = 1;
      7'b?????10: rotation_count = 2;
      7'b????100: rotation_count = 3; 
      7'b???1000: rotation_count = 4;
      7'b??10000: rotation_count = 5;
      7'b?100000: rotation_count = 6;
      7'b1000000: rotation_count = 7;
      default: rotation_count = 0;
    endcase
  end
endmodule