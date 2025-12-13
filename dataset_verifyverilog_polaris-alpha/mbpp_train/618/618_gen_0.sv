module element_wise_div(
  input  [3:0][7:0]  nums1,
  input  [3:0][7:0]  nums2,
  output [3:0][15:0] result
);

  assign result[0] = (nums1[0] * 16'd256) / nums2[0];
  assign result[1] = (nums1[1] * 16'd256) / nums2[1];
  assign result[2] = (nums1[2] * 16'd256) / nums2[2];
  assign result[3] = (nums1[3] * 16'd256) / nums2[3];

endmodule