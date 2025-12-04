module element_wise_div(
  input [7:0] nums1 [0:3],
  input [7:0] nums2 [0:3],
  output reg [15:0] result [0:3]
);

  // Q8.8 fixed-point: treat inputs as integers with implicit scaling x*256.
  // Compute result[i] = (nums1[i] * 256) / nums2[i] with 16-bit output.
  always_comb begin
    result[0] = (nums1[0] << 8) / nums2[0];
    result[1] = (nums1[1] << 8) / nums2[1];
    result[2] = (nums1[2] << 8) / nums2[2];
    result[3] = (nums1[3] << 8) / nums2[3];
  end
endmodule