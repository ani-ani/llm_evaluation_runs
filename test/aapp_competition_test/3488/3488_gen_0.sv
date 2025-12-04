module minimal_convex_hull_vertices(
  input clk,
  input rst_n,
  input start,
  input [15:0] vx[0:7],
  input [15:0] vy[0:7],
  input [2:0] vertex_count,
  input [15:0] px[0:3],
  input [15:0] py[0:3],
  input [1:0] point_count,
  output reg [2:0] min_vertices,
  output reg done
);

  // State machine
  typedef enum logic [3:0] {
    S_IDLE        = 4'd0,
    S_INIT        = 4'd1,
    S_NEXT_K      = 4'd2,
    S_CHECK_DONE  = 4'd3,
    S_COMB_INIT   = 4'd4,
    S_COMB_LOAD   = 4'd5,
    S_EDGE_INIT   = 4'd6,
    S_EDGE_START  = 4'd7,
    S_EDGE_POINT  = 4'd8,
    S_EDGE_EVAL   = 4'd9,
    S_COMB_NEXT   = 4'd10,
    S_FOUND       = 4'd11,
    S_FINISH      = 4'd12
  } state_t;

  state_t state, next_state;

  // Registers
  reg [2:0] k;                  // current subset size (3..vertex_count)
  reg [2:0] N;                  // total vertices
  reg [1:0] P;                  // total points

  // Combination indices (choose k from N), indices in [0..7]
  reg [2:0] comb_idx[0:7];      // only [0..k-1] used

  // Flags
  reg       found_for_k;        // found valid subset for current k
  reg       comb_valid;         // current combination exists within N

  // Edge / point iteration
  reg [2:0] edge_i;             // 0..k-1
  reg [1:0] pt_j;               // 0..P-1
  reg       edge_dir_set;       // direction established for current edge
  reg       edge_ok;            // all points OK for current edge
  reg       subset_ok;          // all edges OK for current subset

  // Temporary for cross product sign reference per edge
  reg       sign_ref_pos;       // 1 if reference sign is positive
  reg       sign_ref_neg;       // 1 if reference sign is negative

  // Cross product computation signals
  reg  [15:0] ax, ay, bx, by, px_s, py_s;
  wire signed [31:0] cross_val;

  assign cross_val = $signed(ax) * $signed(py_s) - $signed(ay) * $signed(px_s);

  // Asynchronous reset and state / registers update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      done          <= 1'b0;
      min_vertices  <= 3'd0;
      k             <= 3'd0;
      N             <= 3'd0;
      P             <= 2'd0;
      found_for_k   <= 1'b0;
      comb_valid    <= 1'b0;
      edge_i        <= 3'd0;
      pt_j          <= 2'd0;
      edge_dir_set  <= 1'b0;
      edge_ok       <= 1'b0;
      subset_ok     <= 1'b0;
      sign_ref_pos  <= 1'b0;
      sign_ref_neg  <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
        end

        S_INIT: begin
          // Capture inputs
          N            <= vertex_count;
          P            <= point_count;
          k            <= 3'd3;      // start from triangle
          found_for_k  <= 1'b0;
          comb_valid   <= 1'b0;
          subset_ok    <= 1'b0;
        end

        S_NEXT_K: begin
          found_for_k  <= 1'b0;
          comb_valid   <= 1'b0;
          subset_ok    <= 1'b0;
        end

        S_CHECK_DONE: begin
          // nothing extra
        end

        S_COMB_INIT: begin
          // Initialize first combination for current k: [0,1,2,...,k-1]
          comb_idx[0] <= 3'd0;
          comb_idx[1] <= 3'd1;
          comb_idx[2] <= 3'd2;
          comb_idx[3] <= 3'd3;
          comb_idx[4] <= 3'd4;
          comb_idx[5] <= 3'd5;
          comb_idx[6] <= 3'd6;
          comb_idx[7] <= 3'd7;
          comb_valid  <= 1'b1; // first combination is valid since k<=N
          subset_ok   <= 1'b0;
        end

        S_COMB_LOAD: begin
          // Reset per-subset flags before edge checks
          edge_i       <= 3'd0;
          subset_ok    <= 1'b1;  // assume ok until proven otherwise
        end

        S_EDGE_INIT: begin
          // Initialize edge processing for edge_i
          pt_j         <= 2'd0;
          edge_dir_set <= 1'b0;
          edge_ok      <= 1'b1; // assume edge ok until violated
          sign_ref_pos <= 1'b0;
          sign_ref_neg <= 1'b0;
        end

        S_EDGE_START: begin
          // nothing; combinational will set up first point
        end

        S_EDGE_POINT: begin
          // For each point, after evaluating cross_val in S_EDGE_EVAL
          // progression of pt_j handled there
        end

        S_EDGE_EVAL: begin
          // Evaluate cross product sign for current point and update edge_ok / direction
          if (edge_ok) begin
            if (cross_val != 32'sd0) begin
              if (!edge_dir_set) begin
                edge_dir_set <= 1'b1;
                if (cross_val > 0) begin
                  sign_ref_pos <= 1'b1;
                  sign_ref_neg <= 1'b0;
                end else begin
                  sign_ref_pos <= 1'b0;
                  sign_ref_neg <= 1'b1;
                end
              end else begin
                // direction already set, check consistency
                if (sign_ref_pos && (cross_val < 0)) begin
                  edge_ok <= 1'b0;
                end else if (sign_ref_neg && (cross_val > 0)) begin
                  edge_ok <= 1'b0;
                end
              end
            end
          end

          // Advance to next point or edge here
          if (pt_j + 1 < P) begin
            pt_j <= pt_j + 1'b1;
          end else begin
            // finished all points for this edge
            if (!edge_ok) begin
              subset_ok <= 1'b0;
            end
            if (edge_i + 1 < k) begin
              edge_i <= edge_i + 1'b1;
            end
          end
        end

        S_COMB_NEXT: begin
          // Generate next combination (lexicographic) for size k from N
          integer i;
          reg advanced;
          advanced = 1'b0;

          if (comb_valid && !found_for_k) begin
            // Try to increment from the rightmost index
            for (i = 7; i >= 0; i = i - 1) begin
              if (!advanced && (i < k)) begin
                if (comb_idx[i] < (N - (k - i))) begin
                  comb_idx[i] <= comb_idx[i] + 1'b1;
                  // reset following indices
                  integer j;
                  for (j = i + 1; j < k; j = j + 1) begin
                    comb_idx[j] <= comb_idx[j-1] + 1'b1;
                  end
                  advanced = 1'b1;
                end
              end
            end

            if (!advanced) begin
              comb_valid <= 1'b0; // no more combinations
            end
          end
        end

        S_FOUND: begin
          // latched in next_state logic
        end

        S_FINISH: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_INIT;
        end
      end

      S_INIT: begin
        if (vertex_count < 3) begin
          next_state = S_FINISH;
        end else begin
          next_state = S_COMB_INIT;
        end
      end

      S_NEXT_K: begin
        if (k > N) begin
          next_state = S_FINISH;
        end else begin
          next_state = S_COMB_INIT;
        end
      end

      S_CHECK_DONE: begin
        if (found_for_k) begin
          next_state = S_FOUND;
        end else if (k >= N) begin
          next_state = S_FINISH;
        end else begin
          next_state = S_NEXT_K;
        end
      end

      S_COMB_INIT: begin
        next_state = S_COMB_LOAD;
      end

      S_COMB_LOAD: begin
        // Start with first edge for this combination
        next_state = S_EDGE_INIT;
      end

      S_EDGE_INIT: begin
        next_state = S_EDGE_START;
      end

      S_EDGE_START: begin
        if (P == 0) begin
          // no internal points, trivial (subset valid)
          next_state = S_FOUND;
        end else begin
          next_state = S_EDGE_POINT;
        end
      end

      S_EDGE_POINT: begin
        // Proceed to evaluate current point
        next_state = S_EDGE_EVAL;
      end

      S_EDGE_EVAL: begin
        // Determine progression based on pt_j, edge_i, edge_ok, subset_ok
        if (P == 0) begin
          next_state = S_FOUND;
        end else if (pt_j + 1 < P) begin
          // more points for same edge
          next_state = S_EDGE_POINT;
        end else begin
          // finished all points for this edge
          if (!edge_ok) begin
            // subset fails due to this edge
            if (!comb_valid) begin
              next_state = S_CHECK_DONE;
            end else begin
              next_state = S_COMB_NEXT;
            end
          end else begin
            // this edge ok, move to next edge or finish subset
            if (edge_i + 1 < k) {
              next_state = S_EDGE_INIT;
            end else begin
              // all edges passed
              next_state = S_FOUND;
            end
          end
        end
      end

      S_COMB_NEXT: begin
        if (!comb_valid) begin
          // no more combinations for this k
          if (k >= N) begin
            next_state = S_FINISH;
          end else begin
            // try next k
            next_state = S_NEXT_K;
          end
        end else begin
          // have next combination to test
          next_state = S_COMB_LOAD;
        end
      end

      S_FOUND: begin
        next_state = S_FINISH;
      end

      S_FINISH: begin
        if (!start) begin
          next_state = S_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Control for k and min_vertices
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_vertices <= 3'd0;
      k            <= 3'd0;
      found_for_k  <= 1'b0;
    end else begin
      case (state)
        S_INIT: begin
          k           <= 3'd3;
          found_for_k <= 1'b0;
        end

        S_NEXT_K: begin
          if (!found_for_k && (k < N)) begin
            k <= k + 1'b1;
          end
          found_for_k <= 1'b0;
        end

        S_FOUND: begin
          if (!found_for_k) begin
            found_for_k  <= 1'b1;
            min_vertices <= k;
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Cross-product input selection (combinational)
  always @(*) begin
    // Default assignments
    ax   = 16'd0;
    ay   = 16'd0;
    bx   = 16'd0;
    by   = 16'd0;
    px_s = 16'd0;
    py_s = 16'd0;

    if (state == S_EDGE_POINT || state == S_EDGE_EVAL || state == S_EDGE_START || state == S_EDGE_INIT) begin
      // Edge endpoints from selected vertices in current combination
      // vA = comb_idx[edge_i], vB = comb_idx[(edge_i+1)%k]
      reg [2:0] idxA;
      reg [2:0] idxB;
      idxA = comb_idx[edge_i];
      if (edge_i + 1 < k)
        idxB = comb_idx[edge_i + 1];
      else
        idxB = comb_idx[0];

      ax = vx[idxB] - vx[idxA];
      ay = vy[idxB] - vy[idxA];

      // point vector from A to internal point j
      if (pt_j < P) begin
        bx   = px[pt_j] - vx[idxA];
        by   = py[pt_j] - vy[idxA];
        px_s = bx;
        py_s = by;
      end else begin
        px_s = 16'd0;
        py_s = 16'd0;
      end
    end
  end

endmodule