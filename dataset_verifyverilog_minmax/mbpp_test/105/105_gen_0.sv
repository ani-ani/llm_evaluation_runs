module count_trues(input [7:0] lst, output [3:0] count);
  assign count = $countones(lst);
endmodule