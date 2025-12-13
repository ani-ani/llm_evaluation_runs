module permutation_cycle_generator(
  input  [3:0] N,
  input  [3:0] A,
  input  [3:0] B,
  output       valid,
  output [31:0] perm
);

  // Internal signals
  reg       valid_r;
  reg [31:0] perm_r;

  // Candidate x,y pairs (0..8) for N <= 8
  reg [3:0] x_sel;
  reg [3:0] y_sel;

  // Temporary indices
  integer i;
  integer pos;
  integer start;

  // Combinational search for non-negative integers x, y such that x*A + y*B = N
  always @* begin
    valid_r = 1'b0;
    x_sel   = 4'd0;
    y_sel   = 4'd0;

    // Default permutation to zeros
    perm_r  = 32'd0;

    // Brute-force small range: x from 0..8, y from 0..8
    // Prioritize smallest x then smallest y that satisfies equation
    for (i = 0; i <= 8; i = i + 1) begin
      integer j;
      if (!valid_r) begin
        for (j = 0; j <= 8; j = j + 1) begin
          if (!valid_r) begin
            if ((i * A + j * B) == N) begin
              valid_r = 1'b1;
              x_sel   = i[3:0];
              y_sel   = j[3:0];
            end
          end
        end
      end
    end

    // If valid, construct permutation
    if (valid_r) begin
      // Initialize outputs to zero
      perm_r = 32'd0;

      pos   = 0; // current position index (0-based for perm entries)
      start = 1; // current starting element label (1-based)

      // Generate x_sel cycles of length A
      for (i = 0; i < x_sel; i = i + 1) begin
        integer k;
        if (A > 0) begin
          // Elements: [start+1, ..., start+A-1, start]
          for (k = 0; k < A-1; k = k + 1) begin
            if ((pos + k) < 8) begin
              perm_r[(4*(pos + k) + 3) -: 4] = (start + k + 1)[3:0];
            end
          end
          if (pos + (A-1) < 8) begin
            perm_r[(4*(pos + (A-1)) + 3) -: 4] = start[3:0];
          end
          pos   = pos + A;
          start = start + A;
        end
      end

      // Generate y_sel cycles of length B
      for (i = 0; i < y_sel; i = i + 1) begin
        integer k2;
        if (B > 0) begin
          // Elements: [start+1, ..., start+B-1, start]
          for (k2 = 0; k2 < B-1; k2 = k2 + 1) begin
            if ((pos + k2) < 8) begin
              perm_r[(4*(pos + k2) + 3) -: 4] = (start + k2 + 1)[3:0];
            end
          end
          if (pos + (B-1) < 8) begin
            perm_r[(4*(pos + (B-1)) + 3) -: 4] = start[3:0];
          end
          pos   = pos + B;
          start = start + B;
        end
      end
    end
  end

  assign valid = valid_r;
  assign perm  = perm_r;

endmodule