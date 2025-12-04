module elementwise_and(input [19:0] tuple1, input [19:0] tuple2, output [19:0] result_tuple);
  assign result_tuple = tuple1 & tuple2;
endmodule