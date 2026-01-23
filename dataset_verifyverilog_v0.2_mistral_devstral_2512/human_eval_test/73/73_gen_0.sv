module smallest_change (
  input [3:0] arr [0:7],
  output [3:0] changes
);

  wire [3:0] mismatch_count;

  assign mismatch_count[0] = (arr[0] != arr[7]);
  assign mismatch_count[1] = (arr[1] != arr[6]);
  assign mismatch_count[2] = (arr[2] != arr[5]);
  assign mismatch_count[3] = (arr[3] != arr[4]);

  assign changes = mismatch_count[0] + mismatch_count[1] + mismatch_count[2] + mismatch_count[3];

endmodule