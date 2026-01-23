module count_same_pair (
  input [7:0] nums1,
  input [7:0] nums2,
  output [3:0] count
);

  wire [7:0] matches;
  genvar i;

  generate
    for (i = 0; i < 8; i = i + 1) begin : compare_loop
      assign matches[i] = (nums1[i] == nums2[i]);
    end
  endgenerate

  assign count = +matches;

endmodule