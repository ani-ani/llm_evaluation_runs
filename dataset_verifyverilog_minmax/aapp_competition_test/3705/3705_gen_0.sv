module phone_number_counter(
  input [4:0] n,           // Number of cards (1-32)
  input [127:0] s,         // 32 digits packed left-aligned (MSB [127:124] = first digit)
  output reg [1:0] count   // Maximum number of phone numbers (0-2)
);
  // Detect '8' for each 4-bit digit and build validity mask for first n digits
  wire [31:0] is_eight;
  wire [31:0] valid;
  genvar i;
  generate
    for (i = 0; i < 32; i++) begin : DIGIT_COMPARE
      // s[127 - 4*i -: 4] is digit i (0 is first, 31 is last)
      assign is_eight[i] = (s[(127 - i*4) -: 4] == 4'd8);
      assign valid[i]    = (i < n);
    end
  endgenerate

  // Count '8's only in the first n valid digits (ad-hoc adder)
  wire [5:0] eight_cnt = (is_eight & valid);

  // Determine floor(n/11) with parallel logic (0, 1, or 2)
  wire n_ge_11 = n >= 5'd11;
  wire n_ge_22 = n >= 5'd22;
  wire [1:0] max_by_n = n_ge_22 ? 2'd2 : (n_ge_11 ? 2'd1 : 2'd0);

  // Clamp eight count to 2 (since count output is 2 bits)
  wire [1:0] eight_count = eight_cnt > 5'd2 ? 2'd2 : eight_cnt[1:0];

  // Final answer: min(eight_count, floor(n/11))
  always @(*) begin
    count = (eight_count < max_by_n) ? eight_count : max_by_n;
  end
endmodule
