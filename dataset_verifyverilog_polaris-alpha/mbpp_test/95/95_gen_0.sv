module min_sublist_length(
  input  [3:0] sublist0,
  input  [3:0] sublist1,
  input  [3:0] sublist2,
  input  [3:0] sublist3,
  output [2:0] min_length
);

  wire [2:0] length0;
  wire [2:0] length1;
  wire [2:0] length2;
  wire [2:0] length3;

  assign length0 = sublist0[0] + sublist0[1] + sublist0[2] + sublist0[3];
  assign length1 = sublist1[0] + sublist1[1] + sublist1[2] + sublist1[3];
  assign length2 = sublist2[0] + sublist2[1] + sublist2[2] + sublist2[3];
  assign length3 = sublist3[0] + sublist3[1] + sublist3[2] + sublist3[3];

  wire [2:0] min01 = (length0 < length1) ? length0 : length1;
  wire [2:0] min23 = (length2 < length3) ? length2 : length3;

  assign min_length = (min01 < min23) ? min01 : min23;

endmodule