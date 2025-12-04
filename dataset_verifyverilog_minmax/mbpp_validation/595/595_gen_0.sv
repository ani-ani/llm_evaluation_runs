module min_swaps(
  input reg [3:0] str1,
  input reg [3:0] str2,
  output reg [2:0] swap_count,
  output reg error
);

  // Count mismatches
  wire [3:0] mismatches;
  assign mismatches = str1 ^ str2;
  // Sum ones in mismatches (0..4)
  integer cnt;
  always @(*) begin
    cnt = 0;
    cnt = cnt + mismatches[0];
    cnt = cnt + mismatches[1];
    cnt = cnt + mismatches[2];
    cnt = cnt + mismatches[3];
  end

  // If odd mismatches => error
  assign error = cnt[0];
  // Even mismatches => swaps = cnt/2
  assign swap_count = (cnt >> 1);

endmodule