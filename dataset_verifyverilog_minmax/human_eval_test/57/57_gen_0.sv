module monotonic_check (
  input wire [2:0] length,
  input reg signed [7:0] arr [0:7],
  output wire is_monotonic
);
  // Determine if the first L elements of arr are monotonic (non-decreasing or non-increasing).

  wire inc_ok; // non-decreasing: arr[i] <= arr[i+1]
  wire dec_ok; // non-increasing: arr[i] >= arr[i+1]

  // combinational monotonic check for all pairs 0..6
  // length==1 -> inc_ok and dec_ok default to 1
  // For length>1, check all required pairs, ignore others.

  // Check non-decreasing: all arr[i] <= arr[i+1] for i in [0, length-2]
  // If length <= 1, there are no pairs to check, so inc_ok = 1.
  assign inc_ok = (length <= 1) ? 1'b1 :
                  ((arr[0] <= arr[1]) &&
                   (length <= 2 || arr[1] <= arr[2]) &&
                   (length <= 3 || arr[2] <= arr[3]) &&
                   (length <= 4 || arr[3] <= arr[4]) &&
                   (length <= 5 || arr[4] <= arr[5]) &&
                   (length <= 6 || arr[5] <= arr[6]) &&
                   (length <= 7 || arr[6] <= arr[7]));

  // Check non-increasing: all arr[i] >= arr[i+1] for i in [0, length-2]
  // If length <= 1, there are no pairs to check, so dec_ok = 1.
  assign dec_ok = (length <= 1) ? 1'b1 :
                  ((arr[0] >= arr[1]) &&
                   (length <= 2 || arr[1] >= arr[2]) &&
                   (length <= 3 || arr[2] >= arr[3]) &&
                   (length <= 4 || arr[3] >= arr[4]) &&
                   (length <= 5 || arr[4] >= arr[5]) &&
                   (length <= 6 || arr[5] >= arr[6]) &&
                   (length <= 7 || arr[6] >= arr[7]));

  // Monotonic if either non-decreasing or non-increasing holds.
  assign is_monotonic = inc_ok | dec_ok;

endmodule
