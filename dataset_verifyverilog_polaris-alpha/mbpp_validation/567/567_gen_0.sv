module sorted_checker(
  input  [39:0] flat_list,
  output       is_sorted
);

  wire [4:0] elem0 = flat_list[4:0];
  wire [4:0] elem1 = flat_list[9:5];
  wire [4:0] elem2 = flat_list[14:10];
  wire [4:0] elem3 = flat_list[19:15];
  wire [4:0] elem4 = flat_list[24:20];
  wire [4:0] elem5 = flat_list[29:25];
  wire [4:0] elem6 = flat_list[34:30];
  wire [4:0] elem7 = flat_list[39:35];

  assign is_sorted = (elem0 <= elem1) &&
                     (elem1 <= elem2) &&
                     (elem2 <= elem3) &&
                     (elem3 <= elem4) &&
                     (elem4 <= elem5) &&
                     (elem5 <= elem6) &&
                     (elem6 <= elem7);

endmodule