module diff_even_odd (
  input [7:0] list1 [0:7],
  output [7:0] diff
);

  wire [7:0] first_even;
  wire [7:0] first_odd;

  // Check if each element is even (LSB = 0)
  wire [7:0] is_even = {list1[0][0] == 0, list1[1][0] == 0, list1[2][0] == 0, list1[3][0] == 0,
                        list1[4][0] == 0, list1[5][0] == 0, list1[6][0] == 0, list1[7][0] == 0};

  // Check if each element is odd (LSB = 1)
  wire [7:0] is_odd = {list1[0][0] == 1, list1[1][0] == 1, list1[2][0] == 1, list1[3][0] == 1,
                       list1[4][0] == 1, list1[5][0] == 1, list1[6][0] == 1, list1[7][0] == 1};

  // Find first even: priority encoder for even elements
  wire [7:0] even_priority = ~|{is_even[0:0], is_even[0:1], is_even[0:2], is_even[0:3],
                                    is_even[0:4], is_even[0:5], is_even[0:6], is_even[0:7]};
  assign first_even = (is_even[0] & even_priority[0]) ? list1[0] :
                      (is_even[1] & even_priority[1]) ? list1[1] :
                      (is_even[2] & even_priority[2]) ? list1[2] :
                      (is_even[3] & even_priority[3]) ? list1[3] :
                      (is_even[4] & even_priority[4]) ? list1[4] :
                      (is_even[5] & even_priority[5]) ? list1[5] :
                      (is_even[6] & even_priority[6]) ? list1[6] :
                      (is_even[7] & even_priority[7]) ? list1[7] : 8'hFF;

  // Find first odd: priority encoder for odd elements
  wire [7:0] odd_priority = ~|{is_odd[0:0], is_odd[0:1], is_odd[0:2], is_odd[0:3],
                                  is_odd[0:4], is_odd[0:5], is_odd[0:6], is_odd[0:7]};
  assign first_odd = (is_odd[0] & odd_priority[0]) ? list1[0] :
                     (is_odd[1] & odd_priority[1]) ? list1[1] :
                     (is_odd[2] & odd_priority[2]) ? list1[2] :
                     (is_odd[3] & odd_priority[3]) ? list1[3] :
                     (is_odd[4] & odd_priority[4]) ? list1[4] :
                     (is_odd[5] & odd_priority[5]) ? list1[5] :
                     (is_odd[6] & odd_priority[6]) ? list1[6] :
                     (is_odd[7] & odd_priority[7]) ? list1[7] : 8'hFF;

  // Compute difference
  assign diff = first_even - first_odd;

endmodule