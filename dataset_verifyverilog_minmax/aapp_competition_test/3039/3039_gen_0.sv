module cube_fold_detector(
  input  [35:0] grid,  // row-major 6x6: bit 0 is row0,col0, bit 35 is row5,col5
  output logic foldable
);

  // Helper to build a 36-bit mask from 6x6 local bits (row-major, 0..5)
  function [35:0] pack6x6(input [5:0][5:0] b);
    integer r, c;
    pack6x6 = 36'b0;
    for (r = 0; r < 6; r++) begin
      for (c = 0; c < 6; c++) begin
        if (b[r][c]) pack6x6[r*6 + c] = 1'b1;
      end
    end
  endfunction

  // Rotate 90 degrees clockwise
  function [35:0] rot90(input [35:0] v);
    integer r, c;
    logic [5:0][5:0] src, dst;
    for (r = 0; r < 6; r++) begin
      for (c = 0; c < 6; c++) begin
        src[r][c] = v[r*6 + c];
      end
    end
    for (r = 0; r < 6; r++) begin
      for (c = 0; c < 6; c++) begin
        // dst[c][5-r] = src[r][c];
        dst[c][5-r] = src[r][c];
      end
    end
    return pack6x6(dst);
  endfunction

  // Horizontal flip (mirror left-right)
  function [35:0] flip_h(input [35:0] v);
    integer r, c;
    logic [5:0][5:0] src, dst;
    for (r = 0; r < 6; r++) begin
      for (c = 0; c < 6; c++) begin
        src[r][c] = v[r*6 + c];
      end
    end
    for (r = 0; r < 6; r++) begin
      for (c = 0; c < 6; c++) begin
        dst[r][5-c] = src[r][c];
      end
    end
    return pack6x6(dst);
  endfunction

  // Vertical flip (mirror top-bottom)
  function [35:0] flip_v(input [35:0] v);
    integer r, c;
    logic [5:0][5:0] src, dst;
    for (r = 0; r < 6; r++) begin
      for (c = 0; c < 6; c++) begin
        src[r][c] = v[r*6 + c];
      end
    end
    for (r = 0; r < 6; r++) begin
      for (c = 0; c < 6; c++) begin
        dst[5-r][c] = src[r][c];
      end
    end
    return pack6x6(dst);
  endfunction

  // 11 base nets (as 6x6 arrays of '1' where '#' appears). Each has 6 cells.
  // 0) Straight line 6
  logic [5:0][5:0] base0;
  assign base0 = '{
    6'b000000,
    6'b000000,
    6'b000000,
    6'b111111,
    6'b000000,
    6'b000000
  };

  // 1) T (4 across + one below center)
  logic [5:0][5:0] base1;
  assign base1 = '{
    6'b000000,
    6'b000000,
    6'b011110,
    6'b000100,
    6'b000000,
    6'b000000
  };

  // 2) Another T variant (4 across + one above center)
  logic [5:0][5:0] base2;
  assign base2 = '{
    6'b000000,
    6'b000100,
    6'b011110,
    6'b000000,
    6'b000000,
    6'b000000
  };

  // 3) Skew T (3 across, one below left, one below right)
  logic [5:0][5:0] base3;
  assign base3 = '{
    6'b000000,
    6'b000000,
    6'b011100,
    6'b000110,
    6'b000000,
    6'b000000
  };

  // 4) Zig-zag/stair 3-2-1 (bottom-left to top-right)
  logic [5:0][5:0] base4;
  assign base4 = '{
    6'b000100,
    6'b000110,
    6'b001110,
    6'b000000,
    6'b000000,
    6'b000000
  };

  // 5) L (3 vertical + tail to the right at the bottom)
  logic [5:0][5:0] base5;
  assign base5 = '{
    6'b001000,
    6'b001000,
    6'b001000,
    6'b001100,
    6'b000000,
    6'b000000
  };

  // 6) L rotated 90 (3 horizontal + tail down at right)
  logic [5:0][5:0] base6;
  assign base6 = '{
    6'b000000,
    6'b000000,
    6'b011100,
    6'b010000,
    6'b010000,
    6'b000000
  };

  // 7) S (stair 2-2-2, left-to-right, row-wise)
  logic [5:0][5:0] base7;
  assign base7 = '{
    6'b000000,
    6'b001100,
    6'b011000,
    6'b000000,
    6'b000000,
    6'b000000
  };

  // 8) Skew chain 4+2: 4 in a row with an extra on the end row, shifted right by 1
  logic [5:0][5:0] base8;
  assign base8 = '{
    6'b000000,
    6'b000000,
    6'b001110,  // 3 cells (index 1..3)
    6'b000100,  // 1 cell (index 2)
    6'b000000,
    6'b000000
  };

  // 9) Compact hook: 2x2 block + 2 extra to the right, same rows
  logic [5:0][5:0] base9;
  assign base9 = '{
    6'b000000,
    6'b001100,
    6'b001100,
    6'b000000,
    6'b000000,
    6'b000000
  };

  // 10) Another L variant: 3 vertical + tail up at top
  logic [5:0][5:0] base10;
  assign base10 = '{
    6'b001100,
    6'b001000,
    6'b001000,
    6'b000000,
    6'b000000,
    6'b000000
  };

  // Convert bases to flat 36-bit masks
  logic [35:0] bases [0:10];
  always_comb begin
    bases[0]  = pack6x6(base0);
    bases[1]  = pack6x6(base1);
    bases[2]  = pack6x6(base2);
    bases[3]  = pack6x6(base3);
    bases[4]  = pack6x6(base4);
    bases[5]  = pack6x6(base5);
    bases[6]  = pack6x6(base6);
    bases[7]  = pack6x6(base7);
    bases[8]  = pack6x6(base8);
    bases[9]  = pack6x6(base9);
    bases[10] = pack6x6(base10);
  end

  // Build a list of all unique transforms of all 11 nets (up to 24 each)
  // We check each combination of flip (none, H, V) x rotation (0,90,180,270).
  // Use a set of seen patterns to avoid duplicates across nets/transforms.
  localparam MAX_PAT = 24 * 11; // 264
  logic [35:0] pats [$];
  logic [35:0] seen [2**20]; // hash set (approx), adjust if needed
  int seen_cnt;
  
  function void try_add_pattern(input [35:0] p);
    int i;
    bit found;
    found = 1'b0;
    for (i = 0; i < seen_cnt; i++) begin
      if (seen[i] == p) begin
        found = 1'b1;
        break;
      end
    end
    if (!found && seen_cnt < $size(seen)) begin
      seen[seen_cnt] = p;
      seen_cnt++;
      pats.push_back(p);
    end
  endfunction

  always_comb begin
    // Clear containers
    pats.delete();
    seen_cnt = 0;

    // Enumerate all transforms for all 11 bases
    for (int b = 0; b < 11; b++) begin
      logic [35:0] base, p0, p90, p180, p270;
      logic [35:0] f0, f1, f2, f3;
      base = bases[b];
      // 0 deg
      p0 = base;
      // 90 deg
      p90 = rot90(p0);
      // 180 deg
      p180 = rot90(p90);
      // 270 deg
      p270 = rot90(p180);

      // No flip
      f0 = p0;      try_add_pattern(f0);
      f0 = p90;     try_add_pattern(f0);
      f0 = p180;    try_add_pattern(f0);
      f0 = p270;    try_add_pattern(f0);

      // Horizontal flip
      f1 = flip_h(p0);    try_add_pattern(f1);
      f1 = flip_h(p90);   try_add_pattern(f1);
      f1 = flip_h(p180);  try_add_pattern(f1);
      f1 = flip_h(p270);  try_add_pattern(f1);

      // Vertical flip
      f2 = flip_v(p0);    try_add_pattern(f2);
      f2 = flip_v(p90);   try_add_pattern(f2);
      f2 = flip_v(p180);  try_add_pattern(f2);
      f2 = flip_v(p270);  try_add_pattern(f2);

      // Both flips (equiv. to 180 deg rot + H flip, but included for completeness)
      f3 = flip_v(flip_h(p0));    try_add_pattern(f3);
      f3 = flip_v(flip_h(p90));   try_add_pattern(f3);
      f3 = flip_v(flip_h(p180));  try_add_pattern(f3);
      f3 = flip_v(flip_h(p270));  try_add_pattern(f3);
    end
  endfunction

  // Match against any of the precomputed unique valid cube-net transforms
  always_comb begin
    foldable = 1'b0;
    foreach (pats[i]) begin
      if (grid == pats[i]) begin
        foldable = 1'b1;
        break;
      end
    end
  end

endmodule