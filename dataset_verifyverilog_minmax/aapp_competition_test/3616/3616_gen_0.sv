module allergen_test_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] D1,
  input [2:0] D2,
  input [2:0] D3,
  input [2:0] D4,
  output reg done,
  output reg [4:0] T
);
  // Internal pipeline registers
  reg [4:0] s2_T;        // T selected in cycle 2
  reg [4:0] s3_T;        // T registered for output in cycle 3
  reg       s2_done;     // pipeline done flag for cycle 2
  reg       s3_done;     // pipeline done flag for cycle 3
  reg [4:0] s1_Tmask;    // 5-bit mask of feasible T in [1..5]; bit0=T=1,..., bit4=T=5
  reg [4:0] s2_Tmask;    // pipeline mask
  reg       s1_done;
  reg       s2_done_d;

  // Allergen durations (zero-extend to 5 bits for comparisons)
  wire [4:0] dvec [0:3];
  assign dvec[0] = {2'b0, D1};
  assign dvec[1] = {2'b0, D2};
  assign dvec[2] = {2'b0, D3};
  assign dvec[3] = {2'b0, D4};

  // Helper: integer min
  function [4:0] fmin (input [4:0] a, input [4:0] b);
    fmin = (a < b) ? a : b;
  endfunction

  // Cycle 1: parallel pair-wise overlap checks and feasibility mask over T in [1..5]
  // Feasible if exists a perfect matching on the bipartite graph of k allergens and T days,
  // where allergen i can use day d iff d < D_i and d < T.
  function [4:0] allowed_bits_k (input integer kk, input [4:0] d0, input [4:0] d1, input [4:0] d2, input [4:0] d3, input [4:0] tt);
    // For given T=tt, build a 5-bit mask of days d (0..4) that are < D_i for at least one allergen i
    integer i; reg [4:0] mask;
    mask = 5'b0;
    for (i = 0; i < kk; i = i + 1) begin
      case (i)
        0: if (tt > 0 && d0 > 0) mask = mask | (5'b1 << (tt > 0 ? 0 : 5));  // day 0 if allowed
        1: if (tt > 1 && d1 > 1) mask = mask | (5'b1 << 1);                // day 1 if allowed
        2: if (tt > 2 && d2 > 2) mask = mask | (5'b1 << 2);                // day 2 if allowed
        3: if (tt > 3 && d3 > 3) mask = mask | (5'b1 << 3);                // day 3 if allowed
      endcase
    end
    // For T<=4, day 4 may also be allowed
    if (tt > 4) begin
      if ((kk > 0 && d0 > 4) || (kk > 1 && d1 > 4) || (kk > 2 && d2 > 4) || (kk > 3 && d3 > 4))
        mask = mask | (5'b1 << 4);
    end
    allowed_bits_k = mask;
  endfunction

  // Max distinct days possible for a given T, considering per-allergen upper bounds
  function [4:0] max_distinct_days (input integer kk, input [4:0] d0, input [4:0] d1, input [4:0] d2, input [4:0] d3, input [4:0] tt);
    integer i; reg [4:0] ctr;
    ctr = 5'b0;
    for (i = 0; i < kk; i = i + 1) begin
      case (i)
        0: if (tt > 0 && d0 > 0) ctr = ctr + 1;
        1: if (tt > 1 && d1 > 1) ctr = ctr + 1;
        2: if (tt > 2 && d2 > 2) ctr = ctr + 1;
        3: if (tt > 3 && d3 > 3) ctr = ctr + 1;
      endcase
    end
    if (tt > 4) begin
      if ((kk > 0 && d0 > 4) || (kk > 1 && d1 > 4) || (kk > 2 && d2 > 4) || (kk > 3 && d3 > 4))
        ctr = ctr + 1;
    end
    // Limit by T
    if (ctr > tt) ctr = tt;
    max_distinct_days = ctr;
  endfunction

  // Feasibility check for a specific T: can we assign k distinct days to k allergens under constraints?
  function bit exists_assign_for_T (input integer kk, input [4:0] d0, input [4:0] d1, input [4:0] d2, input [4:0] d3, input [4:0] tt);
    integer a, d;
    reg [4:0] allow [0:3];
    reg assigned [0:4];
    // Build adjacency: allow[a][d] is 1 if allergen a can use day d (d < D_a and d < T)
    for (d = 0; d < 5; d = d + 1) begin
      assigned[d] = 1'b0;
      case (d)
        0: allow[0][0] = (kk > 0 && tt > 0 && d0 > 0) ? 1'b1 : 1'b0;
        1: allow[0][1] = (kk > 0 && tt > 1 && d0 > 1) ? 1'b1 : 1'b0;
        2: allow[0][2] = (kk > 0 && tt > 2 && d0 > 2) ? 1'b1 : 1'b0;
        3: allow[0][3] = (kk > 0 && tt > 3 && d0 > 3) ? 1'b1 : 1'b0;
        4: allow[0][4] = (kk > 0 && tt > 4 && d0 > 4) ? 1'b1 : 1'b0;
      endcase
      if (kk > 1) begin
        case (d)
          0: allow[1][0] = (tt > 0 && d1 > 0) ? 1'b1 : 1'b0;
          1: allow[1][1] = (tt > 1 && d1 > 1) ? 1'b1 : 1'b0;
          2: allow[1][2] = (tt > 2 && d1 > 2) ? 1'b1 : 1'b0;
          3: allow[1][3] = (tt > 3 && d1 > 3) ? 1'b1 : 1'b0;
          4: allow[1][4] = (tt > 4 && d1 > 4) ? 1'b1 : 1'b0;
        endcase
      end else begin
        allow[1][d] = 1'b0;
      end
      if (kk > 2) begin
        case (d)
          0: allow[2][0] = (tt > 0 && d2 > 0) ? 1'b1 : 1'b0;
          1: allow[2][1] = (tt > 1 && d2 > 1) ? 1'b1 : 1'b0;
          2: allow[2][2] = (tt > 2 && d2 > 2) ? 1'b1 : 1'b0;
          3: allow[2][3] = (tt > 3 && d2 > 3) ? 1'b1 : 1'b0;
          4: allow[2][4] = (tt > 4 && d2 > 4) ? 1'b1 : 1'b0;
        endcase
      end else begin
        allow[2][d] = 1'b0;
      end
      if (kk > 3) begin
        case (d)
          0: allow[3][0] = (tt > 0 && d3 > 0) ? 1'b1 : 1'b0;
          1: allow[3][1] = (tt > 1 && d3 > 1) ? 1'b1 : 1'b0;
          2: allow[3][2] = (tt > 2 && d3 > 2) ? 1'b1 : 1'b0;
          3: allow[3][3] = (tt > 3 && d3 > 3) ? 1'b1 : 1'b0;
          4: allow[3][4] = (tt > 4 && d3 > 4) ? 1'b1 : 1'b0;
        endcase
      end else begin
        allow[3][d] = 1'b0;
      end
    end

    // DFS bipartite matching (Kuhn's algorithm). Allergens 0..kk-1 -> Days 0..tt-1
    reg [4:0] match_d; // match_d[day] = allergen or 5 if none
    match_d = 5'b11111; // 5 means unmatched
    for (a = 0; a < kk; a = a + 1) begin
      reg [4:0] seen;
      seen = 5'b0;
      if (!dfs_kuhn(a)) exists_assign_for_T = 1'b0; // fail fast if any can't be matched
    end
    exists_assign_for_T = 1'b1; // if all reached, a matching exists

    function bit dfs_kuhn (input integer v);
      integer d;
      for (d = 0; d < tt; d = d + 1) begin
        if (allow[v][d] && !seen[d]) begin
          seen[d] = 1'b1;
          if ((match_d[d] == 5) || dfs_kuhn(match_d[d])) begin
            match_d[d] = v;
            dfs_kuhn = 1'b1;
            return;
          end
        end
      end
      dfs_kuhn = 1'b0;
    endfunction

  endfunction

  // Cycle 1 combinational logic: compute feasible T mask for T in [1..5]
  always @(*) begin
    s1_Tmask = 5'b0;
    s1_done  = 1'b0;
    if (start && (k >= 1) && (k <= 4)) begin
      s1_done = 1'b1;
      // Check T=1..5
      // T=1 (bit0)
      if (k <= max_distinct_days(k, dvec[0], dvec[1], dvec[2], dvec[3], 1))
        if (exists_assign_for_T(k, dvec[0], dvec[1], dvec[2], dvec[3], 1))
          s1_Tmask[0] = 1'b1;
      // T=2 (bit1)
      if (k <= max_distinct_days(k, dvec[0], dvec[1], dvec[2], dvec[3], 2))
        if (exists_assign_for_T(k, dvec[0], dvec[1], dvec[2], dvec[3], 2))
          s1_Tmask[1] = 1'b1;
      // T=3 (bit2)
      if (k <= max_distinct_days(k, dvec[0], dvec[1], dvec[2], dvec[3], 3))
        if (exists_assign_for_T(k, dvec[0], dvec[1], dvec[2], dvec[3], 3))
          s1_Tmask[2] = 1'b1;
      // T=4 (bit3)
      if (k <= max_distinct_days(k, dvec[0], dvec[1], dvec[2], dvec[3], 4))
        if (exists_assign_for_T(k, dvec[0], dvec[1], dvec[2], dvec[3], 4))
          s1_Tmask[3] = 1'b1;
      // T=5 (bit4)
      if (k <= max_distinct_days(k, dvec[0], dvec[1], dvec[2], dvec[3], 5))
        if (exists_assign_for_T(k, dvec[0], dvec[1], dvec[2], dvec[3], 5))
          s1_Tmask[4] = 1'b1;
    end
  end

  // Cycle 2: pick the minimal feasible T from mask and store done
  always @(*) begin
    s2_T = 5'b0;
    s2_done = 1'b0;
    s2_Tmask = s1_Tmask;
    if (s1_done) begin
      s2_done = 1'b1;
      if (s1_Tmask[0]) s2_T = 1;
      else if (s1_Tmask[1]) s2_T = 2;
      else if (s1_Tmask[2]) s2_T = 3;
      else if (s1_Tmask[3]) s2_T = 4;
      else if (s1_Tmask[4]) s2_T = 5;
      else s2_T = 5'b0; // no solution (shouldn't happen for given constraints)
    end
  end

  // Cycle 3: register out
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      T    <= 5'b0;
    end else begin
      done <= s2_done; // done is valid in cycle 3 when start was 1 in cycle 1
      T    <= s2_T;
    end
  end
endmodule
