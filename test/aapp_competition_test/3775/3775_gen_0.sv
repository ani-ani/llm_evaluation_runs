module participant_deduction(
  input  [3:0]  n,          // First participant pairs count (1-8)
  input  [3:0]  m,          // Second participant pairs count (1-8)
  input  [63:0] a_pairs,    // 8 pairs: pair0=[63:56], pair1=[55:48], ... pair7=[7:0]
  input  [63:0] b_pairs,    // Same encoding for second participant
  output [3:0]  result      // 1-9 = number, 0 = both know, 15 = -1 (ambiguous)
);

  // Extract A pairs: a_x[i], a_y[i]
  wire [3:0] a_x [0:7];
  wire [3:0] a_y [0:7];
  // Extract B pairs: b_x[i], b_y[i]
  wire [3:0] b_x [0:7];
  wire [3:0] b_y [0:7];

  genvar gi;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : EXTRACT
      assign a_x[gi] = a_pairs[63 - gi*8 -: 4];
      assign a_y[gi] = a_pairs[59 - gi*8 -: 4];
      assign b_x[gi] = b_pairs[63 - gi*8 -: 4];
      assign b_y[gi] = b_pairs[59 - gi*8 -: 4];
    end
  endgenerate

  // Valid flags per pair index based on n, m
  wire a_valid[0:7];
  wire b_valid[0:7];
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : VALID
      assign a_valid[gi] = (gi[3:0] < n);
      assign b_valid[gi] = (gi[3:0] < m);
    end
  endgenerate

  // For each pair and each comparison, track:
  // - is_common: exactly one common number and pairs not identical
  // - common_val: that common number
  // - a_has_match[i], b_has_match[j]: whether this pair participates in any common pair

  wire        is_common [0:7][0:7];
  wire [3:0]  common_val[0:7][0:7];

  wire a_has_match[0:7];
  wire b_has_match[0:7];

  genvar i, j;
  generate
    for (i = 0; i < 8; i = i + 1) begin : A_LOOP
      wire any_a_match;
      assign any_a_match = 1'b0; // default, will be ORed structurally below via intermediate wires
      for (j = 0; j < 8; j = j + 1) begin : B_LOOP
        wire valid_comp;
        assign valid_comp = a_valid[i] & b_valid[j];

        wire same_pair;
        assign same_pair = (a_x[i] == b_x[j]) & (a_y[i] == b_y[j]);

        wire ax_eq_bx = (a_x[i] == b_x[j]);
        wire ax_eq_by = (a_x[i] == b_y[j]);
        wire ay_eq_bx = (a_y[i] == b_x[j]);
        wire ay_eq_by = (a_y[i] == b_y[j]);

        wire [3:0] cv_axbx = a_x[i];
        wire [3:0] cv_axby = a_x[i];
        wire [3:0] cv_aybx = a_y[i];
        wire [3:0] cv_ayby = a_y[i];

        wire [1:0] match_cnt;
        assign match_cnt = {1'b0, ax_eq_bx} + {1'b0, ax_eq_by} + {1'b0, ay_eq_bx} + {1'b0, ay_eq_by};

        wire one_common;
        assign one_common = valid_comp & (~same_pair) & (match_cnt == 2'd1);

        // Determine which common value in case of single match
        assign common_val[i][j] = (ax_eq_bx) ? cv_axbx :
                                  (ax_eq_by) ? cv_axby :
                                  (ay_eq_bx) ? cv_aybx :
                                  (ay_eq_by) ? cv_ayby : 4'd0;

        assign is_common[i][j] = one_common;
      end
    end
  endgenerate

  // Build per-A and per-B match flags (OR over j / i)
  genvar ii, jj;
  generate
    for (ii = 0; ii < 8; ii = ii + 1) begin : A_MATCH_SUM
      wire tmp_or;
      assign tmp_or = 1'b0;
      for (jj = 0; jj < 8; jj = jj + 1) begin : A_MATCH_SUM_INNER
        // OR all is_common[ii][*]
      end
    end
  endgenerate

  // Because generate-for with reduction inside is restricted, do explicit assigns:
  // a_has_match[i] = OR_j is_common[i][j]
  // b_has_match[j] = OR_i is_common[i][j]

  genvar k;
  generate
    for (k = 0; k < 8; k = k + 1) begin : A_HAS_MATCH_GEN
      assign a_has_match[k] = (is_common[k][0] | is_common[k][1] | is_common[k][2] | is_common[k][3] |
                               is_common[k][4] | is_common[k][5] | is_common[k][6] | is_common[k][7]);
    end
    for (k = 0; k < 8; k = k + 1) begin : B_HAS_MATCH_GEN
      assign b_has_match[k] = (is_common[0][k] | is_common[1][k] | is_common[2][k] | is_common[3][k] |
                               is_common[4][k] | is_common[5][k] | is_common[6][k] | is_common[7][k]);
    end
  endgenerate

  // Candidate set: union of all distinct common_val where is_common is true.
  // Only values 1..9 are meaningful per problem statement.

  wire candidate_present[1:9];

  genvar v;
  generate
    for (v = 1; v <= 9; v = v + 1) begin : CAND
      wire found;
      assign found =
        ((is_common[0][0] & (common_val[0][0] == v[3:0])) |
         (is_common[0][1] & (common_val[0][1] == v[3:0])) |
         (is_common[0][2] & (common_val[0][2] == v[3:0])) |
         (is_common[0][3] & (common_val[0][3] == v[3:0])) |
         (is_common[0][4] & (common_val[0][4] == v[3:0])) |
         (is_common[0][5] & (common_val[0][5] == v[3:0])) |
         (is_common[0][6] & (common_val[0][6] == v[3:0])) |
         (is_common[0][7] & (common_val[0][7] == v[3:0])) |

         (is_common[1][0] & (common_val[1][0] == v[3:0])) |
         (is_common[1][1] & (common_val[1][1] == v[3:0])) |
         (is_common[1][2] & (common_val[1][2] == v[3:0])) |
         (is_common[1][3] & (common_val[1][3] == v[3:0])) |
         (is_common[1][4] & (common_val[1][4] == v[3:0])) |
         (is_common[1][5] & (common_val[1][5] == v[3:0])) |
         (is_common[1][6] & (common_val[1][6] == v[3:0])) |
         (is_common[1][7] & (common_val[1][7] == v[3:0])) |

         (is_common[2][0] & (common_val[2][0] == v[3:0])) |
         (is_common[2][1] & (common_val[2][1] == v[3:0])) |
         (is_common[2][2] & (common_val[2][2] == v[3:0])) |
         (is_common[2][3] & (common_val[2][3] == v[3:0])) |
         (is_common[2][4] & (common_val[2][4] == v[3:0])) |
         (is_common[2][5] & (common_val[2][5] == v[3:0])) |
         (is_common[2][6] & (common_val[2][6] == v[3:0])) |
         (is_common[2][7] & (common_val[2][7] == v[3:0])) |

         (is_common[3][0] & (common_val[3][0] == v[3:0])) |
         (is_common[3][1] & (common_val[3][1] == v[3:0])) |
         (is_common[3][2] & (common_val[3][2] == v[3:0])) |
         (is_common[3][3] & (common_val[3][3] == v[3:0])) |
         (is_common[3][4] & (common_val[3][4] == v[3:0])) |
         (is_common[3][5] & (common_val[3][5] == v[3:0])) |
         (is_common[3][6] & (common_val[3][6] == v[3:0])) |
         (is_common[3][7] & (common_val[3][7] == v[3:0])) |

         (is_common[4][0] & (common_val[4][0] == v[3:0])) |
         (is_common[4][1] & (common_val[4][1] == v[3:0])) |
         (is_common[4][2] & (common_val[4][2] == v[3:0])) |
         (is_common[4][3] & (common_val[4][3] == v[3:0])) |
         (is_common[4][4] & (common_val[4][4] == v[3:0])) |
         (is_common[4][5] & (common_val[4][5] == v[3:0])) |
         (is_common[4][6] & (common_val[4][6] == v[3:0])) |
         (is_common[4][7] & (common_val[4][7] == v[3:0])) |

         (is_common[5][0] & (common_val[5][0] == v[3:0])) |
         (is_common[5][1] & (common_val[5][1] == v[3:0])) |
         (is_common[5][2] & (common_val[5][2] == v[3:0])) |
         (is_common[5][3] & (common_val[5][3] == v[3:0])) |
         (is_common[5][4] & (common_val[5][4] == v[3:0])) |
         (is_common[5][5] & (common_val[5][5] == v[3:0])) |
         (is_common[5][6] & (common_val[5][6] == v[3:0])) |
         (is_common[5][7] & (common_val[5][7] == v[3:0])) |

         (is_common[6][0] & (common_val[6][0] == v[3:0])) |
         (is_common[6][1] & (common_val[6][1] == v[3:0])) |
         (is_common[6][2] & (common_val[6][2] == v[3:0])) |
         (is_common[6][3] & (common_val[6][3] == v[3:0])) |
         (is_common[6][4] & (common_val[6][4] == v[3:0])) |
         (is_common[6][5] & (common_val[6][5] == v[3:0])) |
         (is_common[6][6] & (common_val[6][6] == v[3:0])) |
         (is_common[6][7] & (common_val[6][7] == v[3:0])) |

         (is_common[7][0] & (common_val[7][0] == v[3:0])) |
         (is_common[7][1] & (common_val[7][1] == v[3:0])) |
         (is_common[7][2] & (common_val[7][2] == v[3:0])) |
         (is_common[7][3] & (common_val[7][3] == v[3:0])) |
         (is_common[7][4] & (common_val[7][4] == v[3:0])) |
         (is_common[7][5] & (common_val[7][5] == v[3:0])) |
         (is_common[7][6] & (common_val[7][6] == v[3:0])) |
         (is_common[7][7] & (common_val[7][7] == v[3:0])));

      assign candidate_present[v] = found;
    end
  endgenerate

  // Count number of distinct candidates and capture the unique one if it exists
  wire [3:0] candidate_count;
  wire [3:0] unique_candidate;

  assign candidate_count = {2'b00, candidate_present[1]} +
                           {2'b00, candidate_present[2]} +
                           {2'b00, candidate_present[3]} +
                           {2'b00, candidate_present[4]} +
                           {2'b00, candidate_present[5]} +
                           {2'b00, candidate_present[6]} +
                           {2'b00, candidate_present[7]} +
                           {2'b00, candidate_present[8]} +
                           {2'b00, candidate_present[9]};

  assign unique_candidate = candidate_present[1] ? 4'd1 :
                            candidate_present[2] ? 4'd2 :
                            candidate_present[3] ? 4'd3 :
                            candidate_present[4] ? 4'd4 :
                            candidate_present[5] ? 4'd5 :
                            candidate_present[6] ? 4'd6 :
                            candidate_present[7] ? 4'd7 :
                            candidate_present[8] ? 4'd8 :
                            candidate_present[9] ? 4'd9 : 4'd0;

  // Check: all valid A pairs have possible set size <= 1
  // Possible set size for a given pair is the number of distinct candidates it participates in.
  // This is guaranteed <=1 if (for that pair) all is_common[i][j] share the same common_val.
  // We implement: for each i, if any is_common[i][j] is set, ensure all other is_common[i][k]
  // either use same common_val or are 0.

  wire a_pair_ok[0:7];
  wire b_pair_ok[0:7];

  genvar pi;
  generate
    for (pi = 0; pi < 8; pi = pi + 1) begin : A_OK_GEN
      // Determine base value for this A pair (first common_val encountered)
      wire [3:0] base_val;
      wire       has_any;
      assign base_val = is_common[pi][0] ? common_val[pi][0] :
                        is_common[pi][1] ? common_val[pi][1] :
                        is_common[pi][2] ? common_val[pi][2] :
                        is_common[pi][3] ? common_val[pi][3] :
                        is_common[pi][4] ? common_val[pi][4] :
                        is_common[pi][5] ? common_val[pi][5] :
                        is_common[pi][6] ? common_val[pi][6] :
                        is_common[pi][7] ? common_val[pi][7] : 4'd0;

      assign has_any = a_has_match[pi];

      // Check all matches either share base_val or are zero
      wire consistent;
      assign consistent =
        (!has_any) |
        ( ((~is_common[pi][0]) | (common_val[pi][0] == base_val)) &
          ((~is_common[pi][1]) | (common_val[pi][1] == base_val)) &
          ((~is_common[pi][2]) | (common_val[pi][2] == base_val)) &
          ((~is_common[pi][3]) | (common_val[pi][3] == base_val)) &
          ((~is_common[pi][4]) | (common_val[pi][4] == base_val)) &
          ((~is_common[pi][5]) | (common_val[pi][5] == base_val)) &
          ((~is_common[pi][6]) | (common_val[pi][6] == base_val)) &
          ((~is_common[pi][7]) | (common_val[pi][7] == base_val)) );

      // Only care about valid pairs; invalid ones are trivially OK
      assign a_pair_ok[pi] = (~a_valid[pi]) | consistent;
    end
  endgenerate

  genvar pj;
  generate
    for (pj = 0; pj < 8; pj = pj + 1) begin : B_OK_GEN
      wire [3:0] base_val_b;
      wire       has_any_b;
      assign base_val_b = is_common[0][pj] ? common_val[0][pj] :
                          is_common[1][pj] ? common_val[1][pj] :
                          is_common[2][pj] ? common_val[2][pj] :
                          is_common[3][pj] ? common_val[3][pj] :
                          is_common[4][pj] ? common_val[4][pj] :
                          is_common[5][pj] ? common_val[5][pj] :
                          is_common[6][pj] ? common_val[6][pj] :
                          is_common[7][pj] ? common_val[7][pj] : 4'd0;

      assign has_any_b = b_has_match[pj];

      wire consistent_b;
      assign consistent_b =
        (!has_any_b) |
        ( ((~is_common[0][pj]) | (common_val[0][pj] == base_val_b)) &
          ((~is_common[1][pj]) | (common_val[1][pj] == base_val_b)) &
          ((~is_common[2][pj]) | (common_val[2][pj] == base_val_b)) &
          ((~is_common[3][pj]) | (common_val[3][pj] == base_val_b)) &
          ((~is_common[4][pj]) | (common_val[4][pj] == base_val_b)) &
          ((~is_common[5][pj]) | (common_val[5][pj] == base_val_b)) &
          ((~is_common[6][pj]) | (common_val[6][pj] == base_val_b)) &
          ((~is_common[7][pj]) | (common_val[7][pj] == base_val_b)) );

      assign b_pair_ok[pj] = (~b_valid[pj]) | consistent_b;
    end
  endgenerate

  // Global flags for "all A pairs ok" and "all B pairs ok"
  wire all_a_ok;
  wire all_b_ok;

  assign all_a_ok = a_pair_ok[0] & a_pair_ok[1] & a_pair_ok[2] & a_pair_ok[3] &
                    a_pair_ok[4] & a_pair_ok[5] & a_pair_ok[6] & a_pair_ok[7];

  assign all_b_ok = b_pair_ok[0] & b_pair_ok[1] & b_pair_ok[2] & b_pair_ok[3] &
                    b_pair_ok[4] & b_pair_ok[5] & b_pair_ok[6] & b_pair_ok[7];

  // Final decision logic (purely combinational):
  // 1) If exactly one candidate -> that number
  // 2) Else if all pairs for both sides have possible set size <= 1 -> 0
  // 3) Else -> 15 (-1)

  assign result = (candidate_count == 4'd1) ? unique_candidate :
                  ((all_a_ok & all_b_ok) ? 4'd0 : 4'd15);

endmodule