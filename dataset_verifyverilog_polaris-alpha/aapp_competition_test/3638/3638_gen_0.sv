module rival_sequence_sorter(
  input [3:0] n,
  input [1:0] len0,
  input [7:0] seq0,
  input [1:0] len1,
  input [7:0] seq1,
  input [1:0] len2,
  input [7:0] seq2,
  input [1:0] len3,
  input [7:0] seq3,
  output reg [1:0] sorted_indices [0:3]
);

  // Internal score wires
  reg [9:0] score0;
  reg [9:0] score1;
  reg [9:0] score2;
  reg [9:0] score3;

  // Compute scores combinationally
  always @* begin
    // score0
    case (len0)
      2'd0: score0 = 10'd0;
      2'd1: score0 = (n >= 1) ? (n - 4'd1 + 4'd1) * 10'd81 : 10'd0;
      2'd2: score0 = (n >= 2) ? (n - 4'd2 + 4'd1) * 10'd27 : 10'd0;
      2'd3: score0 = (n >= 3) ? (n - 4'd3 + 4'd1) * 10'd9  : 10'd0;
      2'd4: score0 = (n >= 4) ? (n - 4'd4 + 4'd1) * 10'd3  : 10'd0;
      default: score0 = 10'd0;
    endcase

    // score1
    case (len1)
      2'd0: score1 = 10'd0;
      2'd1: score1 = (n >= 1) ? (n - 4'd1 + 4'd1) * 10'd81 : 10'd0;
      2'd2: score1 = (n >= 2) ? (n - 4'd2 + 4'd1) * 10'd27 : 10'd0;
      2'd3: score1 = (n >= 3) ? (n - 4'd3 + 4'd1) * 10'd9  : 10'd0;
      2'd4: score1 = (n >= 4) ? (n - 4'd4 + 4'd1) * 10'd3  : 10'd0;
      default: score1 = 10'd0;
    endcase

    // score2
    case (len2)
      2'd0: score2 = 10'd0;
      2'd1: score2 = (n >= 1) ? (n - 4'd1 + 4'd1) * 10'd81 : 10'd0;
      2'd2: score2 = (n >= 2) ? (n - 4'd2 + 4'd1) * 10'd27 : 10'd0;
      2'd3: score2 = (n >= 3) ? (n - 4'd3 + 4'd1) * 10'd9  : 10'd0;
      2'd4: score2 = (n >= 4) ? (n - 4'd4 + 4'd1) * 10'd3  : 10'd0;
      default: score2 = 10'd0;
    endcase

    // score3
    case (len3)
      2'd0: score3 = 10'd0;
      2'd1: score3 = (n >= 1) ? (n - 4'd1 + 4'd1) * 10'd81 : 10'd0;
      2'd2: score3 = (n >= 2) ? (n - 4'd2 + 4'd1) * 10'd27 : 10'd0;
      2'd3: score3 = (n >= 3) ? (n - 4'd3 + 4'd1) * 10'd9  : 10'd0;
      2'd4: score3 = (n >= 4) ? (n - 4'd4 + 4'd1) * 10'd3  : 10'd0;
      default: score3 = 10'd0;
    endcase
  end

  // Sorting by descending score with tie-breaker on lower index
  // Using a fixed comparator network (4-element sort)

  // Local variables for indices and scores during sorting
  reg [1:0] idx0, idx1, idx2, idx3;
  reg [9:0] sc0, sc1, sc2, sc3;
  reg [1:0] t_idx_a, t_idx_b;
  reg [9:0] t_sc_a, t_sc_b;

  // Comparator task: if (A < B) swap to ensure A >= B, tie-breaker on lower index
  task automatic cmp_swap_desc;
    inout [9:0] a_score;
    inout [1:0] a_idx;
    inout [9:0] b_score;
    inout [1:0] b_idx;
    reg swap;
    begin
      swap = 1'b0;
      if (a_score < b_score)
        swap = 1'b1;
      else if (a_score == b_score && a_idx > b_idx)
        swap = 1'b1;

      if (swap) begin
        t_sc_a = a_score;
        t_idx_a = a_idx;
        a_score = b_score;
        a_idx = b_idx;
        b_score = t_sc_a;
        b_idx = t_idx_a;
      end
    end
  endtask

  always @* begin
    // Initialize indices and scores
    idx0 = 2'd0; sc0 = score0;
    idx1 = 2'd1; sc1 = score1;
    idx2 = 2'd2; sc2 = score2;
    idx3 = 2'd3; sc3 = score3;

    // Comparator network for 4 elements (descending order)
    // Stage 1
    cmp_swap_desc(sc0, idx0, sc1, idx1);
    cmp_swap_desc(sc2, idx2, sc3, idx3);
    // Stage 2
    cmp_swap_desc(sc0, idx0, sc2, idx2);
    cmp_swap_desc(sc1, idx1, sc3, idx3);
    // Stage 3
    cmp_swap_desc(sc1, idx1, sc2, idx2);

    // Assign sorted indices
    sorted_indices[0] = idx0;
    sorted_indices[1] = idx1;
    sorted_indices[2] = idx2;
    sorted_indices[3] = idx3;
  end

endmodule