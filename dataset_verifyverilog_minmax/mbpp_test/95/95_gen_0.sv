module min_sublist_length(
  input wire [3:0] sublist0, sublist1, sublist2, sublist3,
  output logic [2:0] min_length
);
  logic [2:0] len0, len1, len2, len3; assign len0 = $countones(sublist0); assign len1 = $countones(sublist1); assign len2 = $countones(sublist2); assign len3 = $countones(sublist3); assign min_length = (((len0 < len1) ? len0 : len1) < ((len2 < len3) ? len2 : len3)) ? (((len0 < len1) ? len0 : len1) : ((len2 < len3) ? len2 : len3));
endmodule