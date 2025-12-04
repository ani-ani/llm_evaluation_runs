module tuple_comparator(input [7:0] t1[3:0], input [7:0] t2[3:0], output reg result);
  always @* begin
    result = (t1[0] > t2[0]) && (t1[1] > t2[1]) && (t1[2] > t2[2]) && (t1[3] > t2[3]);
  end
endmodule