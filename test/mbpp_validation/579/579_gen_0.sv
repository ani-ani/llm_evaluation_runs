module dissimilar_elements(
  input  [5:0] t1_0, t1_1, t1_2, t1_3,
  input  [5:0] t2_0, t2_1, t2_2, t2_3,
  output [5:0] dissimilar [0:7],
  output [7:0] valid_mask
);

  // Internal wires to track inclusion for each candidate element
  wire t1_0_unique_t1, t1_1_unique_t1, t1_2_unique_t1, t1_3_unique_t1;
  wire t2_0_unique_t2, t2_1_unique_t2, t2_2_unique_t2, t2_3_unique_t2;

  wire t1_0_in_t2, t1_1_in_t2, t1_2_in_t2, t1_3_in_t2;
  wire t2_0_in_t1, t2_1_in_t1, t2_2_in_t1, t2_3_in_t1;

  wire include_t1_0, include_t1_1, include_t1_2, include_t1_3;
  wire include_t2_0, include_t2_1, include_t2_2, include_t2_3;

  // Detect uniqueness within the same tuple (no duplicates inside tuple)
  assign t1_0_unique_t1 = (t1_0 != t1_1) && (t1_0 != t1_2) && (t1_0 != t1_3);
  assign t1_1_unique_t1 = (t1_1 != t1_0) && (t1_1 != t1_2) && (t1_1 != t1_3);
  assign t1_2_unique_t1 = (t1_2 != t1_0) && (t1_2 != t1_1) && (t1_2 != t1_3);
  assign t1_3_unique_t1 = (t1_3 != t1_0) && (t1_3 != t1_1) && (t1_3 != t1_2);

  assign t2_0_unique_t2 = (t2_0 != t2_1) && (t2_0 != t2_2) && (t2_0 != t2_3);
  assign t2_1_unique_t2 = (t2_1 != t2_0) && (t2_1 != t2_2) && (t2_1 != t2_3);
  assign t2_2_unique_t2 = (t2_2 != t2_0) && (t2_2 != t2_1) && (t2_2 != t2_3);
  assign t2_3_unique_t2 = (t2_3 != t2_0) && (t2_3 != t2_1) && (t2_3 != t2_2);

  // Presence in opposite tuple
  assign t1_0_in_t2 = (t1_0 == t2_0) || (t1_0 == t2_1) || (t1_0 == t2_2) || (t1_0 == t2_3);
  assign t1_1_in_t2 = (t1_1 == t2_0) || (t1_1 == t2_1) || (t1_1 == t2_2) || (t1_1 == t2_3);
  assign t1_2_in_t2 = (t1_2 == t2_0) || (t1_2 == t2_1) || (t1_2 == t2_2) || (t1_2 == t2_3);
  assign t1_3_in_t2 = (t1_3 == t2_0) || (t1_3 == t2_1) || (t1_3 == t2_2) || (t1_3 == t2_3);

  assign t2_0_in_t1 = (t2_0 == t1_0) || (t2_0 == t1_1) || (t2_0 == t1_2) || (t2_0 == t1_3);
  assign t2_1_in_t1 = (t2_1 == t1_0) || (t2_1 == t1_1) || (t2_1 == t1_2) || (t2_1 == t1_3);
  assign t2_2_in_t1 = (t2_2 == t1_0) || (t2_2 == t1_1) || (t2_2 == t1_2) || (t2_2 == t1_3);
  assign t2_3_in_t1 = (t2_3 == t1_0) || (t2_3 == t1_1) || (t2_3 == t1_2) || (t2_3 == t1_3);

  // Decide inclusion in symmetric difference:
  // include if unique within its own tuple AND absent from the other tuple
  assign include_t1_0 = t1_0_unique_t1 && !t1_0_in_t2;
  assign include_t1_1 = t1_1_unique_t1 && !t1_1_in_t2;
  assign include_t1_2 = t1_2_unique_t1 && !t1_2_in_t2;
  assign include_t1_3 = t1_3_unique_t1 && !t1_3_in_t2;

  assign include_t2_0 = t2_0_unique_t2 && !t2_0_in_t1;
  assign include_t2_1 = t2_1_unique_t2 && !t2_1_in_t1;
  assign include_t2_2 = t2_2_unique_t2 && !t2_2_in_t1;
  assign include_t2_3 = t2_3_unique_t2 && !t2_3_in_t1;

  // Helper wires for computing insertion positions (prefix-popcount style)
  wire [3:0] inc_t1;
  wire [3:0] pos_t1;

  assign inc_t1[0] = include_t1_0;
  assign inc_t1[1] = include_t1_1;
  assign inc_t1[2] = include_t1_2;
  assign inc_t1[3] = include_t1_3;

  // Positions for T1 elements
  assign pos_t1[0] = 0;
  assign pos_t1[1] = inc_t1[0];
  assign pos_t1[2] = inc_t1[0] + inc_t1[1];
  assign pos_t1[3] = inc_t1[0] + inc_t1[1] + inc_t1[2];

  wire [3:0] count_t1;
  assign count_t1 = inc_t1[0] + inc_t1[1] + inc_t1[2] + inc_t1[3];

  // For T2, positions start after all included T1 elements
  wire [3:0] inc_t2;
  wire [3:0] base_t2;
  wire [3:0] pos_t2;

  assign inc_t2[0] = include_t2_0;
  assign inc_t2[1] = include_t2_1;
  assign inc_t2[2] = include_t2_2;
  assign inc_t2[3] = include_t2_3;

  assign base_t2 = count_t1;

  assign pos_t2[0] = base_t2;
  assign pos_t2[1] = base_t2 + inc_t2[0];
  assign pos_t2[2] = base_t2 + inc_t2[0] + inc_t2[1];
  assign pos_t2[3] = base_t2 + inc_t2[0] + inc_t2[1] + inc_t2[2];

  // Initialize outputs (combinational, with continuous assigns)
  // Default all valids to 0 and values to don't-care (set to 0)
  assign dissimilar[0] = 6'b0;
  assign dissimilar[1] = 6'b0;
  assign dissimilar[2] = 6'b0;
  assign dissimilar[3] = 6'b0;
  assign dissimilar[4] = 6'b0;
  assign dissimilar[5] = 6'b0;
  assign dissimilar[6] = 6'b0;
  assign dissimilar[7] = 6'b0;

  // We'll build valid_mask via wires per index
  wire v0, v1, v2, v3, v4, v5, v6, v7;
  assign {v7,v6,v5,v4,v3,v2,v1,v0} = 8'b0;

  // Helper function-like macros via conditional assigns to place elements
  // T1 elements placement
  assign dissimilar[pos_t1[0]] = include_t1_0 ? t1_0 : dissimilar[pos_t1[0]];
  assign dissimilar[pos_t1[1]] = include_t1_1 ? t1_1 : dissimilar[pos_t1[1]];
  assign dissimilar[pos_t1[2]] = include_t1_2 ? t1_2 : dissimilar[pos_t1[2]];
  assign dissimilar[pos_t1[3]] = include_t1_3 ? t1_3 : dissimilar[pos_t1[3]];

  // T2 elements placement
  assign dissimilar[pos_t2[0]] = include_t2_0 ? t2_0 : dissimilar[pos_t2[0]];
  assign dissimilar[pos_t2[1]] = include_t2_1 ? t2_1 : dissimilar[pos_t2[1]];
  assign dissimilar[pos_t2[2]] = include_t2_2 ? t2_2 : dissimilar[pos_t2[2]];
  assign dissimilar[pos_t2[3]] = include_t2_3 ? t2_3 : dissimilar[pos_t2[3]];

  // Valid bits per inserted element
  wire [3:0] valid_t1_idx;
  wire [3:0] valid_t2_idx;

  assign valid_t1_idx[0] = include_t1_0;
  assign valid_t1_idx[1] = include_t1_1;
  assign valid_t1_idx[2] = include_t1_2;
  assign valid_t1_idx[3] = include_t1_3;

  assign valid_t2_idx[0] = include_t2_0;
  assign valid_t2_idx[1] = include_t2_1;
  assign valid_t2_idx[2] = include_t2_2;
  assign valid_t2_idx[3] = include_t2_3;

  // Build valid_mask combinationally by OR-ing contributions for each slot
  wire [7:0] vm_t1;
  wire [7:0] vm_t2;

  assign vm_t1 = 8'b0
    | (valid_t1_idx[0] ? (8'b00000001 << pos_t1[0]) : 8'b0)
    | (valid_t1_idx[1] ? (8'b00000001 << pos_t1[1]) : 8'b0)
    | (valid_t1_idx[2] ? (8'b00000001 << pos_t1[2]) : 8'b0)
    | (valid_t1_idx[3] ? (8'b00000001 << pos_t1[3]) : 8'b0);

  assign vm_t2 = 8'b0
    | (valid_t2_idx[0] ? (8'b00000001 << pos_t2[0]) : 8'b0)
    | (valid_t2_idx[1] ? (8'b00000001 << pos_t2[1]) : 8'b0)
    | (valid_t2_idx[2] ? (8'b00000001 << pos_t2[2]) : 8'b0)
    | (valid_t2_idx[3] ? (8'b00000001 << pos_t2[3]) : 8'b0);

  assign valid_mask = vm_t1 | vm_t2;

endmodule