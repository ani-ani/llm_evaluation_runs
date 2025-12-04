module find_min(
  input [7:0] numbers [0:7],
  input [2:0] count,
  output [7:0] min_num
);

  wire [7:0] masked [0:7];
  
  generate
    for (genvar i = 0; i < 8; i++) begin : mask_gen
      assign masked[i] = (i < count) ? numbers[i] : 8'hFF;
    end
  endgenerate
  
  function automatic [7:0] min2(input [7:0] a, input [7:0] b);
    min2 = (a < b) ? a : b;
  endfunction
  
  wire [7:0] l1 [0:3];
  assign l1[0] = min2(masked[0], masked[1]);
  assign l1[1] = min2(masked[2], masked[3]);
  assign l1[2] = min2(masked[4], masked[5]);
  assign l1[3] = min2(masked[6], masked[7]);
  
  wire [7:0] l2 [0:1];
  assign l2[0] = min2(l1[0], l1[1]);
  assign l2[1] = min2(l1[2], l1[3]);
  
  wire [7:0] l3;
  assign l3 = min2(l2[0], l2[1]);
  
  assign min_num = l3;

endmodule