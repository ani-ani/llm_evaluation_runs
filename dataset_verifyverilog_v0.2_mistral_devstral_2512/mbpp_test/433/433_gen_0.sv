module check_greater (
  input [7:0] number,
  input [7:0] arr [0:7],
  output result
);

  wire [0:7] comparisons;
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : compare_loop
      assign comparisons[i] = (number > arr[i]);
    end
  endgenerate

  assign result = comparisons[0] &
                  comparisons[1] &
                  comparisons[2] &
                  comparisons[3] &
                  comparisons[4] &
                  comparisons[5] &
                  comparisons[6] &
                  comparisons[7];

endmodule