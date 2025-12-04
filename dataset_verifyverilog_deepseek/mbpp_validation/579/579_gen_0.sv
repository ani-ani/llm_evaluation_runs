module dissimilar_elements (
  input [5:0] t1_0, t1_1, t1_2, t1_3,
  input [5:0] t2_0, t2_1, t2_2, t2_3,
  output [5:0] dissimilar [0:7],
  output [7:0] valid_mask
);

  // Internal wires for uniqueness checking
  wire uniq1_0, uniq1_1, uniq1_2, uniq1_3;
  wire uniq2_0, uniq2_1, uniq2_2, uniq2_3;

  // Determine unique elements in each tuple
  assign uniq1_0 = 1'b1;
  assign uniq1_1 = (t1_1 != t1_0);
  assign uniq1_2 = (t1_2 != t1_0 && t1_2 != t1_1);
  assign uniq1_3 = (t1_3 != t1_0 && t1_3 != t1_1 && t1_3 != t1_2);
  assign uniq2_0 = 1'b1;
  assign uniq2_1 = (t2_1 != t2_0);
  assign uniq2_2 = (t2_2 != t2_0 && t2_2 != t2_1);
  assign uniq2_3 = (t2_3 != t2_0 && t2_3 != t2_1 && t2_3 != t2_2);

  // Candidate validity (unique in self and not in other tuple)
  wire in_t2_0, in_t2_1, in_t2_2, in_t2_3;
  wire in_t1_0, in_t1_1, in_t1_2, in_t1_3;
  wire [7:0] cand_valid;
  wire [5:0] cand [0:7];
  assign cand[0] = t1_0; assign cand[1] = t1_1; assign cand[2] = t1_2; assign cand[3] = t1_3;
  assign cand[4] = t2_0; assign cand[5] = t2_1; assign cand[6] = t2_2; assign cand[7] = t2_3;

  assign in_t2_0 = (t1_0 == t2_0) || (t1_0 == t2_1) || (t1_0 == t2_2) || (t1_0 == t2_3);
  assign in_t2_1 = (t1_1 == t2_0) || (t1_1 == t2_1) || (t1_1 == t2_2) || (t1_1 == t2_3);
  assign in_t2_2 = (t1_2 == t2_0) || (t1_2 == t2_1) || (t1_2 == t2_2) || (t1_2 == t2_3);
  assign in_t2_3 = (t1_3 == t2_0) || (t1_3 == t2_1) || (t1_3 == t2_2) || (t1_3 == t2_3);
  assign in_t1_0 = (t2_0 == t1_0) || (t2_0 == t1_1) || (t2_0 == t1_2) || (t2_0 == t1_3);
  assign in_t1_1 = (t2_1 == t1_0) || (t2_1 == t1_1) || (t2_1 == t1_2) || (t2_1 == t1_3);
  assign in_t1_2 = (t2_2 == t1_0) || (t2_2 == t1_1) || (t2_2 == t1_2) || (t2_2 == t1_3);
  assign in_t1_3 = (t2_3 == t1_0) || (t2_3 == t1_1) || (t2_3 == t1_2) || (t2_3 == t1_3);

  assign cand_valid[0] = uniq1_0 && ~in_t2_0;
  assign cand_valid[1] = uniq1_1 && ~in_t2_1;
  assign cand_valid[2] = uniq1_2 && ~in_t2_2;
  assign cand_valid[3] = uniq1_3 && ~in_t2_3;
  assign cand_valid[4] = uniq2_0 && ~in_t1_0;
  assign cand_valid[5] = uniq2_1 && ~in_t1_1;
  assign cand_valid[6] = uniq2_2 && ~in_t1_2;
  assign cand_valid[7] = uniq2_3 && ~in_t1_3;

  // Prefix sum for packing logic
  wire [3:0] pre_count [0:8];
  assign pre_count[0] = 4'b0;
  assign pre_count[1] = pre_count[0] + cand_valid[0];
  assign pre_count[2] = pre_count[1] + cand_valid[1];
  assign pre_count[3] = pre_count[2] + cand_valid[2];
  assign pre_count[4] = pre_count[3] + cand_valid[3];
  assign pre_count[5] = pre_count[4] + cand_valid[4];
  assign pre_count[6] = pre_count[5] + cand_valid[5];
  assign pre_count[7] = pre_count[6] + cand_valid[6];
  assign pre_count[8] = pre_count[7] + cand_valid[7];
  
  // Pack valid candidates
  assign dissimilar[0] = (cand_valid[0] && pre_count[0] == 0) ? cand[0] :
                          (cand_valid[1] && pre_count[1] == 0) ? cand[1] :
                          (cand_valid[2] && pre_count[2] == 0) ? cand[2] :
                          (cand_valid[3] && pre_count[3] == 0) ? cand[3] :
                          (cand_valid[4] && pre_count[4] == 0) ? cand[4] :
                          (cand_valid[5] && pre_count[5] == 0) ? cand[5] :
                          (cand_valid[6] && pre_count[6] == 0) ? cand[6] :
                          (cand_valid[7] && pre_count[7] == 0) ? cand[7] : 6'b0;

  assign dissimilar[1] = (cand_valid[0] && pre_count[0] == 1) ? cand[0] :
                          (cand_valid[1] && pre_count[1] == 1) ? cand[1] :
                          (cand_valid[2] && pre_count[2] == 1) ? cand[2] :
                          (cand_valid[3] && pre_count[3] == 1) ? cand[3] :
                          (cand_valid[4] && pre_count[4] == 1) ? cand[4] :
                          (cand_valid[5] && pre_count[5] == 1) ? cand[5] :
                          (cand_valid[6] && pre_count[6] == 1) ? cand[6] :
                          (cand_valid[7] && pre_count[7] == 1) ? cand[7] : 6'b0;

  assign dissimilar[2] = (cand_valid[0] && pre_count[0] == 2) ? cand[0] :
                          (cand_valid[1] && pre_count[1] == 2) ? cand[1] :
                          (cand_valid[2] && pre_count[2] == 2) ? cand[2] :
                          (cand_valid[3] && pre_count[3] == 2) ? cand[3] :
                          (cand_valid[4] && pre_count[4] == 2) ? cand[4] :
                          (cand_valid[5] && pre_count[5] == 2) ? cand[5] :
                          (cand_valid[6] && pre_count[6] == 2) ? cand[6] :
                          (cand_valid[7] && pre_count[7] == 2) ? cand[7] : 6'b0;

  assign dissimilar[3] = (cand_valid[0] && pre_count[0] == 3) ? cand[0] :
                          (cand_valid[1] && pre_count[1] == 3) ? cand[1] :
                          (cand_valid[2] && pre_count[2] == 3) ? cand[2] :
                          (cand_valid[3] && pre_count[3] == 3) ? cand[3] :
                          (cand_valid[4] && pre_count[4] == 3) ? cand[4] :
                          (cand_valid[5] && pre_count[5] == 3) ? cand[5] :
                          (cand_valid[6] && pre_count[6] == 3) ? cand[6] :
                          (cand_valid[7] && pre_count[7] == 3) ? cand[7] : 6'b0;

  assign dissimilar[4] = (cand_valid[0] && pre_count[0] == 4) ? cand[0] :
                          (cand_valid[1] && pre_count[1] == 4) ? cand[1] :
                          (cand_valid[2] && pre_count[2] == 4) ? cand[2] :
                          (cand_valid[3] && pre_count[3] == 4) ? cand[3] :
                          (cand_valid[4] && pre_count[4] == 4) ? cand[4] :
                          (cand_valid[5] && pre_count[5] == 4) ? cand[5] :
                          (cand_valid[6] && pre_count[6] == 4) ? cand[6] :
                          (cand_valid[7] && pre_count[7] == 4) ? cand[7] : 6'b0;

  assign dissimilar[5] = (cand_valid[0] && pre_count[0] == 5) ? cand[0] :
                          (cand_valid[1] && pre_count[1] == 5) ? cand[1] :
                          (cand_valid[2] && pre_count[2] == 5) ? cand[2] :
                          (cand_valid[3] && pre_count[3] == 5) ? cand[3] :
                          (cand_valid[4] && pre_count[4] == 5) ? cand[4] :
                          (cand_valid[5] && pre_count[5] == 5) ? cand[5] :
                          (cand_valid[6] && pre_count[6] == 5) ? cand[6] :
                          (cand_valid[7] && pre_count[7] == 5) ? cand[7] : 6'b0;

  assign dissimilar[6] = (cand_valid[0] && pre_count[0] == 6) ? cand[0] :
                          (cand_valid[1] && pre_count[1] == 6) ? cand[1] :
                          (cand_valid[2] && pre_count[2] == 6) ? cand[2] :
                          (cand_valid[3] && pre_count[3] == 6) ? cand[3] :
                          (cand_valid[4] && pre_count[4] == 6) ? cand[4] :
                          (cand_valid[5] && pre_count[5] == 6) ? cand[5] :
                          (cand_valid[6] && pre_count[6] == 6) ? cand[6] :
                          (cand_valid[7] && pre_count[7] == 6) ? cand[7] : 6'b0;

  assign dissimilar[7] = (cand_valid[0] && pre_count[0] == 7) ? cand[0] :
                          (cand_valid[1] && pre_count[1] == 7) ? cand[1] :
                          (cand_valid[2] && pre_count[2] == 7) ? cand[2] :
                          (cand_valid[3] && pre_count[3] == 7) ? cand[3] :
                          (cand_valid[4] && pre_count[4] == 7) ? cand[4] :
                          (cand_valid[5] && pre_count[5] == 7) ? cand[5] :
                          (cand_valid[6] && pre_count[6] == 7) ? cand[6] :
                          (cand_valid[7] && pre_count[7] == 7) ? cand[7] : 6'b0;

  // Valid mask
  assign valid_mask = (8'b1 << pre_count[8]) - 8'b1;

endmodule