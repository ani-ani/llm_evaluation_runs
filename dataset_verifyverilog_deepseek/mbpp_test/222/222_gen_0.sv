module check_tuple_type(input reg [5:0][1:0] types, output all_same);
  assign all_same = (types[1] == types[0]) &
                    (types[2] == types[0]) &
                    (types[3] == types[0]) &
                    (types[4] == types[0]) &
                    (types[5] == types[0]);
endmodule