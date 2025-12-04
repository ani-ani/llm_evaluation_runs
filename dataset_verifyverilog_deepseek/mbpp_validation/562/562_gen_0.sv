module max_sublist_length(input [2:0] length1, input [2:0] length2, input [2:0] length3, input [2:0] length4, output reg [2:0] max_length);
  always_comb begin
    reg [2:0] temp_max1;
    reg [2:0] temp_max2;
    temp_max1 = (length1 > length2) ? length1 : length2;
    temp_max2 = (length3 > length4) ? length3 : length4;
    max_length = (temp_max1 > temp_max2) ? temp_max1 : temp_max2;
  end
endmodule