module participant_deduction (
  input [3:0] n,          // First participant pairs count (1-8)
  input [3:0] m,          // Second participant pairs count (1-8)
  input [63:0] a_pairs,   // 8 pairs (16 x 4-bit numbers, each pair = {x,y}[7:0])
  input [63:0] b_pairs,   // Same for second participant
  output logic [3:0] result // 1-9=number, 0=both know, 15=-1
);

  // Decode 8 pairs from 64-bit vectors (byte i = bits [8*i+7 : 8*i])
  logic [3:0] A [8][2];
  logic [3:0] B [8][2];
  genvar i;
  generate
    for (i = 0; i < 8; i++) begin : decode_pairs
      // Little-endian within each byte: A[i][0] is low 4 bits, A[i][1] is high 4 bits
      assign A[i][0] = a_pairs[8*i +: 4];
      assign A[i][1] = a_pairs[8*i + 4 +: 4];
      assign B[i][0] = b_pairs[8*i +: 4];
      assign B[i][1] = b_pairs[8*i + 4 +: 4];
    end
  endgenerate

  // Globals
  logic [9:0] cand_mask;   // bits [1..9]
  logic [9:0] cand_one_mask; // counts == 1 per candidate (computed later)
  logic all_a_single, all_b_single;
  int g, h;

  // Per-pair possibility bitsets (bits 1..9)
  logic [9:0] a_possible [8];
  logic [9:0] b_possible [8];

  // For each a-pair i that is within n
  always_comb begin
    // Defaults
    for (g = 0; g < 8; g++) begin
      a_possible[g] = 10'b0;
      b_possible[g] = 10'b0;
    end
    cand_mask = 10'b0;

    for (g = 0; g < 8; g++) begin
      if (g < n) begin
        logic [3:0] a0, a1;
        a0 = A[g][0];
        a1 = A[g][1];
        for (h = 0; h < 8; h++) begin
          if (h < m) begin
            logic [3:0] b0, b1;
            b0 = B[h][0];
            b1 = B[h][1];
            // Skip identical pairs
            if ((a0 == b0) && (a1 == b1)) begin
              // no contribution
            end else begin
              // Exactly one common number: a0==b0 xor a0==b1 xor a1==b0 xor a1==b1
              logic c01, c02, c10, c11;
              c01 = (a0 == b0) && (a1 != b1) && (a1 != b0) && (a0 != b1);
              c02 = (a0 == b1) && (a1 != b0) && (a1 != b1) && (a0 != b0);
              c10 = (a1 == b0) && (a0 != b1) && (a0 != b0) && (a1 != b1);
              c11 = (a1 == b1) && (a0 != b0) && (a0 != b1) && (a1 != b0);
              // The real exactly-one condition (single equality and the other elements differ)
              // Robust check
              logic eq0b0, eq0b1, eq1b0, eq1b1;
              eq0b0 = (a0 == b0);
              eq0b1 = (a0 == b1);
              eq1b0 = (a1 == b0);
              eq1b1 = (a1 == b1);

              // Exactly one equality true, and the numbers compared are within [1..9]
              logic [3:0] eq_count;
              eq_count = (eq0b0 ? 1 : 0) + (eq0b1 ? 1 : 0) + (eq1b0 ? 1 : 0) + (eq1b1 ? 1 : 0);
              if (eq_count == 1) begin
                if (eq0b0 && (a0 >= 1 && a0 <= 9)) begin
                  a_possible[g] = a_possible[g] | (10'b1 << a0);
                  b_possible[h] = b_possible[h] | (10'b1 << a0);
                  cand_mask = cand_mask | (10'b1 << a0);
                end else if (eq0b1 && (a0 >= 1 && a0 <= 9)) begin
                  a_possible[g] = a_possible[g] | (10'b1 << a0);
                  b_possible[h] = b_possible[h] | (10'b1 << a0);
                  cand_mask = cand_mask | (10'b1 << a0);
                end else if (eq1b0 && (a1 >= 1 && a1 <= 9)) begin
                  a_possible[g] = a_possible[g] | (10'b1 << a1);
                  b_possible[h] = b_possible[h] | (10'b1 << a1);
                  cand_mask = cand_mask | (10'b1 << a1);
                end else if (eq1b1 && (a1 >= 1 && a1 <= 9)) begin
                  a_possible[g] = a_possible[g] | (10'b1 << a1);
                  b_possible[h] = b_possible[h] | (10'b1 << a1);
                  cand_mask = cand_mask | (10'b1 << a1);
                end
              end
            end
          end
        end
      end
    end

    // Determine candidates with exactly one supporting pair (as an extra check)
    // and per-participant all-single flags
    all_a_single = 1'b1;
    for (g = 0; g < 8; g++) begin
      if (g < n) begin
        // The spec implies emptiness is acceptable (possible <= 1). Empty means 0 possibilities.
        if (($countones(a_possible[g]) > 1)) all_a_single = 1'b0;
      end
    end
    all_b_single = 1'b1;
    for (g = 0; g < 8; g++) begin
      if (g < m) begin
        if (($countones(b_possible[g]) > 1)) all_b_single = 1'b0;
      end
    end

    // Prepare a mask of candidates that have exactly one occurrence among all pair-sets
    cand_one_mask = 10'b0;
    for (g = 1; g <= 9; g++) begin
      logic [3:0] occ;
      occ = 4'd0;
      for (h = 0; h < 8; h++) begin
        if (h < n) occ = occ + (a_possible[h][g] ? 1 : 0);
        if (h < m) occ = occ + (b_possible[h][g] ? 1 : 0);
      end
      if (occ == 1) cand_one_mask[g] = 1'b1;
    end

    // Final decision
    // 1) If exactly one number in candidates (global set) -> output that number
    if ($countones(cand_mask) == 1) begin
      for (g = 1; g <= 9; g++) begin
        if (cand_mask[g]) result = g[3:0];
      end
    end else begin
      // 2) Else if all a_pairs' possible set <=1 AND all b_pairs' possible set <=1 -> output 0
      if (all_a_single && all_b_single) begin
        result = 4'd0;
      end else begin
        result = 4'd15; // -1
      end
    end
  end
endmodule