module statue_rotator(
  input  [7:0][2:0] a,
  input  [7:0][2:0] b,
  output reg        possible
);

  // Internal signals
  integer i, idx_a0, idx_b0, idx_match;
  reg [2:0] a_nz [0:6];
  reg [2:0] b_nz [0:6];
  reg       found_a0, found_b0;
  reg       found_match;
  reg       equal_flag;

  always @* begin
    // Initialize
    possible     = 1'b0;
    idx_a0       = -1;
    idx_b0       = -1;
    found_a0     = 1'b0;
    found_b0     = 1'b0;
    found_match  = 1'b0;
    idx_match    = -1;
    equal_flag   = 1'b0;

    // Find index of 0 in a
    for (i = 0; i < 8; i = i + 1) begin
      if (!found_a0 && a[i] == 3'd0) begin
        idx_a0   = i;
        found_a0 = 1'b1;
      end
    end

    // Find index of 0 in b
    for (i = 0; i < 8; i = i + 1) begin
      if (!found_b0 && b[i] == 3'd0) begin
        idx_b0   = i;
        found_b0 = 1'b1;
      end
    end

    // Default possible = 0 if any 0 not found
    if (!found_a0 || !found_b0) begin
      possible = 1'b0;
    end else begin
      // Build a_nz
      for (i = 0; i < 7; i = i + 1) begin
        a_nz[i] = a[(idx_a0 + 1 + i) % 8];
      end

      // Build b_nz
      for (i = 0; i < 7; i = i + 1) begin
        b_nz[i] = b[(idx_b0 + 1 + i) % 8];
      end

      // Find position of b_nz[0] in a_nz
      for (i = 0; i < 7; i = i + 1) begin
        if (!found_match && a_nz[i] == b_nz[0]) begin
          idx_match   = i;
          found_match = 1'b1;
        end
      end

      if (!found_match) begin
        possible = 1'b0;
      end else begin
        // Compare rotated a_nz with b_nz
        equal_flag = 1'b1;
        for (i = 0; i < 7; i = i + 1) begin
          if (a_nz[(idx_match + i) % 7] != b_nz[i]) begin
            equal_flag = 1'b0;
          end
        end

        possible = equal_flag;
      end
    end
  end

endmodule