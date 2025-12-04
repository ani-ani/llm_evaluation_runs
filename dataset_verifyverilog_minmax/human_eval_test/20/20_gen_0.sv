module closest_pair(input [255:0] numbers_packed, output reg [63:0] closest_pair);
  logic [31:0] e [0:7];

  // Unpack 8 elements (Q8.24 fixed-point)
  assign e[0] = numbers_packed[31:0];
  assign e[1] = numbers_packed[63:32];
  assign e[2] = numbers_packed[95:64];
  assign e[3] = numbers_packed[127:96];
  assign e[4] = numbers_packed[159:128];
  assign e[5] = numbers_packed[191:160];
  assign e[6] = numbers_packed[223:192];
  assign e[7] = numbers_packed[255:224];

  // Compute all 28 pairs, find smallest absolute difference (tie-break by smaller ei)
  logic [31:0] min_diff;
  integer best_i, best_j;
  logic [31:0] diff;

  always_comb begin
    min_diff = 32'hFFFFFFFF;
    best_i = 0;
    best_j = 1;
    for (int i = 0; i < 7; i++) begin
      for (int j = i + 1; j < 8; j++) begin
        diff = (e[i] > e[j]) ? (e[i] - e[j]) : (e[j] - e[i]);
        if (diff < min_diff) begin
          min_diff = diff;
          best_i = i;
          best_j = j;
        end
      end
    end
    // Output {smaller, larger} as two 32-bit values
    if (e[best_i] <= e[best_j]) begin
      closest_pair = {e[best_i], e[best_j]};
    end else begin
      closest_pair = {e[best_j], e[best_i]};
    end
  end
endmodule