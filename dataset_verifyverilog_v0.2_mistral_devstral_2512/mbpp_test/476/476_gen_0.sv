module big_sum (
  input [2:0] array_size,
  input [7:0] nums [0:7],
  output [7:0] result
);

  wire [7:0] min_val;
  wire [7:0] max_val;

  // Find min and max using tree of comparators
  assign min_val = (array_size == 0) ? 8'b0 : 
                   (array_size == 1) ? nums[0] :
                   (array_size == 2) ? (nums[0] < nums[1] ? nums[0] : nums[1]) :
                   (array_size == 3) ? ((nums[0] < nums[1] ? nums[0] : nums[1]) < nums[2] ? (nums[0] < nums[1] ? nums[0] : nums[1]) : nums[2]) :
                   (array_size == 4) ? (((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) :
                   (array_size == 5) ? ((((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) < nums[4] ? ((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) : nums[4]) :
                   (array_size == 6) ? ((((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) < ((nums[4] < nums[5] ? nums[4] : nums[5]) ? ((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) : (nums[4] < nums[5] ? nums[4] : nums[5])) :
                   (array_size == 7) ? ((((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) < ((nums[4] < nums[5] ? nums[4] : nums[5]) < nums[6] ? (nums[4] < nums[5] ? nums[4] : nums[5]) : nums[6]) ? ((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) : ((nums[4] < nums[5] ? nums[4] : nums[5]) < nums[6] ? (nums[4] < nums[5] ? nums[4] : nums[5]) : nums[6])) :
                   (((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) < ((nums[4] < nums[5] ? nums[4] : nums[5]) < (nums[6] < nums[7] ? nums[6] : nums[7]) ? (nums[4] < nums[5] ? nums[4] : nums[5]) : (nums[6] < nums[7] ? nums[6] : nums[7])) ? ((nums[0] < nums[1] ? nums[0] : nums[1]) < (nums[2] < nums[3] ? nums[2] : nums[3]) ? (nums[0] < nums[1] ? nums[0] : nums[1]) : (nums[2] < nums[3] ? nums[2] : nums[3])) : ((nums[4] < nums[5] ? nums[4] : nums[5]) < (nums[6] < nums[7] ? nums[6] : nums[7]) ? (nums[4] < nums[5] ? nums[4] : nums[5]) : (nums[6] < nums[7] ? nums[6] : nums[7])));

  assign max_val = (array_size == 0) ? 8'b0 :
                   (array_size == 1) ? nums[0] :
                   (array_size == 2) ? (nums[0] > nums[1] ? nums[0] : nums[1]) :
                   (array_size == 3) ? ((nums[0] > nums[1] ? nums[0] : nums[1]) > nums[2] ? (nums[0] > nums[1] ? nums[0] : nums[1]) : nums[2]) :
                   (array_size == 4) ? (((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) :
                   (array_size == 5) ? ((((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) > nums[4] ? ((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) : nums[4]) :
                   (array_size == 6) ? ((((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) > ((nums[4] > nums[5] ? nums[4] : nums[5]) ? ((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) : (nums[4] > nums[5] ? nums[4] : nums[5])) :
                   (array_size == 7) ? ((((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) > ((nums[4] > nums[5] ? nums[4] : nums[5]) > nums[6] ? (nums[4] > nums[5] ? nums[4] : nums[5]) : nums[6]) ? ((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) : ((nums[4] > nums[5] ? nums[4] : nums[5]) > nums[6] ? (nums[4] > nums[5] ? nums[4] : nums[5]) : nums[6])) :
                   (((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) > ((nums[4] > nums[5] ? nums[4] : nums[5]) > (nums[6] > nums[7] ? nums[6] : nums[7]) ? (nums[4] > nums[5] ? nums[4] : nums[5]) : (nums[6] > nums[7] ? nums[6] : nums[7])) ? ((nums[0] > nums[1] ? nums[0] : nums[1]) > (nums[2] > nums[3] ? nums[2] : nums[3]) ? (nums[0] > nums[1] ? nums[0] : nums[1]) : (nums[2] > nums[3] ? nums[2] : nums[3])) : ((nums[4] > nums[5] ? nums[4] : nums[5]) > (nums[6] > nums[7] ? nums[6] : nums[7]) ? (nums[4] > nums[5] ? nums[4] : nums[5]) : (nums[6] > nums[7] ? nums[6] : nums[7])));

  // Add min and max
  assign result = min_val + max_val;

endmodule