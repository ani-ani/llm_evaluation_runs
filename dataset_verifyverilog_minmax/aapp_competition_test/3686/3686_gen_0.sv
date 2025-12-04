module laser_target_checker(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // high to start computation
  input [4:0] x_coords [0:5], // array of 6 signed x coordinates (5-bit 2's complement)
  input [4:0] y_coords [0:5], // array of 6 signed y coordinates (5-bit 2's complement)
  output reg done, // high when computation complete
  output reg success // 1=possible, 0=impossible
);

  // 6 points: i=0..5
  // Indices: p0=0, p1=1, p2=2, p3=3, p4=4, p5=5

  // State encoding
  typedef enum logic [2:0] {
    IDLE          = 3'b000,
    SINGLE_CHECK  = 3'b001,
    DUAL_CANDS    = 3'b010, // evaluate candidates for first line: (0,1,2), (0,1,3), (1,2,3)
    DUAL_EVAL     = 3'b011, // evaluate remaining points for the chosen first line
    COMPLETE      = 3'b100
  } state_t;

  state_t state_r, state_next;
  logic [2:0] cand_idx;            // 0 -> (0,1,2), 1 -> (0,1,3), 2 -> (1,2,3)
  logic [2:0] cand_idx_next;
  bit [5:0] line_mask;             // points on the current first line
  bit [5:0] rem_mask;              // points not on the first line
  logic rem_is_line;               // 1 if rem_mask points are colinear (or empty)
  logic single_line_all;           // 1 if all 6 points are colinear

  // Constant function to sign-extend 5-bit 2's complement to 32-bit int
  function automatic int sxt5(input [4:0] v);
    return (v[4] ? {27'h7FFFFFF, v} : {27'h0, v});
  endfunction

  // Check if i is in mask
  function automatic bit in_mask(input bit [5:0] m, input int i);
    return m[i];
  endfunction

  // Evaluate if all points in 'pm' (bitmask) lie on a single line
  // Line defined by the first two set bits in 'pm' as pA, pB.
  // Special cases: 0 or 1 points are trivially colinear.
  function automatic bit all_on_single_line(input bit [5:0] pm);
    int a, b, c;
    int pA, pB, pC;
    int i, j;
    int x1, y1, x2, y2, x3, y3;
    int lhs, rhs;
    bit hasA, hasB;
    bit [5:0] mm;

    mm = pm;
    hasA = 1'b0;
    hasB = 1'b0;
    pA = 0;
    pB = 0;

    // Find first two set bits
    for (i = 0; i < 6; i = i + 1) begin
      if (!hasA && mm[i]) begin
        hasA = 1'b1;
        pA = i;
      end else if (hasA && !hasB && mm[i]) begin
        hasB = 1'b1;
        pB = i;
      end
    end

    // 0 or 1 points: treat as colinear
    if (!hasA || !hasB) begin
      return 1'b1;
    end

    x1 = sxt5(x_coords[pA]);
    y1 = sxt5(y_coords[pA]);
    x2 = sxt5(x_coords[pB]);
    y2 = sxt5(y_coords[pB]);

    // Check every point in mask lies on the same line
    for (j = 0; j < 6; j = j + 1) begin
      if (!mm[j]) continue;
      if (j == pA || j == pB) continue;
      x3 = sxt5(x_coords[j]);
      y3 = sxt5(y_coords[j]);
      lhs = (y2 - y1) * (x3 - x1);
      rhs = (y3 - y1) * (x2 - x1);
      if (lhs != rhs) return 1'b0;
    end

    return 1'b1;
  endfunction

  // Check if all 6 points are colinear (single line)
  function automatic bit all_six_on_single_line();
    return all_on_single_line(6'b111111);
  endfunction

  // Compute: single line check and two-line possibility (3 candidate first lines)
  // 1) all six colinear -> success=1
  // 2) for candidate lines (0,1,2), (0,1,3), (1,2,3):
  //    - compute mask of points on that line (line_mask)
  //    - if remaining (rem_mask = ~line_mask) is colinear or empty -> success=1
  // 3) otherwise success=0
  function automatic void compute_dual_lines(output bit [5:0] line_mask_out,
                                             output bit [5:0] rem_mask_out,
                                             output bit rem_is_line_out,
                                             output bit single_line_all_out,
                                             output bit success_out);
    bit [5:0] lm;
    bit [5:0] rem;
    int a, b, c;
    int pA, pB, pC;
    int x1, y1, x2, y2, x3, y3;
    int lhs, rhs;
    int i;

    // Init
    success_out = 1'b0;
    line_mask_out = 6'b0;
    rem_mask_out = 6'b0;
    rem_is_line_out = 1'b0;
    single_line_all_out = 1'b0;

    // 1) single line check for all 6 points
    if (all_six_on_single_line()) begin
      success_out = 1'b1;
      line_mask_out = 6'b111111;
      rem_mask_out = 6'b0;
      rem_is_line_out = 1'b1;
      single_line_all_out = 1'b1;
      return;
    end

    // 2) Two-line check: three candidate first lines
    // Candidate 0: points 0,1,2
    // Candidate 1: points 0,1,3
    // Candidate 2: points 1,2,3
    for (c = 0; c < 3; c = c + 1) begin
      case (c)
        0: begin a=0; b=1; c=2; end
        1: begin a=0; b=1; c=3; end
        2: begin a=1; b=2; c=3; end
      endcase

      x1 = sxt5(x_coords[a]);
      y1 = sxt5(y_coords[a]);
      x2 = sxt5(x_coords[b]);
      y2 = sxt5(y_coords[b]);
      x3 = sxt5(x_coords[c]);
      y3 = sxt5(y_coords[c]);
      lhs = (y2 - y1) * (x3 - x1);
      rhs = (y3 - y1) * (x2 - x1);

      // Points a,b,c must be colinear; if not, skip this candidate
      if (lhs != rhs) continue;

      // All points colinear with (a,b) belong to line_mask
      lm = 6'b0;
      for (i = 0; i < 6; i = i + 1) begin
        int x, y;
        x = sxt5(x_coords[i]);
        y = sxt5(y_coords[i]);
        lhs = (y2 - y1) * (x - x1);
        rhs = (y - y1) * (x2 - x1);
        if (lhs == rhs) lm[i] = 1'b1;
      end

      // Remaining points
      rem = (~lm) & 6'b111111;

      // Success if remaining points form a line (or are empty)
      if (all_on_single_line(rem)) begin
        success_out = 1'b1;
        line_mask_out = lm;
        rem_mask_out = rem;
        rem_is_line_out = 1'b1;
        return;
      end
    end

    // No single line, and no two-line solution found among 3 candidates
    success_out = 1'b0;
    line_mask_out = 6'b0;
    rem_mask_out = 6'b0;
    rem_is_line_out = 1'b0;
    single_line_all_out = 1'b0;
  endfunction

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r <= IDLE;
      cand_idx <= 3'b0;
      done <= 1'b0;
      success <= 1'b0;
    end else begin
      state_r <= state_next;
      cand_idx <= cand_idx_next;
      // done/success are set only in COMPLETE
      if (state_next == COMPLETE) begin
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
      if (state_next == COMPLETE) begin
        success <= rem_is_line ? 1'b1 : (single_line_all ? 1'b1 : 1'b0);
      end else begin
        success <= success; // keep value
      end
    end
  end

  // Next-state logic and combinatorial outputs for dual-line candidate tracking
  always_comb begin
    state_next = state_r;
    cand_idx_next = cand_idx;
    single_line_all = 1'b0;
    line_mask = 6'b0;
    rem_mask = 6'b0;
    rem_is_line = 1'b0;

    case (state_r)
      IDLE: begin
        if (start) begin
          // Pre-compute single line result and 3 candidate results
          compute_dual_lines(line_mask, rem_mask, rem_is_line, single_line_all, success);
          state_next = SINGLE_CHECK;
        end
      end

      SINGLE_CHECK: begin
        // If all six are colinear, we can finish in this cycle
        if (single_line_all) begin
          state_next = COMPLETE;
        end else begin
          // Otherwise, go evaluate via the 3 candidates
          cand_idx_next = 3'b0;
          state_next = DUAL_CANDS;
        end
      end

      DUAL_CANDS: begin
        // Evaluate candidate cand_idx: compute its line mask and remaining points
        if (cand_idx == 3'b0) begin
          // Candidate: (0,1,2)
          int x1, y1, x2, y2, x3, y3;
          int lhs, rhs;
          int i;
          x1 = sxt5(x_coords[0]); y1 = sxt5(y_coords[0]);
          x2 = sxt5(x_coords[1]); y2 = sxt5(y_coords[1]);
          x3 = sxt5(x_coords[2]); y3 = sxt5(y_coords[2]);
          lhs = (y2 - y1) * (x3 - x1);
          rhs = (y3 - y1) * (x2 - x1);
          if (lhs == rhs) begin
            // Compute line mask for line through (0,1)
            line_mask = 6'b0;
            for (i = 0; i < 6; i = i + 1) begin
              int x, y;
              x = sxt5(x_coords[i]); y = sxt5(y_coords[i]);
              lhs = (y2 - y1) * (x - x1);
              rhs = (y - y1) * (x2 - x1);
              if (lhs == rhs) line_mask[i] = 1'b1;
            end
            rem_mask = (~line_mask) & 6'b111111;
            rem_is_line = all_on_single_line(rem_mask);
          end else begin
            line_mask = 6'b0;
            rem_mask = 6'b111111;
            rem_is_line = 1'b0;
          end
        end else if (cand_idx == 3'b001) begin
          // Candidate: (0,1,3)
          int x1, y1, x2, y2, x3, y3;
          int lhs, rhs;
          int i;
          x1 = sxt5(x_coords[0]); y1 = sxt5(y_coords[0]);
          x2 = sxt5(x_coords[1]); y2 = sxt5(y_coords[1]);
          x3 = sxt5(x_coords[3]); y3 = sxt5(y_coords[3]);
          lhs = (y2 - y1) * (x3 - x1);
          rhs = (y3 - y1) * (x2 - x1);
          if (lhs == rhs) begin
            line_mask = 6'b0;
            for (i = 0; i < 6; i = i + 1) begin
              int x, y;
              x = sxt5(x_coords[i]); y = sxt5(y_coords[i]);
              lhs = (y2 - y1) * (x - x1);
              rhs = (y - y1) * (x2 - x1);
              if (lhs == rhs) line_mask[i] = 1'b1;
            end
            rem_mask = (~line_mask) & 6'b111111;
            rem_is_line = all_on_single_line(rem_mask);
          end else begin
            line_mask = 6'b0;
            rem_mask = 6'b111111;
            rem_is_line = 1'b0;
          end
        end else begin
          // Candidate: (1,2,3)
          int x1, y1, x2, y2, x3, y3;
          int lhs, rhs;
          int i;
          x1 = sxt5(x_coords[1]); y1 = sxt5(y_coords[1]);
          x2 = sxt5(x_coords[2]); y2 = sxt5(y_coords[2]);
          x3 = sxt5(x_coords[3]); y3 = sxt5(y_coords[3]);
          lhs = (y2 - y1) * (x3 - x1);
          rhs = (y3 - y1) * (x2 - x1);
          if (lhs == rhs) begin
            line_mask = 6'b0;
            for (i = 0; i < 6; i = i + 1) begin
              int x, y;
              x = sxt5(x_coords[i]); y = sxt5(y_coords[i]);
              lhs = (y2 - y1) * (x - x1);
              rhs = (y - y1) * (x2 - x1);
              if (lhs == rhs) line_mask[i] = 1'b1;
            end
            rem_mask = (~line_mask) & 6'b111111;
            rem_is_line = all_on_single_line(rem_mask);
          end else begin
            line_mask = 6'b0;
            rem_mask = 6'b111111;
            rem_is_line = 1'b0;
          end
        end

        // After computing candidate, move to evaluate remaining points
        state_next = DUAL_EVAL;
      end

      DUAL_EVAL: begin
        // If the remaining points are colinear (or empty), we succeed; else try next candidate
        if (rem_is_line) begin
          state_next = COMPLETE;
        end else if (cand_idx < 3'b010) begin
          cand_idx_next = cand_idx + 1;
          state_next = DUAL_CANDS;
        end else begin
          state_next = COMPLETE;
        end
      end

      COMPLETE: begin
        // Wait for start to go low before accepting a new start
        if (!start) begin
          state_next = IDLE;
        end
      end

      default: state_next = IDLE;
    endcase
  end
endmodule
