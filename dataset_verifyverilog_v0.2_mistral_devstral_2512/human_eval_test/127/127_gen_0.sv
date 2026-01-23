module interval_intersection_prime (
  input signed [7:0] start1, end1,
  input signed [7:0] start2, end2,
  output is_prime
);

  // Calculate intersection start and end
  wire signed [7:0] intersection_start = (start1 > start2) ? start1 : start2;
  wire signed [7:0] intersection_end = (end1 < end2) ? end1 : end2;

  // Calculate intersection length
  wire signed [7:0] length = intersection_end - intersection_start;

  // Check if length is prime
  assign is_prime = (length > 0) && 
                    (length == 2 || length == 3 || length == 5 || length == 7 || 
                     length == 11 || length == 13 || length == 17 || length == 19 || 
                     length == 23 || length == 29 || length == 31 || length == 37 || 
                     length == 41 || length == 43 || length == 47 || length == 53 || 
                     length == 59 || length == 61);

endmodule