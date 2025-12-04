module count_lists_in_tuple(input [31:0] elements, input [3:0] is_list, output [2:0] list_count);
  assign list_count = is_list[0] + is_list[1] + is_list[2] + is_list[3];
endmodule