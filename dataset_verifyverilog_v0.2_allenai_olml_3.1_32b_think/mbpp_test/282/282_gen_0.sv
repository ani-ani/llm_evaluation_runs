module sub_list(input reg [2:0] length, input reg [7:0] nums1 [0:7], input reg [7:0] nums2 [0:7], output [7:0] result [0:7]);
 genvar i;
 generate
 for (i=0; i<8; i++) begin
 assign result[i] = nums1[i] - nums2[i];
 end
 endgenerate
 endmodule