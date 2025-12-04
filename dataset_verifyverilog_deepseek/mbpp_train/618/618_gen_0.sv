module element_wise_div (
  input [3:0][7:0] nums1,
  input [3:0][7:0] nums2,
  output [3:0][15:0] result
);

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      result[i] = ({nums1[i], 8'h00}) / nums2[i];
    end
  end

endmodule