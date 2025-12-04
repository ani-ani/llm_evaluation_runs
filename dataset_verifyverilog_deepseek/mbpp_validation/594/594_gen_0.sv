module first_even_odd_diff (
  input signed [7:0] list [0:7],
  output signed [8:0] difference
);
  wire signed [7:0] found_first_even;
  wire signed [7:0] found_first_odd;
  
  assign found_first_even = (list[0][0] == 0) ? list[0] :
                          (list[1][0] == 0) ? list[1] :
                          (list[2][0] == 0) ? list[2] :
                          (list[3][0] == 0) ? list[3] :
                          (list[4][0] == 0) ? list[4] :
                          (list[5][0] == 0) ? list[5] :
                          (list[6][0] == 0) ? list[6] :
                          (list[7][0] == 0) ? list[1] :
                          8'sb11111111;
  
  assign found_first_odd = (list[0][0] == 1) ? list[0] :
                         (list[1][0] == 1) ? list[1] :
                         (list[2][0] == 1) ? list[2] :
                         (list[3][0] == 1) ? list[3] :
                         (list[4][0] == 1) ? list[4] :
                         (list[5][0] == 1) ? list[5] :
                         (list[6][0] == 1) ? list[6] :
                         (list[7][0] == 1) ? list[7] :
                         8'sb11111111;
  
  wire signed [8:0] ext_even = {found_first_even[7], found_first_even};
  wire signed [8:0] ext_odd = {found_first_odd[7], found_first_odd};
  assign difference = ext_even - ext_odd;
endmodule