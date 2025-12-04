module elementwise_and (input [19:0] tuple1, tuple2, output [19:0] result_tuple);
  assign result_tuple = { (tuple1[19:15] & tuple2[19:15]),
                          (tuple1[14:10] & tuple2[14:10]),
                          (tuple1[9:5] & tuple2[9:5]),
                          (tuple1[4:0] & tuple2[4:0]) };
endmodule