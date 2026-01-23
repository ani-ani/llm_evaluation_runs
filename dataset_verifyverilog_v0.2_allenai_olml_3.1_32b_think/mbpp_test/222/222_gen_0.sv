module check_same_type(input [7:0] data_array [0:7], output reg result);
  assign result = (data_array[1] == data_array[0]) & (data_array[2] == data_array[0]) & (data_array[3] == data_array[0]) & (data_array[4] == data_array[0]) & (data_array[5] == data_array[0]) & (data_array[6] == data_array[0]) & (data_array[7] == data_array[0]);
endmodule